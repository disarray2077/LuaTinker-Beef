using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestClassCtor
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.AddClass<String>("StringBuilder");
			tinker.AddClassCtor<String, String>();
			tinker.AddClassMethod<String, function Result<void>(String this, StringView, params Span<Object>)>("AppendF", => String.AppendF);
			tinker.AddClassMethod<String, function String(String)>("str", (str) => str);

			if (lua.DoString(
				@"""
				str = StringBuilder("Hello ")
				str:AppendF("'{}'", "LuaTinker")
				assert(str:str() == "Hello 'LuaTinker'")
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}
