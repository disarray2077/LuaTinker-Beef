using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestSetValue
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.SetValue("a", (int32)42);
			tinker.SetValue("b", 0.5f);
			tinker.SetValue("c", 1.23e10);
			tinker.SetValue("d", true);
			tinker.SetValue("e", "hello from Beef");
			tinker.SetValue("f", (Object)null);

			if (lua.DoString(
				@"""
				assert(a == 42, "Integer value mismatch")
				assert(b > 0.49 and b < 0.51, "Float value mismatch")
				assert(c == 1.23e10, "Double value mismatch")
				assert(d == true, "Boolean value mismatch")
				assert(e == "hello from Beef", "String value mismatch")
				assert(f == nil, "Null value should be nil in Lua")
				a = 99
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			Test.Assert((tinker.GetValue<int>("a") case .Ok(let a)) && a == 99);
		}
	}
}