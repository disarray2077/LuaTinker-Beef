using System;
using System.Interop;
using System.Diagnostics;
using System.Reflection;
using System.Collections;

using LuaTinker.Helpers;
using LuaTinker.Layers;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;

using KeraLua;

using internal KeraLua;

namespace LuaTinker
{
	public class LuaTinker
	{
		private Lua mLua;
		private LuaUserdataAllocator mUserdataAllocator;
		private LuaTinkerState mTinkerState;

		/// Initializes a new instance of the LuaTinker class.
		/// @param lua The KeraLua state to wrap.
		public this(Lua lua)
		{
			mLua = lua;
			mUserdataAllocator = .(lua);
			Init();

			mTinkerState = lua.TinkerState;
		}

		public ~this()
		{
			Debug.Assert(mLua.TinkerState == mTinkerState);
			//Debug.Assert(mLua.GetTop() == 0);
#if TEST
			GC.Collect(false);
#endif
		}

#if !DEBUG
		[SkipCall]
#endif
		internal void DebugEnumStack()
		{
			Debug.WriteLine(StackHelper.EnumStack(mLua, .. scope .()));
		}

		private void Init()
		{
			// Add GC Mate
			mLua.CreateTable(0, 2);
			mLua.PushString("__gc");
			mLua.PushCClosure(=> PointerDestructorLayer, 0);
			mLua.RawSet(-3);
			mLua.PushString("__tostring");
			mLua.PushCClosure(=> PointerToStringLayer, 0);
			mLua.RawSet(-3);
			mLua.SetGlobal("__noreg_meta");
		}

		/// Registers an enumeration type in the Lua global scope.
		/// Creates a Lua table where keys are the enum member names and values are their integer equivalents.
		/// @param name The name to use for the enum table in Lua. If empty, the type's name is used.
		public void AddEnum<E>(String name = String.Empty)
			where E : enum
		{
			var name;
			if (name.IsEmpty)
				name = typeof(E).GetName(.. scope:: String());

			mLua.CreateTable(0, typeof(E).FieldCount);

			for (let field in typeof(E).GetFields())
			{
				mLua.PushString(field.Name);
				mLua.PushInteger(field.[Friend]mFieldData.[Friend]mData);
				mLua.SetTable(-3);
			}

			mLua.SetGlobal(name);
		}

		/// Registers a function pointer as a global function in Lua.
		/// @param name The name of the function in the Lua global scope.
		/// @param func The function to register.
		public void AddMethod<F>(String name, F func) where F : var, struct
		{
			mLua.PushLightUserData(func);
			mLua.PushCClosure(=> CallLayer<F>, 1);
			mLua.SetGlobal(name);
		}

		/// Registers a delegate as a global function in Lua.
		/// @param name The name of the function in the Lua global scope.
		/// @param func The delegate instance to register.
		public void AddMethod<F>(String name, F func) where F : var, class
		{
			Debug.AssertNotStack(func);
			mTinkerState.RegisterAliveObject(func);

			new:mUserdataAllocator ClassInstanceWrapper<F>(func, true);
			// register destructor
			{
			    mLua.CreateTable(0, 2);
			    mLua.PushString("__gc");
			    mLua.PushCClosure(=> PointerDestructorLayer, 0);
			    mLua.RawSet(-3);
				mLua.PushString("__tostring");
				mLua.PushCClosure(=> PointerToStringLayer, 0);
				mLua.RawSet(-3);
			    mLua.SetMetaTable(-2);
			}
			mLua.PushCClosure(=> DelegateCallLayer<F>, 1);
			mLua.SetGlobal(name);
		}
		
		/// Automatically binds a Beef class to Lua using its type name.
		[Inline]
		public void AutoTinkClass<T>()
			=> AutoTinkClass<T, const "">();

