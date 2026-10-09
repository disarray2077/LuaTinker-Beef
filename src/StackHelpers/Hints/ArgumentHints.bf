using System;
using KeraLua;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		private static int32 sArgumentHintMetatableKey;

		public static void RegisterArgumentHintMetatable(Lua lua)
		{
			let alreadyRegistered = lua.RawGetByHashCode(LuaRegistry.Index, &sArgumentHintMetatableKey) == .Table;
			lua.Pop(1);
			if (alreadyRegistered)
				return;
			lua.CreateTable(0, 1);
			lua.PushString("__metatable");
			lua.PushBoolean(false);
			lua.RawSet(-3);
			lua.RawSetByHashCode(LuaRegistry.Index, &sArgumentHintMetatableKey);
		}

		internal static void SetArgumentHintMetatable(Lua lua, Type numericType = null)
		{
			lua.RawGetByHashCode(LuaRegistry.Index, &sArgumentHintMetatableKey);
			if (numericType != null)
			{
				let typeId = numericType.GetTypeId();
				let hasName = lua.RawGetInteger(-1, typeId) == .String;
				lua.Pop(1);
				if (!hasName)
				{
					lua.PushString(numericType.GetName(.. scope .()));
					lua.RawSetInteger(-2, typeId);
				}
			}
			lua.SetMetaTable(-2);
		}

		[Inline]
		public static bool IsArgumentHint(Lua lua, int32 index)
			=> IsArgumentHint(lua, index, lua.Type(index));

		public static bool IsArgumentHint(Lua lua, int32 index, LuaType type)
		{
			if (type != .Table || !lua.GetMetaTable(index))
				return false;

			lua.RawGetByHashCode(LuaRegistry.Index, &sArgumentHintMetatableKey);
			let isHint = lua.RawEqual(-1, -2);
			lua.Pop(2);
			return isHint;
		}

		public static void AppendArgumentTypeName(Lua lua, int32 index, String name)
		{
			if (!IsArgumentHint(lua, index))
			{
				name.Append(lua.TypeName(index));
				return;
			}
			let hintIndex = lua.AbsIndex(index);
			lua.RawGetInteger(hintIndex, 1);
			let tag = lua.ToInteger(-1);
			lua.Pop(1);
			if (tag == 4 || tag == 5)
			{
				name.Append(tag == 4 ? "nullptr.int32 hint" : "nullptr.void hint");
				return;
			}
			lua.RawGetInteger(hintIndex, 2);
			let typeId = lua.ToInteger(-1);
			lua.Pop(1);
			lua.GetMetaTable(hintIndex);
			if (lua.RawGetInteger(-1, typeId) == .String)
				lua.ToString(-1, false, name);
			lua.Pop(2);
			name.Append(" cast");
		}

		public static bool EnsureNotArgumentHint(Lua lua, int32 index, Type expectedType = null)
		{
			if (!IsArgumentHint(lua, index))
				return true;
			{
				String hintName = scope .();
				AppendArgumentTypeName(lua, index, hintName);
				if (expectedType != null)
					lua.TinkerState.SetLastError($"expected '{expectedType}' at argument {index} but got '{hintName}'");
				else
					lua.TinkerState.SetLastError($"'{hintName}' cannot bind to an ordinary value parameter");
			}
			TryThrowError(lua, lua.TinkerState);
			return false;
		}
	}
}
