using System;
using System.Reflection;
using System.Collections;
using LuaTinker.Helpers;

using internal LuaTinker.Helpers;
using internal LuaTinker;

namespace LuaTinker.Helpers
{
	static
	{
		[Comptime]
		public static bool CanAutoTinkMethod(MethodInfo method)
		{
			if (IsDelegateType(method.ReturnType))
				return false;

			// Append constructors expose a compiler-generated argument that the
			// dynamic constructor handler skips when consuming Lua arguments.
			int startParamIndex = method.IsConstructor && method.ParamCount > 0 &&
				method.GetParamName(0) == "__appendIdx" ? 1 : 0;
			for (int i = startParamIndex; i < method.ParamCount; i++)
			{
				Type paramType = method.GetParamType(i);
				if (let refType = paramType as RefType)
				{
					// Dynamic constructors only generate value arguments.
					if (method.IsConstructor)
						return false;
					if (refType.RefKind != .Ref && refType.RefKind != .Out)
						return false;
					paramType = refType.UnderlyingType;
					// Pointer-valued out/ref needs a mutable pointer cell, not a pointer to the target.
					if (paramType.IsPointer)
						return false;
				}

				if (IsFunctionType(paramType))
					return false;
			}
			return true;
		}

		// Called once per AutoTinkClass expansion; each name excludes every overload.
		public interface IMethodExclusionProvider
		{
			static void CollectExcludedMethods(Type type, HashSet<StringView> excluded);
		}

		public struct NoMethodExclusions : IMethodExclusionProvider
		{
			[Comptime]
			public static void CollectExcludedMethods(Type type, HashSet<StringView> excluded) {}
		}
	}
}

namespace LuaTinker
{
	/// Options for member dependencies during deep automatic binding.
	public enum AutoTinkFlags
	{
		/// Skips member dependency registration.
		None = 0,
		/// Also registers enum types used by bound members.
		IncludeEnums = 1,
		/// Also registers struct types used by bound members.
		IncludeStructs = 2,
		/// Also registers class types used by bound members.
		IncludeClasses = 4,
		/// Gives registered enum constants their Beef enum type for overload selection.
		TypedEnums = 8,

		/// Includes enum, struct, and class dependencies.
		IncludeAll = IncludeEnums | IncludeStructs | IncludeClasses
	}

	/// Binds the requested type and its parents without following member dependencies.
	public enum AutoTinkShallowMode { Shallow }
	/// Selects binding of the requested type and recursive registration of its dependencies.
	public enum AutoTinkDeepMode { Deep }

	extension LuaTinker
	{
		private enum AutoTinkOrigin
		{
			Root,
			Dependency
		}

		/// Binds the supported public members of T and its parent hierarchy.
		/// @param name Lua name for T. If empty, its short type name is used.
		[Inline]
		public void AutoTinkClass<T>(AutoTinkShallowMode mode, String name = "")
			=> BeginAutoTink<T, NoMethodExclusions, const AutoTinkFlags.None, const false>(
				.None, name: name, namespacePath: "");

		/// Binds T and its parent hierarchy, applying the method exclusions.
		/// @where Exclusions Supplies method names to omit, including all their overloads.
		/// @param name Lua name for T. If empty, its short type name is used.
		[Inline]
		public void AutoTinkClass<T, Exclusions>(AutoTinkShallowMode mode, String name = "")
			where Exclusions : struct, IMethodExclusionProvider
			=> BeginAutoTink<T, Exclusions, const AutoTinkFlags.None, const false>(
				.None, name: name, namespacePath: "");

		/// Binds T and recursively registers its enum, struct, and class dependencies.
		/// Dependencies use their short type names in the same scope.
		/// @param name Lua name for T. If empty, its short type name is used.
		[Inline]
		public void AutoTinkClass<T>(AutoTinkDeepMode mode, String name = "")
			=> BeginAutoTink<T, NoMethodExclusions, const AutoTinkFlags.IncludeAll, const false>(
				.IncludeAll, name: name, namespacePath: "");

