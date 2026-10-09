using System;
using System.Reflection;
using System.Collections;
using LuaTinker.Helpers;

namespace LuaTinker.Helpers
{
	static
	{
		[Comptime]
		public static bool CanAutoTinkMethod(MethodInfo method)
		{
			// Corlib exposes no public function/delegate predicate; inspect its flags without changing corlib visibility.
			if (method.ReturnType.[Friend]mTypeFlags.HasFlag(.Delegate))
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
					if (refType.RefKind != .Ref)
						return false;
					paramType = refType.UnderlyingType;
					// Pointer-valued out/ref needs a mutable pointer cell, not a pointer to the target.
					if (paramType.IsPointer)
						return false;
				}

				if (paramType.[Friend]mTypeFlags.HasFlag(.Function) ||
					paramType.[Friend]mTypeFlags.HasFlag(.Delegate))
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
	extension LuaTinker
	{
		/// Automatically binds a Beef class to Lua using its type name.
		[Inline]
		public void AutoTinkClass<T>()
			=> AutoTinkClass<T, const "">();
		
		/// Automatically binds a Beef class to Lua using a provided name.
		[Inline]
		public void AutoTinkClass<T, Name>()
			where Name : const String
			=> AutoTinkClass<T, const Name, NoMethodExclusions>();
		
		/// Automatically binds a Beef class using compile-time reflection.
		/// A method-exclusion provider runs once per expansion; each excluded name
		/// removes all overloads. Unsupported signatures are always excluded.
		public void AutoTinkClass<T, Name, Exclusions>()
			where Name : const String
			where Exclusions : struct, IMethodExclusionProvider
		{
			[Comptime]
			static void EmitAutoTinkClass<T, Name, Exclusions>()
				where Name : const String
				where Exclusions : struct, IMethodExclusionProvider
			{
				let type = typeof(T);
				if (type.IsGenericParam)
					return;

				HashSet<StringView> excluded = scope .();
				Exclusions.CollectExcludedMethods(type, excluded);

				let code = scope String();

				bool isConstructorEmitted = false;

				if (!type.IsStatic)
				{
					code.AppendF($"AddClass<T>(\"{Name}\");\n");
					code.Append("AddClassMethod<T, function T(T)>(\"self\", (self) => self);\n");
				}

				code.AppendF($"AddNamespace(\"{type.GetFullName(.. scope .())}\");\n");

				Dictionary<StringView, int> overloads = scope .();
				for (let method in type.GetMethods(.Public))
				{
					if (!CanAutoTinkMethod(method) || excluded.Contains(method.Name))
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
					if (method.IsDestructor || method.Name.Contains("$") || method.IsMixin || !method.IsPublic)
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

					if (!CanAutoTinkMethod(method) || excluded.Contains(method.Name))
						continue;

					// Ignore operators.
					if (method.Name.Length == 0)
						continue;

					// Properties/Indexers are handled later.
					if (method.Name.StartsWith("get__") ||
						method.Name.StartsWith("set__"))
						continue;

					if (method.IsConstructor)
					{
						if (method.IsStatic || type.IsAbstract)
							continue;

						if (isConstructorEmitted)
							continue;

						code.Append("AddClassCtor<T>();\n");
						isConstructorEmitted = true;
						continue;
					}

					if (overloads.ContainsKey(method.Name))
					{
						if (overloads[method.Name] == -1)
							continue;
						overloads[method.Name] = -1;

						if (method.IsStatic)
							code.AppendF($"AddNamespaceMethod<T, const \"{method.Name}\">(\"{type.GetFullName(.. scope .())}\");\n");
						else
							code.AppendF($"AddClassMethod<T, const \"{method.Name}\">();\n");
					}
					else
					{
						String methodParams = scope .();

						if (!method.IsStatic)
							methodParams.AppendF($"T this");

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
								default:
									Runtime.FatalError(scope $"Not implemented {retParamType.RefKind}!");
								}
							}

							methodParams.AppendF($"comptype({paramType.GetTypeId()})");
						}

						String retTypeCode = scope .();
						retTypeCode.AppendF($"comptype({method.ReturnType.GetTypeId()})");

						if (method.IsStatic)
							code.AppendF($"AddNamespaceMethod<function {retTypeCode}({methodParams})>(\"{type.GetFullName(.. scope .())}\", \"{method.Name}\", => T.{method.Name});\n");
						else
							code.AppendF($"AddClassMethod<T, function {retTypeCode}({methodParams})>(\"{method.Name}\", => T.{method.Name});\n");
					}
				}

				for (let field in type.GetFields())
				{
					if (field.Name.Contains("$") || !field.IsPublic)
						continue;

					// Ignore fields from base classes.
					if (field.DeclaringType != type)
						continue;

					if (!field.IsStatic)
						code.AppendF($"AddClassVar<T, const \"{field.Name}\">();\n");
				}

				Dictionary<StringView, PropertyBase> properties = scope .();
				GetTypeProperties(type, properties);

				for (let (name, info) in properties)
				{
					if (info.DeclaringType != type)
						continue;

					if (let indexerInfo = info as IndexerProperty)
					{
						if (indexerInfo.Parameters.IsEmpty || indexerInfo.Parameters.Count > 1)
							continue;
						code.AppendF($"AddClassIndexer<T, comptype({indexerInfo.Parameters[0].type.GetTypeId()})>();\n");
					}
					else if (let propertyInfo = info as NormalProperty)
					{
						// TODO: Static
						if (propertyInfo.IsStatic)
							continue;
						switch (propertyInfo.Methods)
						{
						case .GetSet:
							code.AppendF($"AddClassProperty<T, comptype({propertyInfo.Type.GetTypeId()})>(\"{name}\", (self) => self.{name}, (self, value) => self.{name} = value);\n");
						case .Get:
							code.AppendF($"AddClassProperty<T, comptype({propertyInfo.Type.GetTypeId()})>(\"{name}\", (self) => self.{name}, null);\n");
						case .Set:
							code.AppendF($"AddClassProperty<T, comptype({propertyInfo.Type.GetTypeId()})>(\"{name}\", null, (self, value) => self.{name} = value);\n");
						default:
							Runtime.FatalError("Unexpected state");
						}
					}
				}

				Compiler.MixinRoot(code);
			}

#unwarn
			EmitAutoTinkClass<T, const Name, Exclusions>();
		}
	}
}
