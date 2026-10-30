using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		private static LuaType GetParentIndex(Lua lua, String keyName = null)
		{
			lua.PushString("__parent");
			let parentType = lua.RawGet(-2);
			if (parentType == .Table)
			{
				if (keyName == null)
					lua.PushValue(2);
				else
					lua.PushString(keyName);
				var valueType = lua.RawGet(-2);
				if (valueType != .Nil)
				{
					lua.Remove(-2);
				}
				else
				{
					lua.Remove(-1);
					valueType = GetParentIndex(lua, keyName);
				}
				lua.Remove(-2);
				return valueType;
			}
			else if (parentType != .Nil)
			{
				let tinkerState = lua.TinkerState;
				tinkerState.SetLastError("find '__parent' class variable. (nonsupport registering such class variable.)");
				StackHelper.ThrowError(lua, tinkerState);
			}
			return parentType;
		}

		[NoReturn]
		private static void ThrowMissingMemberError(Lua lua)
		{
			lua.TinkerState.SetLastError("can't find '{}' class variable. (forgot registering class variable ?)", lua.ToStringView(2));
			StackHelper.ThrowError(lua, lua.TinkerState);
		}

		[NoReturn]
		private static void ThrowIndexError(Lua lua, StringView operation, StringView reason)
		{
			let key = lua.IsStringOrNumber(2) ? lua.ToStringView(2) : lua.TypeName(2);
			lua.TinkerState.SetLastError($"can't {operation} '{key}' class variable. ({reason}.)");
			StackHelper.ThrowError(lua, lua.TinkerState);
		}

		private static T RequireIndexWrapper<T>(Lua lua, T wrapper, StringView operation, StringView reason) where T : class
		{
			if (wrapper == null)
				ThrowIndexError(lua, operation, reason);
			return wrapper;
		}

		public static int32 IndexGetHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			RequireIndexWrapper(lua, User2Type.TryGetTypePtr<PointerWrapperBase>(lua, 1), "read", "expected a LuaTinker object");

			lua.GetMetaTable(1);
			lua.PushValue(2);
			var valueType = lua.RawGet(-2);

			if (valueType == .UserData)
			{
				RequireIndexWrapper(lua, User2Type.TryGetTypePtr<VariableWrapperBase>(lua, -1), "read", "invalid class variable binding").Get(lua);
				lua.Remove(-2);
			}
			else if (valueType == .Nil)
			{
				lua.Remove(-1);
				valueType = GetParentIndex(lua);
				if (valueType == .UserData)
				{
					RequireIndexWrapper(lua, User2Type.TryGetTypePtr<VariableWrapperBase>(lua, -1), "read", "invalid class variable binding").Get(lua);
					lua.Remove(-2);
				}
				else if (valueType == .Nil)
				{
					lua.Remove(-1);
					lua.PushString("__bfindexer");
					valueType = lua.RawGet(-2);
					if (valueType == .Nil)
					{
						lua.Pop(1);
						valueType = GetParentIndex(lua, "__bfindexer");
					}
					if (valueType == .UserData)
					{
						if (!RequireIndexWrapper(lua, User2Type.TryGetTypePtr<IndexerWrapperBase>(lua, -1), "read", "invalid class indexer binding").Get(lua))
						{
							ThrowMissingMemberError(lua);
						}
						lua.Remove(-2);
					}
					else
					{
						ThrowMissingMemberError(lua);
					}
				}
			}
			
			lua.Remove(-2);
		    return 1;
		}

		public static int32 IndexSetHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			RequireIndexWrapper(lua, User2Type.TryGetTypePtr<PointerWrapperBase>(lua, 1), "write", "expected a LuaTinker object");
			
			lua.GetMetaTable(1);
			lua.PushValue(2);
			var valueType = lua.RawGet(-2);

			if (valueType == .UserData)
			{
				RequireIndexWrapper(lua, User2Type.TryGetTypePtr<VariableWrapperBase>(lua, -1), "write", "invalid class variable binding").Set(lua);
			}
			else if (valueType == .Nil)
			{
				lua.Remove(-1);
				valueType = GetParentIndex(lua);
			    if (valueType == .UserData)
				{
					RequireIndexWrapper(lua, User2Type.TryGetTypePtr<VariableWrapperBase>(lua, -1), "write", "invalid class variable binding").Set(lua);
				}
				else if (valueType == .Nil)
				{
					lua.Remove(-1);
					lua.PushString("__bfindexer");
					valueType = lua.RawGet(-2);
					if (valueType == .Nil)
					{
						lua.Pop(1);
						valueType = GetParentIndex(lua, "__bfindexer");
					}
					if (valueType == .UserData)
					{
						RequireIndexWrapper(lua, User2Type.TryGetTypePtr<IndexerWrapperBase>(lua, -1), "write", "invalid class indexer binding").Set(lua);
					}
					else
					{
						ThrowMissingMemberError(lua);
					}
				}
			}

			lua.SetTop(3);
			return 0;
		}
	}
}
