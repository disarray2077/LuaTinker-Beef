using System;
using KeraLua;
using LuaTinker.StackHelpers;

using internal KeraLua;

namespace LuaTinker.Wrappers
{
	public sealed class FuncPropertyWrapper<T, TVar, TGet, TSet> : VariableWrapperBase
		where T : var
		where TVar : var
		where TGet : var, struct
		where TSet : var, struct
	{
		TGet mGetFunc;
		TSet mSetFunc;

		public this(TGet getFunc, TSet setFunc)
		{
			mGetFunc = getFunc;
			mSetFunc = setFunc;
		}

		public override void Get(Lua lua)
		{
#unwarn
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

			[Comptime]
			void EmitGetter()
			{
				if (typeof(T).IsGenericParam || typeof(TGet).IsGenericParam)
					return;
				Compiler.MixinRoot("StackHelper.Push(lua, mGetFunc(StackHelper.Pop!<T>(lua, 1)));");
			}
			EmitGetter();
		}

		public override void Set(Lua lua)
		{
#unwarn
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
				let isInstance = typeof(TSet).GetMethod("Invoke").Get().GetParamName(0) == "this";
				let receiver = typeof(T).IsStruct
					? scope $"{(isInstance ? "" : "ref ")}StackHelper.PopRef<T>(lua, 1)"
					: "StackHelper.Pop!<T>(lua, 1)";
				Compiler.MixinRoot(scope $"mSetFunc({receiver}, StackHelper.Pop!<TVar>(lua, 3));");
			}
			EmitSetter();
		}
	}
}
