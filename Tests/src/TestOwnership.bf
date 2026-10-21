using System;
using KeraLua;

namespace LuaTinker.Tests
{
	class TestOwnership
	{
		public class Counters
		{
			public int32 Disposed;
			public int32 Destroyed;
		}

		public class Item : IDisposable
		{
			private Counters mCounters;
			public int32 Value;

			public this(Counters counters, int32 value)
			{
				mCounters = counters;
				Value = value;
			}

			public void Dispose() { mCounters.Disposed++; }
			public ~this() { mCounters.Destroyed++; }
		}

		[Test]
		public static void TestAdoptedClassLifetime()
		{
			let counters = scope Counters();
			{
				let lua = scope Lua(true);
				let tinker = scope LuaTinker(lua);
				tinker.AddClass<Item>();
				tinker.AddClassVar<Item, const "Value">();
				tinker.AddMethod<delegate Item()>("CreateItem", new () => new Item(counters, 7));
				if (lua.DoString("""
					held = CreateItem()
					assert(rawequal(take_ownership(held), held))
					assert(rawequal(take_ownership(held), held))
					collectgarbage('collect')
					assert(held.Value == 7)
					"""))
					Test.FatalError(lua.ToString(-1, .. scope .()));
				Test.Assert(counters.Disposed == 0 && counters.Destroyed == 0);
				tinker.GetValue<Item>("held").Get().Value = 9;
				if (lua.DoString("""
					assert(held.Value == 9)
					held = nil
					collectgarbage('collect')
					pending = take_ownership(CreateItem())
					"""))
					Test.FatalError(lua.ToString(-1, .. scope .()));
				Test.Assert(counters.Disposed == 1 && counters.Destroyed == 1);
			}
			Test.Assert(counters.Disposed == 2 && counters.Destroyed == 2);
		}

		[Test]
		public static void TestHeapConstructorOwnershipTransfer()
		{
			for (int mode < 2)
			{
				let counters = scope Counters();
				let lua = scope Lua(true);
				let tinker = scope LuaTinker(lua);
				tinker.AddClass<Counters>();
				tinker.AddClass<Item>();
				if (mode == 0)
					tinker.AddClassCtor<Item>(.Heap);
				else
					tinker.AddClassCtor<Item, (Counters, int32)>(.Heap);
				tinker.SetValue("counters", counters);
				if (lua.DoString("""
					held = Item(counters, 7)
					assert(rawequal(give_ownership(held), held))
					"""))
					Test.FatalError(lua.ToString(-1, .. scope .()));
				let item = tinker.GetValue<Item>("held").Get();
				if (lua.DoString("held = nil; collectgarbage('collect')"))
					Test.FatalError(lua.ToString(-1, .. scope .()));
				Test.Assert(counters.Disposed == 0 && counters.Destroyed == 0);
				Test.Assert(item.Value == 7);
				item.Dispose();
				delete item;
				Test.Assert(counters.Disposed == 1 && counters.Destroyed == 1);
			}
		}

		[Test]
		public static void TestAlreadyOwnedInlineClass()
		{
			let counters = scope Counters();
			{
				let lua = scope Lua(true);
				let tinker = scope LuaTinker(lua);
				tinker.AddClass<Counters>();
				tinker.AddClass<Item>();
				tinker.AddClassCtor<Item>();
				tinker.AddClassVar<Item, const "Value">();
				tinker.SetValue("counters", counters);
				if (lua.DoString("""
					local item = Item(counters, 5)
					assert(not pcall(function() give_ownership(item) end))
					assert(rawequal(take_ownership(item), item))
					assert(rawequal(take_ownership(item), item))
					item.Value = 8
					assert(item.Value == 8)
					"""))
					Test.FatalError(lua.ToString(-1, .. scope .()));
			}
			Test.Assert(counters.Disposed == 1 && counters.Destroyed == 1);
		}

		[Test]
		public static void TestUnadoptedClassRemainsBorrowed()
		{
			let counters = scope Counters();
			let item = scope Item(counters, 7);
			{
				let lua = scope Lua(true);
				let tinker = scope LuaTinker(lua);
				tinker.SetValue("borrowed", item);
				if (lua.DoString("borrowed = nil; collectgarbage('collect')"))
					Test.FatalError(lua.ToString(-1, .. scope .()));
			}
			Test.Assert(counters.Disposed == 0 && counters.Destroyed == 0);
		}

		[Test]
		public static void TestOwnershipRejectsNonClassValues()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			int32 value = 3;
			tinker.SetValue("pointer", &value);
			tinker.SetValue("reference", ref value);
			tinker.SetValue("ownedStruct", (3, 4));
			if (lua.DoString("""
				assert(not pcall(function() take_ownership() end))
				assert(not pcall(function() take_ownership(nil) end))
				assert(not pcall(function() take_ownership(1) end))
				assert(not pcall(function() take_ownership({}) end))
				assert(not pcall(function() take_ownership(pointer) end))
				assert(not pcall(function() take_ownership(reference) end))
				assert(not pcall(function() take_ownership(ownedStruct) end))
				assert(not pcall(function() take_ownership(ref.int32(3)) end))
				assert(not pcall(function() give_ownership() end))
				assert(not pcall(function() give_ownership(nil) end))
				assert(not pcall(function() give_ownership(reference) end))
				local file = assert(io.tmpfile())
				assert(not pcall(function() take_ownership(file) end))
				file:close()
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}
	}
}
