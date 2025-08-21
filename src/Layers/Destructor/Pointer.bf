using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Layers
{
	static
	{
		public static int32 PointerDestructorLayer(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			var ud = lua.ToUserData(1);

			var obj = (PointerWrapperBase)Internal.UnsafeCastToObject(ud);
			lua.TinkerState?.DeregisterAliveObject(obj);
			delete:null obj;

			return 0;
		}
	}
}