		/// Automatically binds a Beef class to Lua using compile-time reflection.
		/// This function generates bindings for public constructors, methods, fields, properties, and indexers.
		/// @where Name A compile-time string specifying the class name in Lua. If empty, the type's name is used.
		public void AutoTinkClass<T, Name>()
			where Name : const String
		{
			[Comptime]
			static void EmitAutoTinkClass<T, Name>()
				where Name : const String
			{
				let type = typeof(T);
				if (type.IsGenericParam)
					return;

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
				
				methodLoop: for (let method in type.GetMethods())
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
								case .Out:
									// Let's just ignore this method for now...
									// TODO: Maybe convert the Beef method with out parameter to a multi-return method in lua?
									continue methodLoop;
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

				fieldLoop: for (let field in type.GetFields())
				{
					if (field.Name.Contains("$") || !field.IsPublic)
						continue;

					// Ignore fields from base classes.
					if (field.DeclaringType != type)
						continue;

					if (field.IsStatic)
						NOP!();//code.AppendF($"AddNamespaceVar(\"{type.GetFullName(.. scope .())}\");\n");
					else
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

			/*
			[Comptime]
			static void Emit<T>()
			{
				if (typeof(T).IsGenericParam)
					return;

				String code = scope .();

				List<Type> inheritanceChain = scope .();
				for (var type = typeof(T); type != typeof(Object) && type != null; type = type.BaseType)
					inheritanceChain.Add(type);

				for (let type in inheritanceChain.Reversed)
				{
					if (type != typeof(T))
					{
						code.AppendF(
							$"""
							if (!mTinkerState.IsClassRegistered<comptype({type.GetTypeId()})>())
								AutoTinkClass<comptype({type.GetTypeId()})>();\n
							""");
					}
				}

				code.Append("EmitAutoTinkClass<T, const Name>();");
				Compiler.MixinRoot(code);
			}
			*/

#unwarn
			EmitAutoTinkClass<T, const Name>();
		}

		/// Registers a Beef class type in Lua.
		/// This creates a global table that will serve as the metatable for instances of this class.
		/// @param name The name to use for the class in Lua. If empty, the type's name is used.
		public void AddClass<T>(String name = String.Empty)
		{
			var name;
			if (name.IsEmpty)
			{
				name = typeof(T).GetName(.. scope:: String());
				if (let specializedType = typeof(T) as SpecializedGenericType)
				{
					for (int i < specializedType.GenericParamCount)
						name.Append(specializedType.GetGenericArg(i).GetName(.. scope:: String()));
				}
			}

			mTinkerState.SetClassName<T>(name);

			mLua.CreateTable(0, 5);

			mLua.PushString("__name");
			mLua.PushString(name);
			mLua.RawSet(-3);

			mLua.PushString("__index");
			mLua.PushCClosure(=> MetaGetLayer, 0);
			mLua.RawSet(-3);

			mLua.PushString("__newindex");
			mLua.PushCClosure(=> MetaSetLayer, 0);
			mLua.RawSet(-3);

			mLua.PushString("__gc");
			mLua.PushCClosure(=> PointerDestructorLayer, 0);
			mLua.RawSet(-3);

			mLua.PushString("__tostring");
			mLua.PushCClosure(=> PointerToStringLayer, 0);
			mLua.RawSet(-3);

			mLua.SetGlobal(name);
		}

		/// Establishes an inheritance relationship between two registered classes in Lua.
		/// @where T The child class type.
		/// @where P The parent class type.
		public void AddClassParent<T, P>()
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString("__parent");
				mLua.GetGlobal(mTinkerState.GetClassName<P>());
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Binds the constructors of a class, making the class table callable in Lua to create new instances.
		/// This version dynamically finds a matching constructor at runtime.
		public void AddClassCtor<T>()
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.CreateTable(0, 2);
				mLua.PushString("__call");
				mLua.PushCClosure(=> DynamicCreatorLayer<T>, 0);
				mLua.RawSet(-3);
				mLua.PushString("__tostring");
				mLua.PushCClosure(=> ConstructorToStringLayer<T>, 0);
				mLua.RawSet(-3);
				mLua.SetMetaTable(-2);
			}
			mLua.Pop(1);
		}

