using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		[Inline]
		public static void Push(Lua lua, String val)
		{
			lua.PushString(val);
		}

		public static StringView? Pop<T>(Lua lua, int32 index)
			where T : class, String where String : T
		{
			if (lua.IsNil(index))
			{
				return null;
			}
			else if (!lua.IsStringOrNumber(index))
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"expected 'String' but got '{lua.TypeName(index)}'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			return lua.ToStringView(index);
		}
	}
}
