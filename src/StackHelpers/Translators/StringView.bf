using System;
using System.Diagnostics;
using KeraLua;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		[Inline]
		public static void Push(Lua lua, StringView val)
		{
			lua.PushString(val);
		}

		[Inline]
		public static void Push(Lua lua, StringView? val)
		{
			if (!val.HasValue)
				lua.PushNil();
			else
				lua.PushString(val.Value);
		}

		public static T Pop<T>(Lua lua, int32 index)
			where T : struct, StringView where StringView : T
		{
			if (!lua.IsStringOrNumber(index))
			{
				let tinkerState = lua.TinkerState;
				tinkerState.SetLastError($"expected 'String' but got '{lua.TypeName(index)}'");
				TryThrowError(lua, tinkerState);
				return default;
			}
			return lua.ToStringView(index);
		}
	}
}
