using System;
using KeraLua;

namespace LuaTinker.Tests
{
	class TestCoroutine
	{
		[Test]
		public static void TestBoundClassesAcrossYield()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddClass<String>("StringBuilder");
			tinker.AddClassCtor<String, String>();
			tinker.AddClassMethod<String, function String(String)>("str", (str) => str);
			let thread = lua.NewThread();
			defer { delete thread; lua.Pop(1); }
			Test.Assert(thread.LoadString("local value = StringBuilder('coroutine'); coroutine.yield(); return value:str()") == .OK);
			Test.Assert(thread.Resume(lua, 0, var results) == .Yield);
			if (thread.Resume(lua, 0, out results) != .OK)
				Test.FatalError(thread.ToString(-1, .. scope .()));
			Test.Assert(thread.ToString(-1, .. scope .()) == "coroutine");
			thread.Pop(results);
		}

		[Test]
		public static void TestNestedCoroutineClassBindings()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddClass<String>("StringBuilder");
			tinker.AddClassCtor<String, String>();
			tinker.AddClassMethod<String, function String(String)>("str", (str) => str);
			let parent = lua.NewThread();
			defer { delete parent; lua.Pop(1); }
			let child = parent.NewThread();
			defer { delete child; parent.Pop(1); }
			Test.Assert(child.LoadString("return StringBuilder('nested'):str()") == .OK);
			if (child.Resume(lua, 0, let results) != .OK)
				Test.FatalError(child.ToString(-1, .. scope .()));
			Test.Assert(child.ToString(-1, .. scope .()) == "nested");
			child.Pop(results);
		}

		[Test]
		public static void TestCaughtBindingError()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(int32)>("Twice", (value) => value * 2);
			let thread = lua.NewThread();
			defer { delete thread; lua.Pop(1); }
			Test.Assert(thread.LoadString("assert(not pcall(Twice, nil)); return Twice(3)") == .OK);
			if (thread.Resume(lua, 0) != .OK)
				Test.FatalError(thread.ToString(-1, .. scope .()));
			Test.Assert(thread.ToInteger(-1) == 6);
			thread.Pop(1);
		}

		[Test]
		public static void TestUncaughtBindingError()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(int32)>("Twice", (value) => value * 2);
			let thread = lua.NewThread();
			defer { delete thread; lua.Pop(1); }
			Test.Assert(thread.LoadString("coroutine.yield(); return Twice(nil)") == .OK);
			Test.Assert(thread.Resume(lua, 0) == .Yield);
			Test.Assert(thread.Resume(lua, 0, let results) == .ErrRun);
		}

		private static void CheckNestedProtection(LuaFunction nestedCall)
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(int32)>("Twice", (value) => value * 2);
			lua.Register("Nested", nestedCall);
			if (lua.DoString("""
				assert(not pcall(function() Nested(); Twice(nil) end))
				assert(Twice(3) == 6)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNestedPCallPreservesProtection()
		{
			CheckNestedProtection((state) =>
			{
				let lua = Lua.FromIntPtr(state);
				Test.Assert(lua.LoadString("return Twice(3)") == .OK);
				Test.Assert(lua.PCall(0, 1, 0) == .OK);
				lua.Pop(1);
				return 0;
			});
		}

		[Test]
		public static void TestNestedPCallKPreservesProtection()
		{
			CheckNestedProtection((state) =>
			{
				let lua = Lua.FromIntPtr(state);
				Test.Assert(lua.LoadString("return Twice(3)") == .OK);
				Test.Assert(lua.PCallK(0, 1, 0, 0, null) == .OK);
				lua.Pop(1);
				return 0;
			});
		}

		[Test]
		public static void TestNestedResumePreservesProtection()
		{
			CheckNestedProtection((state) =>
			{
				let lua = Lua.FromIntPtr(state);
				let thread = lua.NewThread();
				defer { delete thread; lua.Pop(1); }
				Test.Assert(thread.LoadString("return Twice(3)") == .OK);
				Test.Assert(thread.Resume(lua, 0) == .OK);
				thread.Pop(1);
				return 0;
			});
		}
	}
}
