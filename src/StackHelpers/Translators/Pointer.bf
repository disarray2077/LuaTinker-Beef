using System;
using KeraLua;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct*
			=> (T)PopPointer(lua, index, typeof(T));

		private static void* PopPointer(Lua lua, int32 index, Type expectedType)
		{
			if (lua.IsNil(index))
				return null;
			if (expectedType == typeof(char8*) && lua.Type(index) == .String)
				return lua.ToStringView(index, false).Ptr;

			let stackObject = User2Type.GetObject(lua, index);
			if (let pointerWrapper = stackObject as PointerWrapperBase)
				if (IsPointerWrapperArgument(pointerWrapper, expectedType))
					return pointerWrapper.Ptr;

			let tinkerState = lua.TinkerState;
			tinkerState.SetLastError($"can't convert argument {index} to 'ptr {GetBestLuaClassName(tinkerState, expectedType)}'");
			TryThrowError(lua, tinkerState);
			return default;
		}
	}
}
