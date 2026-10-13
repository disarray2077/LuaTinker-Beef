using System;
using KeraLua;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 ConstructorToStringHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			lua.PushValue(Lua.UpValueIndex(1));
			return 1;
		}
	}
}