		/// Binds a specific constructor of a class, making the class table callable in Lua.
		/// @where Args A single argument type or a tuple representing the constructor's argument types.
		public void AddClassCtor<T, Args>()
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.CreateTable(0, 2);
				mLua.PushString("__call");
				mLua.PushCClosure(=> CreatorLayer<T, Args>, 0);
				mLua.RawSet(-3);
				mLua.PushString("__tostring");
				mLua.PushCClosure(=> ConstructorToStringLayer<T>, 0);
				mLua.RawSet(-3);
				mLua.SetMetaTable(-2);
			}
			mLua.Pop(1);
		}

		/// Binds an indexer (e.g., `obj[key]`) for a class.
		/// This allows accessing class indexers from Lua using standard table syntax.
		/// @where TKey The key type of the indexer.
		public void AddClassIndexer<T, TKey>()
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (!mLua.IsTable(-1))
			{
				mLua.Pop(1);
				return;
			}

			mLua.PushString("__bfindexer");
			mLua.RawGet(-2);

			let existingIndexer = User2Type.GetTypePtr<IndexerWrapperBase>(mLua, -1);
			mLua.Pop(1);

			if (existingIndexer == null)
			{
				mLua.PushString("__bfindexer");
				new:mUserdataAllocator IndexerWrapper<T, TKey>();
				mLua.RawSet(-3);
			}
			else if (var aggregator = existingIndexer as IndexerAggregatorWrapper)
			{
				let indexer = new IndexerWrapper<T, TKey>();
				mTinkerState.RegisterAliveObject(indexer);
				aggregator.AddIndexer(typeof(TKey), indexer);
			}
			else
			{
				var newAggregator = new:mUserdataAllocator IndexerAggregatorWrapper();

				let existingIndexerClone = existingIndexer.CreateNew();
				let newIndexer = new IndexerWrapper<T, TKey>();
				mTinkerState.RegisterAliveObject(existingIndexerClone);
				mTinkerState.RegisterAliveObject(newIndexer);

				newAggregator.AddIndexer(existingIndexer.KeyType, existingIndexerClone);
				newAggregator.AddIndexer(typeof(TKey), newIndexer);

				mLua.PushString("__bfindexer");
				mLua.PushValue(-2);
				// register destructor
				{
				    mLua.CreateTable(0, 1);
				    mLua.PushString("__gc");
				    mLua.PushCClosure(=> IndexerDestructorLayer, 0);
				    mLua.RawSet(-3);
				    mLua.SetMetaTable(-2);
				}
				mLua.RawSet(-4);

				mLua.Pop(1);
			}
			
			mLua.Pop(1);
		}

		/// Binds a function pointer as a method on a registered class.
		/// @where T The class type.
		/// @where F The function's type.
		/// @param name The name of the method in Lua.
		/// @param func The function pointer to bind.
		public void AddClassMethod<T, F>(String name, F func) where F : var, struct
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name);
				mLua.PushLightUserData(func);
				mLua.PushCClosure(=> CallLayer<F>, 1);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Binds a method by its name to a registered class.
		/// This version dynamically resolves overloads at runtime.
		/// @param name The name of the method in Lua.
		public void AddClassMethod<T, Name>(String name = "")
			where Name : const String
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name.IsEmpty ? Name : name);
				mLua.PushCClosure(=> DynamicCallLayer<T, const Name, false>, 0);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Binds a field by its name to a registered class.
		/// @param name The name of the field in Lua.
		public void AddClassVar<T, Name>(String name = "")
			where Name : const String
		{
			[Comptime]
			static void _Emit()
			{
				if (typeof(T).IsGenericParam)
				{
					Compiler.MixinRoot(
						scope $"""
						const int memberOffset = 0;
						const int memberTypeId = {typeof(void).GetTypeId()};
						""");
					return;
				}
				let fieldType = typeof(T).GetField(Name).Get().FieldType;
				Compiler.MixinRoot(
					scope $"""
					const int memberOffset = offsetof(T, {Name});
					const int memberTypeId = {fieldType.GetTypeId()};
					""");
			}
			_Emit();

			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name.IsEmpty ? Name : name);
				new:mUserdataAllocator ClassFieldWrapper<comptype(memberTypeId)>(memberOffset);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Binds a property by its name to a registered class.
		/// @param name The name of the property in Lua.
		public void AddClassProperty<T, Name>(String name = "")
			where Name : const String
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name.IsEmpty ? Name : name);
				new:mUserdataAllocator ClassPropertyWrapper<T, Name>();
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}
		
		/// Binds a property to a class using explicit getter and setter delegates.
		/// @param name The name of the property in Lua.
		/// @param getter The getter delegate. Can be null for a write-only property.
		/// @param setter The setter delegate. Can be null for a read-only property.
		public void AddClassProperty<T, TVar, TGet, TSet>(String name, TGet getter, TSet setter)
			where TGet : class, delegate TVar(T)
			where TSet : class, delegate void(T, TVar)
		{
			Debug.Assert(getter != null || setter != null, "Properties must have at least a getter or a setter");
			Debug.AssertNotStack(getter);
			Debug.AssertNotStack(setter);
			mTinkerState.RegisterAliveObject(getter);
			mTinkerState.RegisterAliveObject(setter);

			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name);
				new:mUserdataAllocator DelegatePropertyWrapper<T, TVar, TGet, TSet>(getter, setter);
				// register destructor
				{
				    mLua.CreateTable(0, 1);
				    mLua.PushString("__gc");
				    mLua.PushCClosure(=> VariableDestructorLayer, 0);
				    mLua.RawSet(-3);
				    mLua.SetMetaTable(-2);
				}
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Binds a property to a class using explicit getter and setter function pointers.
		// @param name The name of the property in Lua.
		/// @param getter The getter function. Can be null for a write-only property.
		/// @param setter The setter function. Can be null for a read-only property.
		public void AddClassProperty<T, TVar>(String name, function TVar(T) getter, function void(T, TVar) setter)
		{
			Debug.Assert(getter != null || setter != null, "Properties must have at least a getter or a setter");
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name);
				new:mUserdataAllocator FuncPropertyWrapper<T, TVar>(getter, setter);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Binds a property to a class using explicit getter and setter function pointers (with 'this' syntax).
		/// @param name The name of the property in Lua.
		/// @param getter The getter function. Can be null for a write-only property.
		/// @param setter The setter function. Can be null for a read-only property.
		public void AddClassProperty<T, TVar>(String name, function TVar(T this) getter, function void(T this, TVar) setter)
		{
			Debug.Assert(getter != null || setter != null, "Properties must have at least a getter or a setter");
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name);
				new:mUserdataAllocator FuncPropertyWrapper<T, TVar>(getter, setter);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Finds a Lua table corresponding to a namespace path and pushes it onto the stack.
		/// @param path A dot-separated namespace path (e.g., "MyLib.Utils").
		/// @return A result indicating whether the table was found and pushed successfully.
		private Result<bool> FindNamespaceTable(String path)
		{
			bool parentExists = false;

			for (var ns in path.Split('.'))
			{
				if (@ns.MatchIndex > 0)
				{
					// Get from the parent namespace table
					mLua.PushString(ns);
					mLua.RawGet(-2);
				}
				else
				{
					// Get from the global table
					mLua.GetGlobal(ns);
				}

				if (mLua.IsTable(-1))
				{
					if (parentExists)
					{
						// This namespace exists, so we don't need the parent of it anymore,
						// as we only need the very last existing one.
						mLua.Remove(-2);
					}

					if (!@ns.HasMore)
						return true;

					parentExists = true;
					continue;
				}
				else if (!mLua.IsNil(-1))
				{
					// This value isn't a table and isn't nil, so there's nothing that we can do.
					mLua.Pop(1);
					return .Err;
				}

				mLua.Pop(1);
				return false;
			}

			// This will only happen if the name is empty, but this isn't legal
			// so we just return an error.
			Debug.Assert(path.IsEmpty);
			return .Err;
		}

		/// Ensures a namespace (a nested table structure) exists in Lua. Creates it if it doesn't.
		/// @param path A dot-separated namespace path (e.g., "MyLib.Utils").
		/// @return True if the table was created, otherwise false.
		public bool AddNamespace(String path)
		{
			bool parentExists = false;
			bool first = true;
			bool globalSet = false;

			for (var ns in path.Split('.'))
			{
				if (@ns.MatchIndex > 0)
				{
					// Get from the parent namespace table
					mLua.PushString(ns);
					mLua.RawGet(-2);
				}
				else
				{
					// Get from the global table
					mLua.GetGlobal(ns);
				}

				if (mLua.IsTable(-1))
				{
					if (parentExists)
					{
						// This namespace exists, so we don't need the parent of it anymore,
						// as we only need the very last existing one.
						mLua.Remove(-2);
					}

					if (!@ns.HasMore)
					{
						// The namespace we want to add already exists.
						mLua.Pop(1);
						return false;
					}

					parentExists = true;
					continue;
				}
				else if (!mLua.IsNil(-1))
				{
					// This value isn't a table and isn't nil, so there's nothing that we can do.
					mLua.Pop(1);
					return false;
				}

				mLua.Pop(1);

				if (@ns.MatchIndex > 0)
					mLua.PushString(ns);

				mLua.CreateTable(0, 3);

				mLua.PushString("__name");
				mLua.PushString(ns);
				mLua.RawSet(-3);

				mLua.PushString("__index");
				mLua.PushCClosure(=> MetaGetLayer, 0);
				mLua.RawSet(-3);

				mLua.PushString("__newindex");
				mLua.PushCClosure(=> MetaSetLayer, 0);
				mLua.RawSet(-3);

				if (@ns.MatchIndex == 0)
				{
					if (@ns.HasMore)
					{
						// SetGlobal already pops the value from the stack.
						globalSet = true;
						defer:: {
							mLua.SetGlobal(path.Substring(0, path.IndexOf('.')));
						}
					}
					else
					{
						// Just set the namespace in the global table, as we will exit the loop anyway.
						mLua.SetGlobal(ns);
					}
				}
				else
				{
					if (first && !globalSet)
					{
						first = false;
						defer:: {
							mLua.RawSet(-3);
							mLua.Pop(1);
						}
					}
					else
					{
						defer:: {
							mLua.RawSet(-3);
						}
					}
				}
			}

			return true;
		}

		/// Creates a new nested table in Lua.
		/// @param path A dot-separated path for the table.
		public void NewTable(String path)
			=> AddNamespace(path);

		/// Registers an enumeration type within a specified Lua namespace.
		/// @param namespacePath The dot-separated path to the target namespace table.
		/// @param enumName The name for the enum table in Lua. If empty, the type's name is used.
		public void AddNamespaceEnum<E>(String namespacePath, String enumName = String.Empty)
			where E : enum
		{
			if (FindNamespaceTable(namespacePath))
			{
				var enumName;
				if (enumName.IsEmpty)
					enumName = typeof(E).GetName(.. scope:: String());

				mLua.PushString(enumName);
				mLua.CreateTable(0, typeof(E).FieldCount);
	
				for (let field in typeof(E).GetFields())
				{
					mLua.PushString(field.Name);
					mLua.PushInteger(field.[Friend]mFieldData.[Friend]mData);
					mLua.SetTable(-3);
				}

				mLua.RawSet(-3);
			}

			mLua.Pop(1);
		}

		/// Binds a function pointer as a method within a specified Lua namespace.
		/// @param namespacePath The dot-separated path to the target namespace table.
		/// @param methodName The name of the function in the namespace.
		/// @param func The function to bind.
		public void AddNamespaceMethod<F>(String namespacePath, String methodName, F func) where F : var, struct
		{
			if (FindNamespaceTable(namespacePath))
			{
				mLua.PushString(methodName);
				mLua.PushLightUserData(func);
				mLua.PushCClosure(=> CallLayer<F>, 1);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Binds a delegate as a method within a specified Lua namespace.
		/// @param namespacePath The dot-separated path to the target namespace table.
		/// @param methodName The name of the function in the namespace.
		/// @param func The delegate to bind.
		public void AddNamespaceMethod<F>(String namespacePath, String methodName, F func) where F : var, class
		{
			mTinkerState.RegisterAliveObject(func);

			if (FindNamespaceTable(namespacePath))
			{
				mLua.PushString(methodName);
				new:mUserdataAllocator ClassInstanceWrapper<F>(func, true);
				// register destructor
				{
				    mLua.CreateTable(0, 2);
				    mLua.PushString("__gc");
				    mLua.PushCClosure(=> PointerDestructorLayer, 0);
				    mLua.RawSet(-3);
					mLua.PushString("__tostring");
					mLua.PushCClosure(=> PointerToStringLayer, 0);
					mLua.RawSet(-3);
				    mLua.SetMetaTable(-2);
				}
				mLua.PushCClosure(=> DelegateCallLayer<F>, 1);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Binds a static method by its name into a specified Lua namespace.
		/// @param namespacePath The dot-separated path to the target namespace table.
		/// @param name The name of the method in Lua.
		public void AddNamespaceMethod<T, Name>(String namespacePath, String name = "")
			where Name : const String
		{
			if (FindNamespaceTable(namespacePath))
			{
				mLua.PushString(name.IsEmpty ? Name : name);
				mLua.PushCClosure(=> DynamicCallLayer<T, const Name, true>, 0);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Adds a variable by value to a specified Lua namespace.
		/// @param namespacePath The dot-separated path to the target namespace table.
		/// @param varName The name of the variable.
		/// @param value The value to set.
		public void AddNamespaceVar<TVar>(String namespacePath, String varName, TVar value)
			where TVar : var
		{
			if (FindNamespaceTable(namespacePath))
			{
				mLua.PushString(varName);
				StackHelper.Push(mLua, value);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// Adds a variable by reference to a specified Lua namespace.
		/// @param namespacePath The dot-separated path to the target namespace table.
		/// @param varName The name of the variable.
		/// @param value A reference to the value to set.
		public void AddNamespaceVar<TVar>(String namespacePath, String varName, ref TVar value)
			where TVar : var
		{
			if (FindNamespaceTable(namespacePath))
			{
				mLua.PushString(varName);
				StackHelper.Push(mLua, ref value);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		/// A mixin that checks for a LuaTinker error and propagates it.
		/// @param val The value to return if there is no error.
		/// @return An error result if an error exists, otherwise the input value.
		private mixin TryTinker(var val)
		{
			if (mTinkerState.HasError)
				return .Err(mTinkerState.GetLastError());
			val
		}
		
		/// Calls a global Lua function with no arguments and expects no return value.
		/// @param name The name of the global Lua function to call.
		/// @return A result indicating success or an error message.
		[Inline]
		public Result<void, StringView> Call(StringView name)
			=> Call<void, void>(name, default);
		
		/// Calls a global Lua function with no arguments and expects a single return value.
		/// @where RVal The expected return type.
		/// @param name The name of the global Lua function to call.
		/// @return A result containing the return value or an error message.
		[Inline]
		public Result<RVal, StringView> Call<RVal>(StringView name)
			=> Call<RVal, void>(name, default);

		/// Calls a global Lua function with arguments and expects a return value.
		/// @where RVal The expected return type. Use `void` for no return value.
		/// @where Args The type of the arguments. Can be a single value or a tuple for multiple arguments.
		/// @param name The name of the global Lua function to call.
		/// @param args The arguments to pass to the Lua function. Can be a single value or a tuple for multiple arguments.
		/// @return A result containing the return value or an error message.
		public Result<RVal, StringView> Call<RVal, Args>(StringView name, Args args)
			where RVal : var
			where Args : var
		{
			[Comptime]
			static int EmitCallPushes<Args>()
			{
				let type = typeof(Args);
				let code = scope String();

				int fieldCount = 0;
				if (type.IsTuple)
				{
					fieldCount = type.FieldCount;
					for (int i = 0; i < fieldCount; i++)
						code.AppendF($"StackHelper.Push(mLua, args.{i});\n");
				}
				else if (type != typeof(void))
				{
					fieldCount = 1;
					code.Append("StackHelper.Push(mLua, args);\n");
				}

				Compiler.MixinRoot(code);
				return fieldCount;
			}

			Debug.Assert(mLua.GetTop() == 0);
			const int32 results = typeof(RVal) == typeof(void) ? 0 : 1;
			mTinkerState.ClearError();
			
			mLua.GetGlobal(name);
			if (mLua.IsFunction(-1))
			{
				int argc = EmitCallPushes<Args>();
				if (mLua.PCall((.)argc, results, 0) != .OK)
				{
					mTinkerState.SetLastError(StackHelper.Pop!<StringView>(mLua, -1));
					return .Err(mTinkerState.GetLastError());
				}
			}
			else
			{
				mTinkerState.SetLastError($"attempt to call global '{name}' (not a function)");
				return .Err(mTinkerState.GetLastError());
			}

			if (results == 1)
			{
				defer mLua.Pop(1);
				return .Ok(TryTinker!(StackHelper.Pop<RVal>(mLua, -1)));
			}

			// TODO: Support for tuples

			// TODO: Remove the #unwarn when the compiler bug is solved.
#unwarn // COMPILER-BUG: The compiler thinks that this return is unreachable.
			return .Ok(default);
		}

		/// Finds and pushes the parent table of a dot-separated path onto the Lua stack.
		/// @param path The full path to the variable.
		/// @param finalKey An out parameter that will contain the final key in the path.
		/// @return True if the parent table was found and pushed, false otherwise.
		private bool FindAndPushParentTable(StringView path, out StringView finalKey)
		{
			int lastDot = path.LastIndexOf('.');
			if (lastDot == -1)
			{
				finalKey = path;
				return true;
			}

			finalKey = path.Substring(lastDot + 1);
			var tablePath = path.Substring(0, lastDot);

			bool first = true;
			for (var segment in tablePath.Split('.'))
			{
				if (first)
				{
					mLua.GetGlobal(segment);
					first = false;
				}
				else
				{
					mLua.PushString(segment);
					mLua.GetTable(-2);
					mLua.Remove(-2);
				}

				if (!mLua.IsTable(-1))
				{
					mLua.Pop(1);
					return false;
				}
			}

			return true;
		}

		/// Gets the value of a global Lua variable.
		/// @param name The name of the global variable.
		/// @return A result containing the value or an error message.
		public Result<T, StringView> GetValue<T>(StringView name) where T : var
		{
			Debug.Assert(mLua.GetTop() == 0);
			mTinkerState.ClearError();

			mLua.GetGlobal(name);
			defer mLua.Pop(1);

			if (mLua.IsNil(-1) || !StackHelper.CheckMetaTableValidity<T>(mLua, -1))
			{
				mTinkerState.SetLastError($"can't convert global '{name}' ({mLua.TypeName(-1)}) to '{typeof(T)}'");
				return .Err(mTinkerState.GetLastError());
			}

			return .Ok(TryTinker!(StackHelper.Pop<T>(mLua, -1)));
		}

		/// Gets the value of a global Lua variable.
		/// @param name The name of the global variable.
		/// @return A result containing the value or an error message.
		public Result<T, StringView> GetValue<T>(StringView name) where T : class
		{
			Debug.Assert(mLua.GetTop() == 0);
			mTinkerState.ClearError();

			mLua.GetGlobal(name);
			defer mLua.Pop(1);

			if (!mLua.IsNil(-1) && !StackHelper.CheckMetaTableValidity<T>(mLua, -1))
			{
				mTinkerState.SetLastError($"can't convert global '{name}' ({mLua.TypeName(-1)}) to '{typeof(T)}'");
				return .Err(mTinkerState.GetLastError());
			}

			return .Ok(TryTinker!(StackHelper.Pop<T>(mLua, -1)));
		}

		/// Gets the value of a global Lua variable.
		/// @param name The name of the global variable.
		/// @return A result containing the value or an error message.
		public Result<T, StringView> GetValue<T>(StringView name) where T : struct*
		{
			Debug.Assert(mLua.GetTop() == 0);
			mTinkerState.ClearError();

			mLua.GetGlobal(name);
			defer mLua.Pop(1);

			if (!mLua.IsNil(-1) && !StackHelper.CheckMetaTableValidity<T>(mLua, -1))
			{
				mTinkerState.SetLastError($"can't convert global '{name}' ({mLua.TypeName(-1)}) to '{typeof(T)}'");
				return .Err(mTinkerState.GetLastError());
			}

			return .Ok(TryTinker!(StackHelper.Pop<T>(mLua, -1)));
		}

		[Error("Use the \"GetString\" mixin instead, or get a StringView if you don't need a String instance")]
		public Result<T, StringView> GetValue<T>(StringView name) where T : String where String : T
		{
			Runtime.NotImplemented();
		}

		/// Gets the value of a global Lua variable as a String.
		/// This mixin will allocate a String in the stack if necessary, and returns a `Result<String, StringView>`.
		/// @param name The name of the global variable.
		public mixin GetString(StringView name)
		{
			Debug.Assert(mLua.GetTop() == 0);
			mTinkerState.ClearError();
			Result<String, StringView> result;

			mLua.GetGlobal(name);
			defer mLua.Pop(1);

			if (mLua.IsNil(-1))
			{
				mTinkerState.SetLastError($"can't convert global '{name}' ({mLua.TypeName(-1)}) to 'System.String'");
				result = .Err(mTinkerState.GetLastError());
			}
			else
			{
				result = .Ok(StackHelper.Pop!:mixin<String>(mLua, -1));
				if (mTinkerState.HasError)
					result = .Err(mTinkerState.GetLastError());
			}

			result
		}

		/// Gets the value of a global Lua variable as a number (double).
		/// @param name The name of the global variable.
		/// @return A result containing the double value or an error message.
		[Inline]
		public Result<double, StringView> GetNumber(StringView name)
			=> GetValue<double>(name);

		/// Sets the value of a global Lua variable.
		/// @param name The name of the global variable.
		/// @param value The value to set.
		public void SetValue<TVar>(StringView name, TVar value)
			where TVar : var
		{
			// COMPILER-BUG: Wrong method gets called! (with corrupted value)
			//StackHelper.Push<TVar>(mLua, value);
			StackHelper.Push(mLua, value);
			mLua.SetGlobal(name);
		}

		/// Sets the value of a global Lua variable by reference.
		/// @param name The name of the global variable.
		/// @param value A reference to the value to set.
		public void SetValue<TVar>(StringView name, ref TVar value)
			where TVar : var
		{
			StackHelper.Push(mLua, ref value);
			mLua.SetGlobal(name);
		}
		
		/// Sets the value of a global Lua variable to a string.
		/// @param name The name of the global variable.
		/// @param value The string value to set.
		[Inline]
		public void SetString(StringView name, String value)
			=> SetValue<String>(name, value);

		/// Sets the value of a global Lua variable to a number.
		/// @param name The name of the global variable.
		/// @param number The double value to set.
		[Inline]
		public void SetNumber(StringView name, double number)
			=> SetValue(name, number);
	}
}