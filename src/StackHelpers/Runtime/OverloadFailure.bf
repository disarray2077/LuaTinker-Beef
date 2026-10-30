using System;
using KeraLua;

using internal KeraLua;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpers
{
	public struct OverloadFailure<Capacity> where Capacity : const int
	{
		public int32 Arg;
		public int32 Stack;
		private Type[Capacity] mExpected;
		private int mExpectedCount;

		public void Record(int32 arg, int32 stack, params Span<Type> expected) mut
		{
			if (Arg <= arg)
			{
				Arg = arg;
				Stack = stack;
				expected.CopyTo(mExpected);
				mExpectedCount = expected.Length;
			}
		}

		public void Record(int32 arg, int32 stack, Type expected) mut
		{
			if (Arg <= arg)
			{
				Arg = arg;
				Stack = stack;
				mExpected[0] = expected;
				mExpectedCount = 1;
			}
		}

		[NoReturn]
		public void Throw(Lua lua)
		{
			Span<Type> expected = mExpected;
			if (Arg > 0)
			{
				String actual = scope .();
				StackHelper.AppendArgumentTypeName(lua, Stack, actual);
				let state = lua.TinkerState;
				state.SetLastError("expected ");
				let message = state.GetLastError();
				for (let type in expected.Slice(0, mExpectedCount))
				{
					if (@type.Index > 0)
						message.Append(" or ");
					message.Append('\'');
					message.Append(StackHelper.GetBestLuaClassName(state, type));
					message.Append('\'');
				}
				message.AppendF($" at argument {Arg} but got '{actual}'");
			}
			else
				lua.TinkerState.SetLastError("no matching overload for the supplied arguments");
			StackHelper.ThrowError(lua, lua.TinkerState);
		}
	}
}
