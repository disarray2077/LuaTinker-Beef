using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.StackHelpers;

using internal KeraLua;

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
				let tinkerState = lua.TinkerState;
				tinkerState.SetLastError("this property is write-only");
				StackHelper.ThrowError(lua, tinkerState);
			}

			if (!lua.IsUserData(1))
			{
				let tinkerState = lua.TinkerState;
				tinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
				StackHelper.ThrowError(lua, tinkerState);
			}

			StackHelper.Push(lua, mGetFunc(StackHelper.Pop!<T>(lua, 1)));
		}

		public override void Set(Lua lua)
		{
			if (mSetFunc == null)
			{
				let tinkerState = lua.TinkerState;
				tinkerState.SetLastError("this property is read-only");
				StackHelper.ThrowError(lua, tinkerState);
			}

			if (!lua.IsUserData(1))
			{
				let tinkerState = lua.TinkerState;
				tinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
				StackHelper.ThrowError(lua, tinkerState);
			}

			mSetFunc(StackHelper.Pop!<T>(lua, 1), StackHelper.Pop!<TVar>(lua, 3));
		}

		public override void OnRemoveFromLua(LuaTinkerState tinkerState)
		{
			tinkerState.DeregisterAliveObject(mGetFunc);
			tinkerState.DeregisterAliveObject(mSetFunc);
		}
	}
}