		/// Binds T and recursively registers its dependencies, applying the method exclusions.
		/// Dependencies use their short type names in the same scope.
		/// @where Exclusions Supplies method names to omit from T and each dependency, including all overloads.
		/// @param name Lua name for T. If empty, its short type name is used.
		[Inline]
		public void AutoTinkClass<T, Exclusions>(AutoTinkDeepMode mode, String name = "")
			where Exclusions : struct, IMethodExclusionProvider
			=> BeginAutoTink<T, Exclusions, const AutoTinkFlags.IncludeAll, const false>(
				.IncludeAll, name: name, namespacePath: "");

		/// Binds T and recursively registers the dependency kinds selected by flags.
		/// Dependencies use their short type names in the same scope.
		/// @param flags Compile-time dependency inclusion options.
		/// @param name Lua name for T. If empty, its short type name is used.
		[Inline]
		public void AutoTinkClass<T, Flags>(AutoTinkDeepMode mode, Flags flags, String name = "")
			where Flags : const AutoTinkFlags
			=> BeginAutoTink<T, NoMethodExclusions, const Flags, const false>(
				flags, name: name, namespacePath: "");

		/// Binds T and recursively registers selected dependencies, applying the method exclusions.
		/// Dependencies use their short type names in the same scope.
		/// @where Exclusions Supplies method names to omit from T and each dependency, including all overloads.
		/// @param flags Compile-time dependency inclusion options.
		/// @param name Lua name for T. If empty, its short type name is used.
		[Inline]
		public void AutoTinkClass<T, Exclusions, Flags>(AutoTinkDeepMode mode, Flags flags, String name = "")
			where Exclusions : struct, IMethodExclusionProvider
			where Flags : const AutoTinkFlags
			=> BeginAutoTink<T, Exclusions, const Flags, const false>(
				flags, name: name, namespacePath: "");

		internal void BeginAutoTink<T, Exclusions, Flags, Inline>(Flags flags, String name, String namespacePath)
			where Exclusions : struct, IMethodExclusionProvider
			where Flags : const AutoTinkFlags
			where Inline : const bool
		{
			HashSet<Type> visited = scope .();
			Dictionary<String, Type> names = scope .();
			defer { for (let key in names.Keys) delete key; }
			visited.Add(typeof(T));
			AutoTinkClassImpl<T, Exclusions, const Flags, const Inline>(flags, namespacePath, visited, names, name, .Root);
		}

		private static void RequireAutoTinkName(
			Type type, String namespacePath, String name, Dictionary<String, Type> names)
		{
			if (names.TryAdd(name, let key, let value))
			{
				*key = new String(name);
				*value = type;
			}
			else if (*value != type)
			{
				let fullName = scope String(namespacePath);
				if (!fullName.IsEmpty)
					fullName.Append('.');
				fullName.Append(name);
				Runtime.FatalError(scope $"AutoTink name '{fullName}' conflicts between '{*value}' and '{type}'");
			}
		}

		private void AutoTinkEnumDependency<E>(String namespacePath, HashSet<Type> visited,
			Dictionary<String, Type> names, bool typed) where E : enum
		{
			if (!visited.Add(typeof(E)))
				return;
			let name = typeof(E).GetName(.. scope .());
			RequireAutoTinkName(typeof(E), namespacePath, name, names);
			if (namespacePath.IsEmpty)
				AddEnum<E>(name, typed);
			else
				AddNamespaceEnum<E>(namespacePath, name, typed);
		}

		internal void AddScopedClass(Type type, String namespacePath, String name)
		{
			if (namespacePath.IsEmpty)
			{
				if (CreateClass(type, name))
					mLua.SetGlobal(name);
				return;
			}
			if (FindNamespaceTable(namespacePath))
			{
				let fullName = scope String(namespacePath);
				fullName.Append('.');
				fullName.Append(name);
				mLua.PushString(name);
				if (CreateClass(type, fullName))
					mLua.RawSet(-3);
				else
					mLua.Pop(1);
				mLua.Pop(1);
			}
		}

