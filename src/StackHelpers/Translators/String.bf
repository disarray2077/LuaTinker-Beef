using System;
using System.Diagnostics;
using KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		[Inline]
		public static void Push(Lua lua, String val)
		{
			lua.PushString(val);
		}

		[Inline]
		public static StringView? Pop<T>(Lua lua, int32 index)
			where T : class, String where String : T
		{
			if (lua.IsNil(index))
			{
				return null;
			}
			else if (!lua.IsStringOrNumber(index))
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"expected 'String' but got '{lua.TypeName(index)}'");
				lua.Error();
			}
			return lua.ToStringView(index);
		}
	}
}
