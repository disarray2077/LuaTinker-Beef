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

namespace LuaTinker
{
	public class LuaTinker
	{
		private Lua mLua;
		private LuaUserdataAllocator mUserdataAllocator;
		private LuaTinkerState mTinkerState;

		public this(Lua lua)
		{
			mLua = lua;
			mUserdataAllocator = .(lua);
			Init();

			mTinkerState = LuaTinkerState.GetOrAdd(mLua);
		}

		public ~this()
		{
			LuaTinkerState.Remove(mLua);
		}

		private void Init()
		{
			// Add GC Mate
			mLua.CreateTable(0, 1);
			mLua.PushString("__gc");
			mLua.PushCClosure(=> PointerDestroyerLayer, 0);
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

		public void AddMethod<F>(String name, F func) where F : var
		{
			mLua.PushLightUserData(func);
			mLua.PushCClosure(=> CallLayer<F>, 1);
			mLua.SetGlobal(name);
		}

		public void SetValue<TVar>(String name, TVar value)
			where TVar : var
		{
			// COMPILER-BUG: Wrong method gets called! (with corrupted value)
			//StackHelper.Push<TVar>(mLua, value);
			StackHelper.Push(mLua, value);
			mLua.SetGlobal(name);
		}
		
		[Comptime]
		private static void EmitAutoTinkClass<T>(String name = String.Empty)
		{
			let code = scope String();
			let type = typeof(T);
			
			for (let method in type.GetMethods(.Public | .Static))
			{
				if (method.IsConstructor || method.IsDestructor)
					continue;

				if (method.Name.StartsWith("get__") ||
					method.Name.StartsWith("set__"))
					continue;

				if (method.ReturnType == typeof(Windows.Handle) || method.ReturnType == typeof(Windows.IntBool))
					continue;

				String m = scope .();
				for (int i < method.ParamCount)
				{
					let paramType = method.GetParamType(i);
					m.Append(paramType.GetFullName(.. scope .()));

					if (i != method.ParamCount - 1)
						m.Append(", ");
				}

				let retType = method.ReturnType;

				code.AppendF($"AddMethod(\"{method.Name}\", (function {retType.GetFullName(.. scope .())}({m})) => {type.GetFullName(.. scope .())}.{method.Name});\n");
			}

			Compiler.MixinRoot(code);
		}

		public mixin AutoTinkClass<T>(var name = "")
		{
			// CRASH
			//AddMethod("CheckLiterals", (function void(System.String*)) => System.String.CheckLiterals);
			// TODO
			//EmitAutoTinkClass<T>(name);
		}

		public void AddClass<T>(String name = String.Empty)
		{
			var name;
			if (name.IsEmpty)
				name = typeof(T).GetName(.. scope:: String());

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
			mLua.PushCClosure(=> PointerDestroyerLayer, 0);
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

		public void AddClassCtor<T>()
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.CreateTable(0, 1);
				mLua.PushString("__call");
				mLua.PushCClosure(=> CreatorLayer<T>, 0);
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

		public void AddClassVar<T, TVar>(String name, int memberOffset)
		{
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name);
				new:mUserdataAllocator ClassFieldWrapper<TVar>(memberOffset);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}
		
		public void AddClassProperty<T, TVar, TGet, TSet>(String name, TGet getter, TSet setter)
			where TGet : class, delegate TVar(T)
			where TSet : class, delegate void(T, TVar)
		{
			Debug.Assert(getter != null || setter != null, "Properties must have at least a getter or a setter");
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name);
				new:mUserdataAllocator DelegatePropertyWrapper<T, TVar, TGet, TSet>(getter, setter);
				// register destructor
				{
				    mLua.CreateTable(0, 1);
				    mLua.PushString("__gc");
				    mLua.PushCClosure(=> VariableDestroyerLayer, 0);
				    mLua.RawSet(-3);
				    mLua.SetMetaTable(-2);
				}
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		public void AddClassProperty<T, TVar, TGet, TSet>(String name, TGet getter, TSet setter)
			where TGet : struct, function TVar(T this)
			where TSet : struct, function void(T this, TVar)
		{
			Debug.Assert(getter != null || setter != null, "Properties must have at least a getter or a setter");
			mLua.GetGlobal(mTinkerState.GetClassName<T>());
			if (mLua.IsTable(-1))
			{
				mLua.PushString(name);
				new:mUserdataAllocator FuncPropertyWrapper<T, TVar, TGet, TSet>(getter, setter);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		private Result<bool> FindNamespaceTable(String name)
		{
			bool parentExists = false;

			for (var ns in name.Split('.'))
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
			Debug.Assert(name.IsEmpty);
			return .Err;
		}

		public Result<void> AddNamespace(String name)
		{
			bool parentExists = false;
			bool first = true;
			bool globalSet = false;

			for (var ns in name.Split('.'))
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
							mLua.SetGlobal(name.Substring(0, name.IndexOf('.')));
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

		public void AddNamespaceEnum<E>(String namespaceName, String enumName = String.Empty)
			where E : enum
		{
			if (FindNamespaceTable(namespaceName))
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

		public void AddNamespaceMethod<F>(String namespaceName, String methodName, F func) where F : var
		{
			if (FindNamespaceTable(namespaceName))
			{
				mLua.PushString(methodName);
				mLua.PushLightUserData(func);
				mLua.PushCClosure(=> CallLayer<F>, 1);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		public void AddNamespaceVar<TVar>(String namespaceName, String varName, TVar value)
			where TVar : var
		{
			if (FindNamespaceTable(namespaceName))
			{
				mLua.PushString(varName);
				StackHelper.Push(mLua, value);
				mLua.RawSet(-3);
			}
			mLua.Pop(1);
		}

		[Comptime]
		private static int EmitCallPushes<Args>()
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

		public Result<RVal> Call<RVal>(StringView name)
			=> Call<RVal, void>(name, default);

		public Result<RVal> Call<RVal, Args>(StringView name, Args args)
			where RVal : var
			where Args : var
		{
			Debug.Assert(mLua.GetTop() == 0);
			const int32 results = typeof(RVal) == typeof(void) ? 0 : 1;
			
			mLua.GetGlobal(name);
			if (mLua.IsFunction(-1))
			{
				int argc = EmitCallPushes<Args>();
				mLua.Call((.)argc, results);
			}
			else
			{
				//mLua.PushString("attempt to call global '{}' (not a function)", name);
				//mLua.Error();
				return .Err; // TODO: More informative errors
			}

			if (results == 1)
			{
				defer mLua.Pop(1);
				return .Ok(StackHelper.Pop<RVal>(mLua, -1));
			}

			// TODO: Support for tuples

			// TODO: Remove the #unwarn when the compiler bug is solved.
#unwarn // COMPILER-BUG: The compiler thinks that this return is unreachable.
			return .Ok(default);
		}

		// TODO: Return reference
		public Result<T> GetValue<T>(StringView name) where T : var
		{
			Debug.Assert(mLua.GetTop() == 0);

			mLua.GetGlobal(name);
			if (mLua.IsNil(-1) || !StackHelper.CheckMetaTableValidity<T>(mLua, -1))
				return .Err; // TODO: More informative errors

			defer mLua.Pop(1);
			return .Ok(StackHelper.Pop<T>(mLua, -1));
		}

		[Error("Use the \"GetString\" method instead, or get a StringView if you doesn't need a String instance")]
		public Result<T> GetValue<T>(StringView name) where T : String
		{
			Runtime.NotImplemented();
		}

		public Result<void> GetString(StringView name, String outString)
		{
			Debug.Assert(mLua.GetTop() == 0);

			mLua.GetGlobal(name);
			if (mLua.IsNil(-1))
				return .Err; // TODO: More informative errors

			outString.Append(StackHelper.Pop<StringView>(mLua, -1));
			mLua.Pop(1);
			return .Ok;
		}
	}
}