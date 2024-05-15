using System;
using KeraLua;
using System.IO;
using System.Diagnostics;

namespace LuaTinker.Tests
{
	static class TestDlgMethod
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			String str = scope .();

			tinker.AddClass<String>("StringBuilder");
			tinker.AddClassCtor<String>();
			tinker.AddClassMethod<String, function Result<void>(String this, StringView, params Span<Object>)>("AppendF", => String.AppendF);
			tinker.AddClassMethod<String, function String(String)>("str", (str) => str); // This is necessary to convert from a String instance to a Lua String.

			tinker.AddMethod<delegate String()>("GetStringBuilder", new () => str);

			if (lua.DoString(
				@"""
				sb4 = GetStringBuilder()
				a = 1
				b = 9999999999
				c = nil
				d = null
				e = none
				f = false
				sb4:AppendF("{} {} {} {} {} {}", a, b, c, d, e, f)
				if sb4:str() ~= "1 9999999999 null null null False" then
					error("Text didn't match")
				end
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			Test.Assert(str == "1 9999999999 null null null False");
		}
	}
}
