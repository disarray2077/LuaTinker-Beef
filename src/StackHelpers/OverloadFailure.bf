using System;
using KeraLua;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	public struct OverloadFailure
	{
		public int32 Arg;
		public int32 Stack;
		public StringView Expected;

		public void Record(int32 arg, int32 stack, StringView expected) mut
		{
			if (Arg <= arg)
			{
				Arg = arg;
				Stack = stack;
				Expected = expected;
			}
		}

		[NoReturn]
		public void Throw(Lua lua)
		{
			if (Arg > 0)
			{
				String actual = scope .();
				StackHelper.AppendArgumentTypeName(lua, Stack, actual);
				lua.TinkerState.SetLastError($"expected {Expected} at argument {Arg} but got '{actual}'");
			}
			else
				lua.TinkerState.SetLastError("no matching overload for the supplied arguments");
			StackHelper.ThrowError(lua, lua.TinkerState);
		}
	}
}