		private void AutoTinkDependency<T, Exclusions, Flags>(Flags flags, String namespacePath,
			HashSet<Type> visited, Dictionary<String, Type> names)
			where Exclusions : struct, IMethodExclusionProvider
			where Flags : const AutoTinkFlags
		{
			if (!visited.Add(typeof(T)))
				return;
			AutoTinkClassImpl<T, Exclusions, const Flags, const false>(flags, namespacePath, visited, names, "", .Dependency);
		}

		[Comptime]
		private static void CollectAutoTinkDependency(Type type, AutoTinkFlags flags, HashSet<Type> dependencies)
		{
			if (type == null || flags == .None || type.IsGenericParam ||
				type == typeof(String) || type == typeof(StringView) || type == typeof(LuaTable))
				return;
			if (IsFunctionType(type) || IsDelegateType(type))
			{
				if (type.GetMethod("Invoke") case .Ok(let invoke))
				{
					CollectAutoTinkDependency(invoke.ReturnType, flags, dependencies);
					for (int i < invoke.ParamCount)
						CollectAutoTinkDependency(invoke.GetParamType(i), flags, dependencies);
				}
				return;
			}
			if (type.IsPointer || type is RefType || type.IsSizedArray)
			{
				CollectAutoTinkDependency(type.UnderlyingType, flags, dependencies);
				return;
			}
			if (type.IsArray || type.IsNullable || GetSpanElement(type) != null)
			{
				CollectAutoTinkDependency(((SpecializedGenericType)type).GetGenericArg(0), flags, dependencies);
				return;
			}
			if (type.IsTuple)
			{
				for (let field in type.GetFields(.Instance | .Public))
					CollectAutoTinkDependency(field.FieldType, flags, dependencies);
				return;
			}
			if (type.IsEnum)
			{
				if (flags.HasFlag(.IncludeEnums))
					dependencies.Add(type);
				return;
			}
			if (type.IsPrimitive || type.IsTypedPrimitive || type.IsInterface || type == typeof(Object))
				return;
			if ((type.IsStruct && flags.HasFlag(.IncludeStructs)) ||
				(type.IsObject && flags.HasFlag(.IncludeClasses)))
				dependencies.Add(type);
		}

