using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.Handlers;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpers
{
	// Function pointers derive from System.Function (an int), so Beef selects
	// the INumeric Push overload. Send them to callable userdata, not Lua integers.
	extension NumericDispatch<T> where T : var, struct, INumeric where IsFunction<T>.Result : Yes
	{
		public new static void Push(Lua lua, T value)
		{
			Type2User.Create(lua, value);
			lua.CreateTable(0, 4);
			UserdataMetatables.Mark(lua, -1, .Pointer);
			lua.PushString("__gc");
			lua.PushCClosure(=> PointerDestructorHandler, 0);
			lua.RawSet(-3);
			lua.PushString("__tostring");
			lua.PushCClosure(=> PointerToStringHandler, 0);
			lua.RawSet(-3);
			lua.PushString("__call");
			lua.PushCClosure(=> FunctionPointerCallHandler<T>, 0);
			lua.RawSet(-3);
			lua.SetMetaTable(-2);
		}

		public new static T Pop(Lua lua, int32 index)
		{
			if (lua.IsNil(index))
				return default;
			if (let wrapper = User2Type.TryGetTypePtr<ValueTypeWrapper<T>>(lua, index))
				return *wrapper.ValuePointer;
			lua.TinkerState.SetLastError($"can't convert argument {index} to '{typeof(T)}'");
			StackHelper.TryThrowError(lua, lua.TinkerState);
			return default;
		}
	}
}
