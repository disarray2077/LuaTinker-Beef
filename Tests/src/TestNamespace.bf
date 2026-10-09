using System;
using KeraLua;

namespace System
{
	extension Version
	{
		public bool Check(Version other)
		{
			return (Major > other.Major) || ((Major == other.Major) && (Minor > other.Minor)) ||
				((Major == other.Major) && (Minor == other.Minor) && (Build > other.Build)) ||
				((Major == other.Major) && (Minor == other.Minor) && (Build == other.Build) && (Revision >= other.Revision));
		}
	}
}

namespace LuaTinker.Tests
{
	static class TestNamespace
	{
		static int32 mNum;
		public typealias Callback = function int32(uint32*);
		public static Callback Current;
		private static Callback sReturned;
		public static int32 Number;

		public class CallbackHolder
		{
			public Callback Value;
		}

		[Test]
		public static void TestCallableFunctionPointerField()
		{
			Current = null;
			defer { Current = null; }
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddNamespace("Callbacks");
			tinker.AddNamespaceVar<TestNamespace, const "Current">("Callbacks", "current");
			tinker.SetValue<function int32(int32)>("otherCallback", (value) => value);
			if (lua.DoString("assert(not pcall(function() Callbacks.current(ref.uint32(0)) end))"))
				Test.FatalError(lua.ToString(-1, .. scope .()));

			Current = (value) => { *value = 7; return 11; };
			if (lua.DoString("""
				savedCallback = Callbacks.current
				local cell = ref.uint32(0)
				assert(Callbacks.current(cell) == 11 and cell.value == 7)
				assert(not pcall(function() Callbacks.current(1) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));

			Current = (value) => { *value = 13; return 17; };
			if (lua.DoString("""
				local cell = ref.uint32(0)
				assert(Callbacks.current(cell) == 17 and cell.value == 13)
				Callbacks.current = savedCallback
				assert(Callbacks.current(cell) == 11 and cell.value == 7)
				assert(not pcall(function() Callbacks.current = 1 end))
				assert(not pcall(function() Callbacks.current = otherCallback end))
				assert(not pcall(function() Callbacks.current = function() end end))
				assert(Callbacks.current(cell) == 11)
				Callbacks.current = nil
				assert(not pcall(function() Callbacks.current(cell) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(Current == null);
		}

		[Test]
		public static void TestFunctionPointerReturn()
		{
			sReturned = null;
			defer { sReturned = null; }
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function Callback()>("GetCallback", () => sReturned);
			if (lua.DoString("assert(not pcall(function() GetCallback()(ref.uint32(0)) end))"))
				Test.FatalError(lua.ToString(-1, .. scope .()));

			sReturned = (value) => { *value = 7; return 11; };
			if (lua.DoString("""
				savedCallback = GetCallback()
				local cell = ref.uint32(0)
				assert(savedCallback(cell) == 11 and cell.value == 7)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			let saved = tinker.GetValue<Callback>("savedCallback").Get();
			sReturned = (value) => { *value = 13; return 17; };
			if (lua.DoString("""
				local cell = ref.uint32(0)
				assert(GetCallback()(cell) == 17 and cell.value == 13)
				assert(savedCallback(cell) == 11 and cell.value == 7)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			uint32 value = 0;
			Test.Assert(saved(&value) == 11 && value == 7);
		}

		[Test]
		public static void TestStaticNamespaceField()
		{
			Number = 5;
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddNamespace("Fields");
			tinker.AddNamespaceVar("Fields", "Number", 99);
			tinker.AddNamespaceVar<TestNamespace, const "Number">("Fields");
			if (lua.DoString("""
				assert(Fields.Number == 5)
				Fields.Number = 8
				Fields.extra = 13
				assert(Fields.extra == 13 and Fields.missing == nil)
				assert(not pcall(function() Fields.Number = "invalid" end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(Number == 8);
			Number = 21;
			if (lua.DoString("assert(Fields.Number == 21)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestCallableClassField()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddClass<CallbackHolder>("CallbackHolder");
			tinker.AddClassVar<CallbackHolder, const "Value">();
			let holder = scope CallbackHolder();
			holder.Value = (value) => { *value = 7; return 11; };
			tinker.SetValue("holder", holder);
			if (lua.DoString("savedCallback = holder.Value"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			holder.Value = (value) => { *value = 13; return 17; };
			if (lua.DoString("""
				local cell = ref.uint32(0)
				assert(holder.Value(cell) == 17 and cell.value == 13)
				holder.Value = savedCallback
				assert(holder.Value(cell) == 11 and cell.value == 7)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			uint32 value = 0;
			Test.Assert(holder.Value(&value) == 11 && value == 7);
		}

		public static void TestCall(int8 i)
		{
			mNum += i;
		}

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.AddClass<Version>("Version");
			tinker.AddClassMethod<Version, function bool(Version this, Version)>("Check", => Version.Check);

			tinker.AddNamespace("LuaTinker.Tests");
			tinker.AddNamespaceMethod("LuaTinker.Tests", "TestCall", (function void(int8)) => TestCall);
			tinker.AddNamespaceVar("LuaTinker", "Version", Environment.OSVersion.Version);

			tinker.AddMethod<function Version()>("GetVersion", () => Environment.OSVersion.Version);

			if (lua.DoString(
				@"""
				if not LuaTinker.Version:Check(GetVersion()) then
					error("Version check failed")
				end
				LuaTinker.Tests.TestCall(32)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
			
			tinker.AddNamespace("LuaTinker.Tests.Networking.Factory.Services");
			tinker.AddNamespaceMethod("LuaTinker.Tests.Networking.Factory.Services", "CreateInstance", (function void(int8)) => TestCall);
			tinker.AddNamespaceMethod("LuaTinker.Tests.Networking", "SendData", (function void(int8)) => TestCall);
			
			if (lua.DoString(
				@"""
				LuaTinker.Tests.Networking.Factory.Services.CreateInstance(55)
				LuaTinker.Tests.Networking.SendData(-7)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			Test.Assert(mNum == 32 + 55 - 7);
		}
	}
}
