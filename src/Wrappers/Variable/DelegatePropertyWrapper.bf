using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.StackHelpers;

namespace LuaTinker.Wrappers
{
	public sealed class DelegatePropertyWrapper<T, TVar, TGet, TSet> : VariableWrapperBase
		where T : var
		where TVar : var
		where TGet : class, delegate TVar(T)
		where TSet : class, delegate void(T, TVar)
	{
		TGet mGetFunc;
		TSet mSetFunc;

		public this(TGet getFunc, TSet setFunc)
		{
			mGetFunc = getFunc;
			mSetFunc = setFunc;
		}

		public ~this()
		{
			delete mGetFunc;
			delete mSetFunc;
		}

		public override void Get(Lua lua)
		{
			if (mGetFunc == null)
			{
				lua.PushString("this property is write-only");
				lua.Error();
			}

			if (!lua.IsUserData(1))
			{
				lua.PushString("no class at first argument. (forgot ':' expression ?)");
				lua.Error();
			}

			StackHelper.Push(lua, mGetFunc(StackHelper.Pop!<T>(lua, 1)));
		}

		public override void Set(Lua lua)
		{
			if (mSetFunc == null)
			{
				lua.PushString("this property is read-only");
				lua.Error();
			}

			if (!lua.IsUserData(1))
			{
				lua.PushString("no class at first argument. (forgot ':' expression ?)");
				lua.Error();
			}

			mSetFunc(StackHelper.Pop!<T>(lua, 1), StackHelper.Pop!<TVar>(lua, 3));
		}
	}
}
