using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

namespace LuaTinker.Layers
{
	static
	{
		public static int32 VariableDestroyerLayer(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);

			var ud = lua.ToUserData(1);
			var obj = (VariableWrapperBase)Internal.UnsafeCastToObject(ud);
			delete:null obj;
			return 0;
		}
	}
}
