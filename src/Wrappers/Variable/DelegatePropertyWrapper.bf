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
		where TSet : Delegate
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

			[Comptime]
			void EmitSetter()
			{
				if (typeof(T).IsGenericParam || typeof(TSet).IsGenericParam)
					return;
				let receiver = typeof(T).IsStruct
					? "ref StackHelper.PopRef<T>(lua, 1)"
					: "StackHelper.Pop!<T>(lua, 1)";
				Compiler.MixinRoot(scope $"mSetFunc({receiver}, StackHelper.Pop!<TVar>(lua, 3));");
			}
			EmitSetter();
		}

		public override void OnRemovedFromLua(LuaTinkerState tinkerState)
		{
			tinkerState.DeregisterAliveObject(mGetFunc);
			tinkerState.DeregisterAliveObject(mSetFunc);
		}
	}
}
