using System;
using System.Collections;
using KeraLua;

namespace LuaTinker.Tests
{
	static class TestIndexer
	{
		[Test]
		public static void TestList()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			// Register List<float> class
			tinker.AddClass<List<float>>("FloatList");
			tinker.AddClassCtor<List<float>>();
			tinker.AddClassIndexer<List<float>, int>();

			// Add a method to create a list for testing
			List<float> testList = scope .() { 1.0f, 2.0f, 3.0f, 4.0f, 5.0f };
			tinker.AddMethod<delegate List<float>()>("CreateList", new () => testList);

			if (lua.DoString(
				"""
				list = CreateList()
				assert(list[0] == 1.0)
				assert(list[1] == 2.0)
				assert(list[2] == 3.0)
				assert(list[3] == 4.0)
				assert(list[4] == 5.0)
				
				-- Modify values through indexer
				list[0] = 10.0
				list[2] = 30.0
				assert(list[0] == 10.0)
				assert(list[2] == 30.0)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			// Verify changes made from Lua
			Test.Assert(testList[0] == 10.0f);
			Test.Assert(testList[2] == 30.0f);
			Test.Assert(testList[1] == 2.0f); // Unchanged
			Test.Assert(testList[3] == 4.0f); // Unchanged
			Test.Assert(testList[4] == 5.0f); // Unchanged
		}

		[Test]
		public static void TestDictionary()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.AddClass<String>();
			tinker.AddClassCtor<String, String>();

			// Register Dictionary<String, int> class
			tinker.AddClass<Dictionary<String, int>>("IntDict");
			tinker.AddClassCtor<Dictionary<String, int>>();
			tinker.AddClassIndexer<Dictionary<String, int>, String>();

			// Create a test dictionary
			Dictionary<String, int> testDict = scope .()
			{
				("one", 1),
				("two", 2),
				("three", 3)
			};
			tinker.AddMethod<delegate Dictionary<String, int>()>("CreateDict", new () => testDict);

			if (lua.DoString(
				"""
				dict = CreateDict()
				assert(dict["one"] == 1)
				assert(dict["two"] == 2)
				assert(dict["three"] == 3)
				
				-- Modify values through indexer
				dict["one"] = 100
				dict["three"] = 300
				assert(dict["one"] == 100)
				assert(dict["three"] == 300)
				
				-- Add new key-value pair
				dict[String("four")] = 4
				assert(dict["four"] == 4)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			// Verify changes made from Lua
			Test.Assert(testDict["one"] == 100);
			Test.Assert(testDict["two"] == 2); // Unchanged
			Test.Assert(testDict["three"] == 300);
			Test.Assert(testDict["four"] == 4); // New entry
		}
	}
}