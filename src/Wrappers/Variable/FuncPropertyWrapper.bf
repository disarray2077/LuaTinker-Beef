using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.StackHelpers;

using internal KeraLua;

namespace LuaTinker.Wrappers
{
	public sealed class FuncPropertyWrapper<T, TVar> : VariableWrapperBase
		where T : var
		where TVar : var
	{
		function TVar(T this) mGetFunc;
		function void(T this, TVar) mSetFunc;
		function TVar(T) mStaticGetFunc;
		function void(T, TVar) mStaticSetFunc;

		public this(function TVar(T this) getFunc, function void(T this, TVar) setFunc)
		{
			mGetFunc = getFunc;
			mSetFunc = setFunc;
		}

		public this(function TVar(T) getFunc, function void(T, TVar) setFunc)
		{
			// Previously, we reused the instance function pointer for static methods by casting it
			// to the corresponding instance signature. However, static and instance methods can use
			// different calling conventions for struct return values, making the cast brittle.
			mStaticGetFunc = getFunc;
			mStaticSetFunc = setFunc;
		}

		public override void Get(Lua lua)
		{
			if (mGetFunc == null && mStaticGetFunc == null)
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

			if (mStaticGetFunc != null)
				StackHelper.Push(lua, mStaticGetFunc(StackHelper.Pop!<T>(lua, 1)));
			else
				StackHelper.Push(lua, mGetFunc(StackHelper.Pop!<T>(lua, 1)));
		}

		public override void Set(Lua lua)
		{
			if (mSetFunc == null && mStaticSetFunc == null)
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

			if (mStaticSetFunc != null)
				mStaticSetFunc(StackHelper.Pop!<T>(lua, 1), StackHelper.Pop!<TVar>(lua, 3));
			else
				mSetFunc(StackHelper.Pop!<T>(lua, 1), StackHelper.Pop!<TVar>(lua, 3));
		}
	}
}