		private void AutoTinkClassImpl<T, Exclusions, Flags, Inline>(Flags flags, String scopePath,
			HashSet<Type> visited, Dictionary<String, Type> names, String name, AutoTinkOrigin origin)
			where Exclusions : struct, IMethodExclusionProvider
			where Flags : const AutoTinkFlags
			where Inline : const bool
		{
			[Comptime]
			static void EmitAutoTinkClass<T, Exclusions, Flags, Inline>()
				where Exclusions : struct, IMethodExclusionProvider
				where Flags : const AutoTinkFlags
				where Inline : const bool
			{
				let type = typeof(T);
				if (type.IsGenericParam)
					return;
				let parentType = !Inline && type.IsObject && !type.IsStatic && type.BaseType != typeof(Object)
					? type.BaseType : null;

				HashSet<StringView> excluded = scope .();
				Exclusions.CollectExcludedMethods(type, excluded);

				let code = scope String();
				code.Append("if (registerMembers) {\n");
				HashSet<Type> dependencies = scope .();

				bool isConstructorEmitted = false;

				if (!Inline && !type.IsStatic)
				{
					code.Append("AddScopedClass(typeof(T), scopePath, className);\n");
					// Opaque native handles cannot be materialized as values.
					if (type.Size > 0)
						code.Append("AddClassMethod<T, function T(T)>(\"self\", (self) => self);\n");
				}

				code.Append("AddNamespace(namespacePath);\n");

				Dictionary<StringView, int> overloads = scope .();
				for (let method in type.GetMethods(.Public))
				{
					if ((Inline && !method.IsStatic) || !CanAutoTinkMethod(method) || excluded.Contains(method.Name))
						continue;
					if (overloads.TryAdd(method.Name, let keyPtr, let valuePtr))
						*valuePtr = 1;
					else
						*valuePtr += 1;
				}

				for (let (methodName, overloadCount) in overloads)
				{
					if (overloadCount <= 1)
						@methodName.Remove();
				}

				for (let method in type.GetMethods())
				{
					if (method.IsDestructor || method.Name.Contains("$") || method.IsMixin || method.IsAbstract || !method.IsPublic)
						continue;

					// Ignore generics
					if (method.GenericArgCount > 0)
						continue;

					// Ignore comptime/intrinsics.
					if (method.HasCustomAttribute<ComptimeAttribute>() || method.HasCustomAttribute<IntrinsicAttribute>())
						continue;

					// Ignore unchecked methods.
					if (method.HasCustomAttribute<UncheckedAttribute>())
						continue;

					// Ignore methods from base classes.
					if (method.DeclaringType != type)
						continue;

					if ((Inline && !method.IsStatic) || !CanAutoTinkMethod(method) || excluded.Contains(method.Name))
						continue;

					// Ignore operators.
					if (method.Name.Length == 0)
						continue;

					// Properties/Indexers are handled later.
					if (method.Name.StartsWith("get__") ||
						method.Name.StartsWith("set__"))
						continue;

					if (method.IsConstructor && (method.IsStatic || type.IsAbstract))
						continue;

					CollectAutoTinkDependency(method.ReturnType, Flags, dependencies);
					for (int i < method.ParamCount)
						CollectAutoTinkDependency(method.GetParamType(i), Flags, dependencies);

					if (method.IsConstructor)
					{
						if (isConstructorEmitted)
							continue;

						code.Append("AddClassCtor<T>();\n");
						isConstructorEmitted = true;
						continue;
					}

					if (overloads.ContainsKey(method.Name) || GetRequiredParameterCount(method) < GetFixedParameterCount(method))
					{
						if (overloads.TryGetValue(method.Name, let count) && count == -1)
							continue;
						overloads[method.Name] = -1;

						if (method.IsStatic)
							code.AppendF($"AddNamespaceMethod<T, const \"{method.Name}\">(namespacePath);\n");
						else
							code.AppendF($"AddClassMethod<T, const \"{method.Name}\">();\n");
					}
					else
					{
						String methodParams = scope .();

						if (!method.IsStatic)
						{
							if (type.IsStruct && method.IsMutating)
								methodParams.Append("mut ");
							methodParams.Append("T this");
						}

						for (int i < method.ParamCount)
						{
							if (!methodParams.IsEmpty)
								methodParams.Append(", ");

							if (method.GetParamFlags(i).HasFlag(.Params))
								methodParams.AppendF("params ");

							let paramType = method.GetParamType(i);

							if (var retParamType = paramType as RefType)
							{
								switch (retParamType.RefKind)
								{
								case .Ref:
									methodParams.Append("ref ");
								case .Out:
									methodParams.Append("out ");
								default:
									Runtime.FatalError(scope $"Not implemented {retParamType.RefKind}!");
								}
							}

							methodParams.AppendF($"comptype({paramType.GetTypeId()})");
						}

						String retTypeCode = scope .();
						retTypeCode.AppendF($"comptype({method.ReturnType.GetTypeId()})");

						if (method.IsStatic)
							code.AppendF($"AddNamespaceMethod<function {retTypeCode}({methodParams})>(namespacePath, \"{method.Name}\", => T.{method.Name});\n");
						else
							code.AppendF($"AddClassMethod<T, function {retTypeCode}({methodParams})>(\"{method.Name}\", => T.{method.Name});\n");
					}
				}

				for (let field in type.GetFields())
				{
					if ((Inline && !field.IsStatic) || field.Name.Contains("$") || !field.IsPublic)
						continue;

					// Ignore fields from base classes.
					if (field.DeclaringType != type)
						continue;

					if (!field.IsStatic || (!field.IsConst && !field.IsReadOnly))
						CollectAutoTinkDependency(field.FieldType, Flags, dependencies);

					if (field.IsStatic)
					{
						if (!field.IsConst && !field.IsReadOnly)
							code.AppendF($"AddNamespaceVar<T, const \"{field.Name}\">(namespacePath);\n");
					}
					else
						code.AppendF($"AddClassVar<T, const \"{field.Name}\">();\n");
				}

				Dictionary<StringView, PropertyBase> properties = scope .();
				GetTypeProperties(type, properties);

				for (let (name, info) in properties)
				{
					if (Inline || info.DeclaringType != type)
						continue;

					if (let indexerInfo = info as IndexerProperty)
					{
						if (indexerInfo.Parameters.IsEmpty || indexerInfo.Parameters.Count > 1)
							continue;
						CollectAutoTinkDependency(indexerInfo.Type, Flags, dependencies);
						CollectAutoTinkDependency(indexerInfo.Parameters[0].type, Flags, dependencies);
						code.AppendF($"AddClassIndexer<T, comptype({indexerInfo.Parameters[0].type.GetTypeId()})>();\n");
					}
					else if (let propertyInfo = info as NormalProperty)
					{
						// TODO: Static
						if (propertyInfo.IsStatic)
							continue;
						CollectAutoTinkDependency(propertyInfo.Type, Flags, dependencies);
						if (propertyInfo.GetterReturnsRef || propertyInfo.GetterIsMutating || propertyInfo.SetterTakesRef)
						{
							// TODO: Make this work through normal means.
							code.AppendF($"AddClassProperty<T, const \"{name}\">();\n");
							continue;
						}
						code.Append(type.IsStruct ? "AddStructProperty" : "AddClassProperty");
						switch (propertyInfo.Methods)
						{
						case .GetSet:
							code.AppendF($"<T, comptype({propertyInfo.Type.GetTypeId()})>(\"{name}\", (self) => self.{name}, (self, value) => self.{name} = value);\n");
						case .Get:
							code.AppendF($"<T, comptype({propertyInfo.Type.GetTypeId()})>(\"{name}\", (self) => self.{name}, null);\n");
						case .Set:
							code.AppendF($"<T, comptype({propertyInfo.Type.GetTypeId()})>(\"{name}\", null, (self, value) => self.{name} = value);\n");
						default:
							Runtime.FatalError("Unexpected state");
						}
					}
				}

				code.Append("}\n");
				if (parentType != null)
					dependencies.Add(parentType);
				for (let dependency in dependencies)
				{
					if (dependency == type)
						continue;
					if (dependency.IsEnum)
					{
						let typed = Flags.HasFlag(.TypedEnums) ? "true" : "false";
						code.AppendF($"AutoTinkEnumDependency<comptype({dependency.GetTypeId()})>(scopePath, visited, names, {typed});\n");
					}
					else
					{
						code.AppendF($"AutoTinkDependency<comptype({dependency.GetTypeId()}), Exclusions, const ((AutoTinkFlags){(int)Flags})>((AutoTinkFlags){(int)Flags}, scopePath, visited, names);\n");
					}
				}
				if (parentType != null)
					code.AppendF($"if (mTinkerState.IsClassRegistered<comptype({parentType.GetTypeId()})>()) AddClassParent<T, comptype({parentType.GetTypeId()})>();\n");

				Compiler.MixinRoot(code);
			}

			let registerMembers = origin == .Root || typeof(T).IsStatic || !mTinkerState.IsClassRegistered<T>();
			String className = scope .();
			AppendScopeClassName(typeof(T), name, className);
			String namespacePath = scope String(scopePath);
			if (!Inline)
			{
				if (!namespacePath.IsEmpty)
					namespacePath.Append('.');
				namespacePath.Append(className);
				if (registerMembers || mTinkerState.GetClassName<T>() == namespacePath)
					RequireAutoTinkName(typeof(T), scopePath, className, names);
			}

#unwarn
			EmitAutoTinkClass<T, Exclusions, const Flags, const Inline>();
		}
	}
}
