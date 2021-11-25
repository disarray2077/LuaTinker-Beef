using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

namespace LuaTinker.Layers
{
	static
	{
		private static void ParentMetaLayer(Lua lua)
		{
			lua.PushString("__parent");
			lua.RawGet(-2);
			if(lua.IsTable(-1))
			{
			    lua.PushValue(2);
			    lua.RawGet(-2);
			    if(!lua.IsNil(-1))
			    {
			        lua.Remove(-2);
			    }
			    else
			    {
			        lua.Remove(-1);
			        ParentMetaLayer(lua);
			    }
				lua.Remove(-2);
			}
			else if (!lua.IsNil(-1))
			{
				lua.PushString("find '__parent' class variable. (nonsupport registering such class variable.)");
				lua.Error();
			}
		}

		public static int32 MetaGetLayer(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);

			lua.GetMetaTable(1);
			lua.PushValue(2);
			lua.RawGet(-2);

			if (lua.IsUserData(-1))
			{
				User2Type.GetTypePtr<VariableWrapperBase>(lua, -1).Get(lua);
				lua.Remove(-2);
			}
			else if (lua.IsNil(-1))
			{
				lua.Remove(-1);
				ParentMetaLayer(lua);
				if (lua.IsUserData(-1))
				{
					User2Type.GetTypePtr<VariableWrapperBase>(lua, -1).Get(lua);
					lua.Remove(-2);
				}
				else if (lua.IsNil(-1))
				{
				    lua.PushString("can't find '{}' class variable. (forgot registering class variable ?)", lua.ToStringView(2));
				 	lua.Error();
				}
			}

			lua.Remove(-2);
		    return 1;
		}

		public static int32 MetaSetLayer(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			
			lua.GetMetaTable(1);
			lua.PushValue(2);
			lua.RawGet(-2);

			if(lua.IsUserData(-1))
			{
				User2Type.GetTypePtr<VariableWrapperBase>(lua, -1).Set(lua);
			}
			else if(lua.IsNil(-1))
			{
				lua.Remove(-1);
				ParentMetaLayer(lua);
			    if (lua.IsUserData(-1))
				{
					User2Type.GetTypePtr<VariableWrapperBase>(lua, -1).Set(lua);
				}
				else if (lua.IsNil(-1))
				{
				    lua.PushString("can't find '{}' class variable. (forgot registering class variable ?)", lua.ToStringView(2));
				 	lua.Error();
				}
			}

			lua.SetTop(3);
			return 0;
		}
	}
}
