using System;
using KeraLua;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		internal static void PushNullPointerArgumentHint(Lua lua, Type pointerType = null)
		{
			RegisterArgumentHintMetatable(lua);
			lua.CreateTable(pointerType == null ? 1 : 2, 0);
			lua.PushInteger(pointerType == null ? 5 : 4);
			lua.RawSetInteger(-2, 1);
			if (pointerType != null)
			{
				lua.PushInteger(pointerType.GetTypeId());
				lua.RawSetInteger(-2, 2);
			}
			SetArgumentHintMetatable(lua);
		}

		public static bool IsNullPointerArgument(Lua lua, int32 index, Type expectedPointerType)
		{
			if (!expectedPointerType.IsPointer || !IsArgumentHint(lua, index))
				return false;
			let hintIndex = lua.AbsIndex(index);
			lua.RawGetInteger(hintIndex, 1);
			let tag = lua.ToInteger(-1);
			lua.Pop(1);
			if (tag == 5)
				return true;
			if (tag != 4)
				return false;
			// Typed hints carry the pointer type supplied by their construction path.
			lua.RawGetInteger(hintIndex, 2);
			let matches = lua.ToInteger(-1) == expectedPointerType.GetTypeId();
			lua.Pop(1);
			return matches;
		}

		// Dispatch calls this only when distinct pointer types compete at this argument.
		public static void EnsureUnambiguousNullPointer(Lua lua, int32 index, int32 argument)
		{
			if (!IsArgumentHint(lua, index))
				return;
			lua.RawGetInteger(index, 1);
			let isUniversalNull = lua.ToInteger(-1) == 5;
			lua.Pop(1);
			if (!isUniversalNull)
				return;
			lua.TinkerState.SetLastError($"ambiguous null pointer overload at argument {argument}");
			ThrowError(lua, lua.TinkerState);
		}
	}
}
