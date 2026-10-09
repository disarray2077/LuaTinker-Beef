using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 CStringFromPointerHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			if (lua.GetTop() == 1 && (lua.IsNil(1) || StackHelper.IsNullPointerArgument(lua, 1, typeof(char8*))))
			{
				lua.PushNil();
				return 1;
			}
			let pointer = lua.GetTop() == 1 ? User2Type.TryGetTypePtr<PointerWrapper<char8>>(lua, 1) : null;
			if (pointer == null)
			{
				lua.TinkerState.SetLastError("string.from_cstr expects one char8* pointer");
				StackHelper.TryThrowError(lua, lua.TinkerState);
				return 0;
			}
			if (pointer.Ptr == null)
				lua.PushNil();
			else
				lua.PushString(StringView(pointer.Ptr));
			return 1;
		}
	}
}
