using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 IndexerDestructorHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			var obj = User2Type.TryGetTypePtr<IndexerWrapperBase>(lua, 1);
			if (obj == null)
				return 0;

			lua.TinkerState?.DeregisterAliveObject(obj);
			delete:null obj;

			return 0;
		}
	}
}
