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

		// This exists only to make GC happy.
		internal static List<Object> sAliveObjects = new .() ~ delete _;

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
		}

		[NoShow]
#if !DEBUG
		[SkipCall]
#endif
		public void DebugEnumStack()
		{
			Debug.WriteLine(StackHelper.EnumStack(mLua, .. scope .()));
		}

		private void Init()
		{
			// Add GC Mate
			mLua.CreateTable(0, 1);
			mLua.PushString("__gc");
			mLua.PushCClosure(=> PointerDestructorLayer, 0);
			mLua.RawSet(-3);
			mLua.SetGlobal("__onlygc_meta");
		}

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

		public void AddMethod<F>(String name, F func) where F : var, struct
		{
			mLua.PushLightUserData(func);
			mLua.PushCClosure(=> CallLayer<F>, 1);
			mLua.SetGlobal(name);
		}

		public void AddMethod<F>(String name, F func) where F : var, class
		{
			sAliveObjects.Add(func);

			new:mUserdataAllocator ClassInstanceWrapper<F>(func, true);
			// register destructor
			{
			    mLua.CreateTable(0, 1);
			    mLua.PushString("__gc");
			    mLua.PushCClosure(=> PointerDestructorLayer, 0);
			    mLua.RawSet(-3);
			    mLua.SetMetaTable(-2);
			}
			mLua.PushCClosure(=> DelegateCallLayer<F>, 1);
			mLua.SetGlobal(name);
		}
		
		[Inline]
		public void AutoTinkClass<T>()
			=> AutoTinkClass<T, const "">();

		public void AutoTinkClass<T, Name>()
			where Name : const String
		{
			[Comptime]
			static void EmitAutoTinkClass<T, Name>()
				where Name : const String
			{
				let code = scope String();
				let type = typeof(T);

				if (type.IsGenericParam)
					return;

				bool isConstructorEmitted = false;

				if (!type.IsStatic)
				{
					code.AppendF($"AddClass<T>(\"{Name}\");\n");
					//code.Append("AddClassCtor<T>();\n");
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
						if (method.IsStatic)
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

#unwarn
			EmitAutoTinkClass<T, const Name>();
		}

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

			mLua.CreateTable(0, 4);

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

			mLua.SetGlobal(name);
		}

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

		[Inline]
		public void AddClassCtor<T>()
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.CreateTable(0, 1);
				mLua.PushString("__call");
				mLua.PushCClosure(=> DynamicCreatorLayer<T>, 0);
				mLua.RawSet(-3);
				mLua.SetMetaTable(-2);
			}
			mLua.Pop(1);
		}

		public void AddClassCtor<T, Args>()
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.CreateTable(0, 1);
				mLua.PushString("__call");
				mLua.PushCClosure(=> CreatorLayer<T, Args>, 0);
				mLua.RawSet(-3);
				mLua.SetMetaTable(-2);
			}
			mLua.Pop(1);
		}

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
				sAliveObjects.Add(indexer);
				aggregator.AddIndexer(typeof(TKey), indexer);
			}
			else
			{
				var newAggregator = new:mUserdataAllocator IndexerAggregatorWrapper();

				let existingIndexerClone = existingIndexer.CreateNew();
				let newIndexer = new IndexerWrapper<T, TKey>();
				sAliveObjects.Add(existingIndexerClone);
				sAliveObjects.Add(newIndexer);

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

		public void AddClassMethod<T, F>(String name, F func) where F : var
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
		
		public void AddClassProperty<T, TVar, TGet, TSet>(String name, TGet getter, TSet setter)
			where TGet : class, delegate TVar(T)
			where TSet : class, delegate void(T, TVar)
		{
			Debug.Assert(getter != null || setter != null, "Properties must have at least a getter or a setter");
			sAliveObjects.Add(getter);
			sAliveObjects.Add(setter);

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

		public Result<void> AddNamespace(String path)
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
						return .Ok;
					}

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

			return .Ok;
		}

		public void NewTable(String path)
			=> AddNamespace(path);

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

		public void AddNamespaceMethod<F>(String namespacePath, String methodName, F func) where F : var
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

		public void AddNamespaceMethod<F>(String namespacePath, String methodName, F func) where F : var, class
		{
			sAliveObjects.Add(func);

			if (FindNamespaceTable(namespacePath))
			{
				mLua.PushString(methodName);
				new:mUserdataAllocator ClassInstanceWrapper<F>(func, true);
				// register destructor
				{
				    mLua.CreateTable(0, 1);
				    mLua.PushString("__gc");
				    mLua.PushCClosure(=> PointerDestructorLayer, 0);
				    mLua.RawSet(-3);
				    mLua.SetMetaTable(-2);
				}
				mLua.PushCClosure(=> DelegateCallLayer<F>, 1);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

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

		private mixin TryTinker(var val)
		{
			if (mTinkerState.HasError)
				return .Err(mTinkerState.GetLastError());
			val
		}
		
		[Inline]
		public Result<void, StringView> Call(StringView name)
			=> Call<void, void>(name, default);
		
		[Inline]
		public Result<RVal, StringView> Call<RVal>(StringView name)
			=> Call<RVal, void>(name, default);

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

		// TODO: Return reference
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

		[Inline]
		public Result<double, StringView> GetNumber(StringView name)
			=> GetValue<double>(name);

		public void SetValue<TVar>(StringView name, TVar value)
			where TVar : var
		{
			// COMPILER-BUG: Wrong method gets called! (with corrupted value)
			//StackHelper.Push<TVar>(mLua, value);
			StackHelper.Push(mLua, value);
			mLua.SetGlobal(name);
		}

		public void SetValue<TVar>(StringView name, ref TVar value)
			where TVar : var
		{
			StackHelper.Push(mLua, ref value);
			mLua.SetGlobal(name);
		}
		
		[Inline]
		public void SetString(StringView name, String value)
			=> SetValue<String>(name, value);

		[Inline]
		public void SetNumber(StringView name, double number)
			=> SetValue(name, number);
	}
}