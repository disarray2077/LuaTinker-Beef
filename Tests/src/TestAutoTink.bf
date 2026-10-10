using KeraLua;
using System;
using System.Collections;
using LuaTinker.Helpers;

namespace LuaTinker.Tests
{
	class TestAutoTink
	{
		public static class FunctionAPI
		{
			public static int32 Count;
			public static function int32(int32) Callback;
			public const int32 Constant = 7;
			public static readonly int32 ReadOnly = 9;
		}

		[Test]
		public static void TestStaticFields()
		{
			FunctionAPI.Count = 3;
			FunctionAPI.Callback = (value) => value + 1;
			defer { FunctionAPI.Callback = null; }
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<FunctionAPI>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestAutoTink.FunctionAPI
				assert(api.Count == 3)
				api.Count = 7
				assert(api.Callback(41) == 42)
				assert(api.Constant == nil and api.ReadOnly == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(FunctionAPI.Count == 7);
			FunctionAPI.Callback = (value) => value * 2;
			if (lua.DoString("assert(LuaTinker.Tests.TestAutoTink.FunctionAPI.Callback(21) == 42)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		public static class FilteredAPI
		{
			public static int Twice(int value) => value * 2;
			public static int Twice(String value) => value.Length;
			public static int Triple(int value) => value * 3;
			public static int Triple(String value) => value.Length * 3;
		}

		public struct ExcludeTriple : IMethodExclusionProvider
		{
			[Comptime]
			public static void CollectExcludedMethods(Type type, HashSet<StringView> excluded)
				=> excluded.Add("Triple");
		}

		public static class MixedAPI
		{
			public function void Callback(int value);
			public delegate void CallbackDelegate(int value);
			public static int Twice(int value) => value * 2;
			public static int Twice(String value) => value.Length;
			public static int Twice(out int32 value) { value = 42; return 0; }
			public static int Twice(Callback callback) => -1;
			public static void SetCallback(Callback callback) {}
			public static void SetDelegate(CallbackDelegate callback) {}
			public static CallbackDelegate GetDelegate() => null;
			public static void Change(ref int32* pointer) { pointer = null; }
			public static void Produce(out int32* pointer) { pointer = null; }
			public static int32 ReadRef(ref int32 value) => value;
		}

		public class MixedConstructors
		{
			public int32 Value;
			public this(int32 value) { Value = value; }
			public this(out int32 value) { value = 99; Value = -1; }
			public this(function void() callback) { Value = -2; }
		}

		[Test]
		public static void TestMethodExclusions()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<FilteredAPI, const "", ExcludeTriple>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestAutoTink.FilteredAPI
				assert(api.Twice(21) == 42)
				assert(api.Twice("text") == 4)
				assert(api.Triple == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestUnsupportedMethodsExcluded()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<MixedAPI>();
			int32 holder = 7;
			tinker.SetValue("holder", ref holder);
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestAutoTink.MixedAPI
				assert(api.Twice(21) == 42)
				assert(api.Twice("text") == 4)
				assert(api.SetCallback == nil)
				assert(not pcall(function() api.SetDelegate(function() end) end))
				assert(api.GetDelegate == nil)
				assert(api.Change == nil)
				assert(api.Produce == nil)
				assert(api.ReadRef(holder) == 7)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestOutParameters()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<MixedAPI>();
			int32 holder = 7;
			tinker.SetValue("holder", ref holder);
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestAutoTink.MixedAPI
				assert(api.Twice(holder) == 0)
				local cell = ref.int32(7)
				assert(api.Twice(cell) == 0)
				assert(cell.value == 42)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(holder == 42);
		}

		[Test]
		public static void TestUnsupportedConstructorsExcluded()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<MixedConstructors>();
			int32 holder = 0;
			tinker.SetValue("holder", ref holder);
			if (lua.DoString("""
				assert(MixedConstructors(42).Value == 42)
				assert(not pcall(function() MixedConstructors(holder) end))
				assert(not pcall(function() MixedConstructors(function() end) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestReflectedConstructorsUseSignaturePolicy()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddClass<MixedConstructors>();
			tinker.AddClassCtor<MixedConstructors>();
			tinker.AddClassVar<MixedConstructors, const "Value">();
			if (lua.DoString("assert(MixedConstructors(42).Value == 42)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			tinker.AutoTinkClass<System.String, const "StringBuilder">();
			tinker.AutoTinkClass<System.Console>();

			if (lua.DoString(
				@"""
				str = StringBuilder()
				str:Append("1")
				str:Append("2", "2.1")
				str:Append("3")
				System.Console.WriteLine(str)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}
