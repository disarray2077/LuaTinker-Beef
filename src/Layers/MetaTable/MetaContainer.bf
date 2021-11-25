using System;
using KeraLua;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;

namespace LuaTinker.Layers
{
	static
	{
		public static int32 MetaContainerGetLayer<T>(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);

			lua.GetMetaTable(1);
			lua.PushValue(2);
			lua.RawGet(-2);

			if (lua.IsNil(-1))
			{
				Runtime.NotImplemented();
				//PointerWrapperBase wrapper = User2Type<PointerWrapperBase>.GetType(lua, 1);
				//T container = (T)Internal.UnsafeCastToObject(wrapper.[Friend]mPtr);
				// TODO
				//PushContainerItemToLua(lua, container);
			}

			lua.Remove(-2);
			return 1;
		}
	}
}
