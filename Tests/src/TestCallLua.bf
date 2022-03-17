using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestCallLua
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			if (lua.DoString(
				@"""
				var = 0

				function TestRet1()
					var = 20
					return 1
				end

				function TestRetPlus(a, b)
					return var + a + b
				end

				function TestLotsOfArgs(a, b, c, d, e, f, g, h, i, j)
					return a + b + c + d + e + f + g + h + i + j
				end
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			Test.Assert(tinker.Call<int>("TestRet1") == 1);
			Test.Assert(tinker.Call<int, (int, char32)>("TestRetPlus", (13, (.)22)) == 55);
			Test.Assert(tinker.Call<int, (int, int, int, int, int, int, int, int, int, int)>("TestLotsOfArgs", (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)) == 55);
		}
	}
}
