using System;
using System.Collections;
using KeraLua;

namespace LuaTinker.Tests
{
	static class TestLuaTable
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);

			if (lua.DoString(
				"""
				test_table = {
					name = "Player One",
					score = 12345,
					is_active = true,
					[10] = "ten",
					nested = { value = 99 }
				}
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			if (tinker.GetTable!("test_table") case .Ok(var table))
			{
				Test.Assert(table.GetValue<StringView>("name").Get() == "Player One");
				Test.Assert(table.GetValue<int>("score").Get() == 12345);
				Test.Assert(table.GetValue<bool>("is_active").Get());
				Test.Assert(table.GetValue<StringView>(10).Get() == "ten");
				if (table.GetTable!("nested") case .Ok(var nested))
					Test.Assert(nested.GetValue<int>("value").Get() == 99);
				else Test.FatalError("Failed to get nested table.");

				int itemCount = 0;
				for (var (key, value) in table)
				{
					itemCount++;

					let keyStr = scope String();
					key.ToString(keyStr);

					switch (keyStr)
					{
					case "name": Test.Assert((StringView)value == "Player One");
					case "score": Test.Assert((int64)value == 12345);
					case "is_active": Test.Assert((bool)value == true);
					case "10": Test.Assert((StringView)value == "ten");
					case "nested":
						Test.Assert(value is LuaTable);
						Test.Assert(((LuaTable)value).GetValue<int8>("value") == 99);
					default:
						Test.FatalError(scope $"Unexpected key '{keyStr}' during iteration.");
					}
				}
				Test.Assert(itemCount == 5, "Enumerator did not yield 5 items.");

				// Test writing values
				table.SetValue("score", 54321);
				table.SetValue("new_value", "hello from beef");
				table.SetValue(20, false);
			}
			else
			{
				Test.FatalError("Failed to get LuaTable from Lua.");
			}

			if (lua.DoString(
				"""
				assert(test_table.score == 54321)
				assert(test_table.new_value == "hello from beef")
				assert(test_table[20] == false)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}