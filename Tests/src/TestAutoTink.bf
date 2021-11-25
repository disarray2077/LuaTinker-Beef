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
			tinker.AutoTinkClass!<System.String>();

			if (lua.DoString(
				@"""
				
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}
