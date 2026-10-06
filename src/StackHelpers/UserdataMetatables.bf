using System;
using KeraLua;
using LuaTinker.Handlers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	internal static class UserdataMetatables
	{
		private static uint8 sKindKey;
		private static uint8[3] sFamilyKeys;

		internal static void Mark(Lua lua, int32 index, LuaUserdataKind kind)
		{
			let tableIndex = lua.AbsIndex(index);
			lua.PushInteger((int)kind + 1);
			lua.RawSetByHashCode(tableIndex, &sKindKey);
		}

		internal static bool IsKind(Lua lua, int32 index, LuaUserdataKind kind)
		{
			if (lua.Type(index) != .UserData || !lua.GetMetaTable(index))
				return false;
			let type = lua.RawGetByHashCode(lua.AbsIndex(-1), &sKindKey);
			let matches = type == .Number && lua.ToInteger(-1) == (int)kind + 1;
			lua.Pop(2);
			return matches;
		}

		internal static void PushFamily(Lua lua, LuaUserdataKind kind)
		{
			let key = &sFamilyKeys[(int)kind];
			if (lua.RawGetByHashCode(LuaRegistry.Index, key) == .Table)
				return;
			lua.Pop(1);
			lua.CreateTable(0, 3);
			Mark(lua, -1, kind);
			lua.PushString("__gc");
			switch (kind)
			{
			case .Pointer: lua.PushCClosure(=> PointerDestructorHandler, 0);
			case .Variable: lua.PushCClosure(=> VariableDestructorHandler, 0);
			case .Indexer: lua.PushCClosure(=> IndexerDestructorHandler, 0);
			}
			lua.RawSet(-3);
			if (kind == .Pointer)
			{
				lua.PushString("__tostring");
				lua.PushCClosure(=> PointerToStringHandler, 0);
				lua.RawSet(-3);
			}
			lua.PushValue(-1);
			lua.RawSetByHashCode(LuaRegistry.Index, key);
		}
	}
}
