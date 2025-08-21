using System;
using KeraLua;
using LuaTinker.StackHelpers;

using internal KeraLua;

namespace LuaTinker.Wrappers
{
	public sealed class ClassFieldWrapper<T> : VariableWrapperBase
		where T : var
	{
		private int mMemberOffset;

		public this(int val)
		{
			mMemberOffset = val;
		}

		[Inline]
		private ref T GetValueRef(int instance)
		{
			return ref *(T*)((void*)(instance + mMemberOffset));
		}

		public override void Get(Lua lua)
		{
			if (!lua.IsUserData(1))
			{
				lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}

			let wrapper = User2Type.GetTypePtr<PointerWrapperBase>(lua, 1);
			if (!typeof(T).IsPrimitive && typeof(T).IsStruct)
				StackHelper.Push(lua, ref GetValueRef((.)wrapper.Ptr));
			else
				StackHelper.Push(lua, GetValueRef((.)wrapper.Ptr));
		}

		public override void Set(Lua lua)
		{
			if (!lua.IsUserData(1))
			{
				lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}

			let wrapper = User2Type.GetTypePtr<PointerWrapperBase>(lua, 1);
			GetValueRef((.)wrapper.Ptr) = StackHelper.Pop!<T>(lua, 3);
		}
	}
}
