using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestEnum
	{
		static StringSplitOptions GetSSO()
		{
			return .RemoveEmptyEntries;
		}

		static void SetSSO(StringSplitOptions sso)
		{
			Test.Assert(sso == .None);
		}

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			tinker.AddNamespace("System");
			tinker.AddNamespaceEnum<StringSplitOptions>("System");
			tinker.AddMethod("GetSSO", (function StringSplitOptions()) => GetSSO);
			tinker.AddMethod("SetSSO", (function void(StringSplitOptions)) => SetSSO);

			if (lua.DoString(
				@"""
				assert(GetSSO() == System.StringSplitOptions.RemoveEmptyEntries)
				assert(GetSSO() == 1)
				SetSSO(System.StringSplitOptions.None)
				SetSSO(0)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}
