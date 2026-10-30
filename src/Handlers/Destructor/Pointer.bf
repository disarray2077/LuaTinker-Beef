using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 PointerDestructorHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			var obj = User2Type.TryGetTypePtr<PointerWrapperBase>(lua, 1);
			if (obj == null)
				return 0;
			lua.TinkerState?.DeregisterAliveObject(obj);
			delete:null obj;

			return 0;
		}
	}
}
