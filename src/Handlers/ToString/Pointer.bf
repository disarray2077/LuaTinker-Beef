using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 PointerToStringHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			var ud = lua.ToUserData(1);

			var obj = (PointerWrapperBase)Internal.UnsafeCastToObject(ud);
			StackHelper.Push(lua, obj.ToString(.. scope .()));

			return 1;
		}
	}
}
