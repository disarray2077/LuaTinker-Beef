using System;
using System.Diagnostics;
using KeraLua;

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
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"expected 'String' but got '{lua.TypeName(index)}'");
				lua.Error();
			}
			return lua.ToStringView(index);
		}
	}
}
