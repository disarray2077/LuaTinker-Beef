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
		private static uint8 sFunctionPointerMetatableKey;

		[Inline]
		public new static void Push(Lua lua, T value)
		{
			Type2User.Create(lua, value);
			StackHelper.SetFunctionPointer(lua, &sFunctionPointerMetatableKey, => FunctionPointerCallHandler<T>);
		}

		public new static T Pop(Lua lua, int32 index)
		{
			if (lua.IsNil(index))
				return default;
			if (let wrapper = User2Type.TryGetTypePtr<ValueTypeWrapper<T>>(lua, index))
				return *wrapper.ValuePointer;
			lua.TinkerState.SetLastError($"can't convert argument {index} to '{StackHelper.GetBestLuaClassName<T>(lua.TinkerState)}'");
			StackHelper.TryThrowError(lua, lua.TinkerState);
			return default;
		}
	}
}
