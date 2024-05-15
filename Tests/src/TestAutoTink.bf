using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestAutoTink
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			tinker.AutoTinkClass<System.String, const "StringBuilder">();
			tinker.AutoTinkClass<System.Console>();

			if (lua.DoString(
				@"""
				str = StringBuilder()
				str:Append("1")
				str:Append("2", "2.1")
				str:Append("3")
				System.Console.WriteLine(str)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}
