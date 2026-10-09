using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;

namespace LuaTinker.Wrappers
{
	public sealed class VariableWrapper<T> : VariableWrapperBase
		where T : var
	{
		private T* mPtr;

		public this(T* ptr)
		{
			mPtr = ptr;
		}

		public override void Get(Lua lua)
		{
			if (!typeof(T).IsPrimitive && typeof(T).IsStruct && !IsFunctionType(typeof(T)))
				StackHelper.Push(lua, ref *mPtr);
			else
				StackHelper.Push(lua, *mPtr);
		}

		public override void Set(Lua lua)
		{
			*mPtr = StackHelper.Pop!<T>(lua, 2);
		}
	}
}
