using System;
using KeraLua;
using System.IO;
using System.Diagnostics;

namespace LuaTinker.Tests
{
	static class TestClassIterop
	{
		public static String StrImpl(String self)
		{
			return self;
		}

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.AddNamespace("System.IO.File");
			tinker.AddNamespaceMethod<function Result<void, FileError>(StringView, String, bool)>("System.IO.File", "ReadAllText", => File.ReadAllText);
			
			tinker.AddClass<String>("StringBuilder");
			tinker.AddClassCtor<String>();
			tinker.AddClassMethod<String, function Result<void>(String this, StringView, params Object[])>("AppendF", => String.AppendF);
			tinker.AddClassMethod<String, function String(String)>("str", => StrImpl); // This is necessary to convert from a String instance to a Lua String.

			File.WriteAllText("test_tmp.txt", "All works!");
			defer File.Delete("test_tmp.txt");

			if (lua.DoString(
				@"""
				sb = StringBuilder()
				res = System.IO.File.ReadAllText("test_tmp.txt", sb, false)

				sb2 = StringBuilder()
				sb2:AppendF("Test '{}'", sb)
				if sb2:str() ~= "Test 'All works!'" then
				    error("Text didn't match")
				end

				sb3 = StringBuilder()
				sb3:AppendF("Test '{}'", sb:str())
				if sb3:str() ~= "Test 'All works!'" then
				    error("Text didn't match")
				end

				sb4 = StringBuilder()
				a = 1
				b = 9999999999
				c = nil
				d = null
				e = none
				f = false
				g = res
				sb4:AppendF("{} {} {} {} {} {}. Result: {}", a, b, c, d, e, f, g)
				if sb4:str() ~= "1 9999999999 null null null False. Result: Ok()" then
					error("Text didn't match")
				end
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}
