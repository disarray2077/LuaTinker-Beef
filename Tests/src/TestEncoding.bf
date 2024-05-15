using System;
using KeraLua;

namespace LuaTinker.Tests
{
	static class TestEncoding
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			tinker.AddMethod<function String(String)>(
				"test",
				(str) =>
				{
					Test.Assert(str == "s̶̡̨̜͙̟͙͚̹̜̭͖̘͗̀̍̾p̶̢̧̛͕̬͈͚͖̹̯̰̫͎̥̌͌̏̋̔͐̌̋̾͘ͅo̶̤̹̟̭͚̬̿ǫ̵̨̢̻̤͇̝̬̤͚̋̃͊́̎̐͒̈́̅͌̕k̴͕̫͒͂̈͋̾̾͛̽̈̐̃̚͝y̷̡̛̘͍̜̟͉̳̗̽̄̊̉̅̓͒͑̕͘͘̚"
						|| str == "Anão anáio açõrai"
						|| str == "わびさび");
					return "👌";
				});

			if (lua.DoString(
				@"""
				assert(test("s̶̡̨̜͙̟͙͚̹̜̭͖̘͗̀̍̾p̶̢̧̛͕̬͈͚͖̹̯̰̫͎̥̌͌̏̋̔͐̌̋̾͘ͅo̶̤̹̟̭͚̬̿ǫ̵̨̢̻̤͇̝̬̤͚̋̃͊́̎̐͒̈́̅͌̕k̴͕̫͒͂̈͋̾̾͛̽̈̐̃̚͝y̷̡̛̘͍̜̟͉̳̗̽̄̊̉̅̓͒͑̕͘͘̚") == "👌")
				assert(test("Anão anáio açõrai") == "👌")
				assert(test("わびさび") == "👌")
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}
