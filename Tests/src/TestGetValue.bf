using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestGetValue
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			if (lua.DoString(
				@"""
				a = 4
				b = 0.4
				c = 4.57e-3
				d = 0.3e12
				e = 5e+20
				f = true
				g = "hello"
				h = nil
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			LuaTinker tinker = scope .(lua);
			Test.Assert((tinker.GetValue<uint8>("a") case .Ok(let a)) && a == 4);
			Test.Assert((tinker.GetValue<char32>("a") case .Ok(let a2)) && a2 == '\x04');
			Test.Assert((tinker.GetValue<float>("b") case .Ok(let b)) && Math.WithinEpsilon(b, 0.4f));
			Test.Assert((tinker.GetValue<float>("c") case .Ok(let c)) && Math.WithinEpsilon(c, 4.57e-3f));
			Test.Assert((tinker.GetValue<double>("d") case .Ok(let d)) && d == 0.3e12);
			Test.Assert((tinker.GetValue<double>("e") case .Ok(let e)) && e == 5e+20);
			Test.Assert((tinker.GetValue<bool>("f") case .Ok(let f)) && f == true);
			Test.Assert((tinker.GetValue<StringView>("g") case .Ok(let g1)) && g1 == "hello");
			Test.Assert(tinker.GetValue<StringBuilder>("g") case .Err);
			Test.Assert((tinker.GetValue<Object>("h") case .Ok(let h)) && h == null);
			Test.Assert((tinker.GetValue<int32*>("h") case .Ok(let h2)) && h2 == null);
			Test.Assert(tinker.GetValue<int32>("i") case .Err);
		}
	}
}
