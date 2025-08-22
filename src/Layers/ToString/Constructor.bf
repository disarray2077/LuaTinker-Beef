using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Layers
{
	static
	{
		public static int32 ConstructorToStringLayer<T>(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			StackHelper.Push(lua, scope $"<constructor for {typeof(T)}>");
			return 1;
		}
	}
}
