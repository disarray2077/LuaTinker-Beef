using KeraLua;
using System;

namespace LuaTinker.Tests
{
	[Reflect(.All)]
	class TestMultiReturn
	{
		public static (int, StringView) GetTuple()
		{
			return (1337, typeof(Self).GetMethod("GetTuple").Get().Name);
		}

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;
			
			LuaTinker tinker = scope .(lua);
			tinker.AddMethod<function (int, StringView)()>("GetTuple", => GetTuple);

			if (lua.DoString(
				@"""
				num, str = GetTuple()
				if num ~= 1337 or str ~= "GetTuple" then
					error("Tuple isn't valid")
				end

				function GetTuple_Lua()
					return 1, 1.4, "3"
				end
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			// TODO
			//(let a, let b, let c) = tinker.Call<(int, float, StringView)>("GetTuple_Lua").Get();
			//Test.Assert(a == 1);
			//Test.Assert(Math.WithinEpsilon(b, 1.4f));
			//Test.Assert(c == "3");
		}
	}
}
