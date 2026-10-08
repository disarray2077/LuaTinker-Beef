using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestNullPointerArguments
	{
		public static class PointerAPI
		{
			[Inline] public static int32 Select(int32* value) => value == null ? 1 : -1;
			[Inline] public static int32 Select(float* value) => value == null ? 2 : -2;
			[Inline] public static int32 Select(int32 value) => 3;
			[Inline] public static bool OnlyInt32(int32* value) => value == null;
			[Inline] public static bool OnlyFloat(float* value) => value == null;
			[Inline] public static bool OnlyVoid(void* value) => value == null;
			[Inline] public static int32 OnlyValue(int32 value) => value;
			[Inline] public static int32 RefOnly(ref int32 value) => value;
			[Inline] public static bool OnlyObject(Object value) => value == null;
			[Inline] public static bool OnlyArray(int32[] value) => value == null;
			[Inline] public static int32 OnlySpan(Span<int32> value) => (int32)value.Length;
			public static int32 Variadic(params Span<int32*> values)
			{
				for (let value in values)
					if (value != null)
						return -1;
				return (int32)values.Length;
			}
			[Inline] public static int32 Variadic(params Span<float*> values) => -2;
		}

		public class PointerCtor
		{
			public int32 Kind;
			public this(int32* value) { Kind = value == null ? 1 : -1; }
			public this(float* value) { Kind = value == null ? 2 : -2; }
			[Inline] public int32 Pick(int32* value) => value == null ? 1 : -1;
			[Inline] public int32 Pick(float* value) => value == null ? 2 : -2;
		}

		public class ManualPointerCtor
		{
			public bool IsNull;
			public this(int32* value) { IsNull = value == null; }
		}

		[Test]
		public static void TestTypedNullSelection()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<PointerAPI>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNullPointerArguments.PointerAPI
				assert(api.Select(nullptr.int32) == 1)
				assert(api.OnlyInt32(nullptr.void))
				assert(api.OnlyFloat(nullptr.void))
				assert(api.OnlyVoid(nullptr.void))
				assert(api.OnlyInt32(nil))
				assert(api.Select(5) == 3)
				assert(not pcall(function() api.OnlyFloat(nullptr.int32) end))
				assert(not pcall(function() api.OnlyVoid(nullptr.int32) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNullPointerAmbiguity()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<PointerAPI>();
			tinker.AutoTinkClass<PointerCtor>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNullPointerArguments.PointerAPI
				local ok, err = pcall(function() api.Select(nullptr.void) end)
				assert(not ok and err:find("ambiguous null pointer overload at argument 1", 1, true), tostring(err))
				ok, err = pcall(function() PointerCtor(nullptr.void) end)
				assert(not ok and err:find("ambiguous null pointer overload at argument 1", 1, true), tostring(err))
				ok, err = pcall(function() PointerCtor(nullptr.int32):Pick(nullptr.void) end)
				assert(not ok and err:find("ambiguous null pointer overload at argument 1", 1, true), tostring(err))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNullPointerBindingEntryPoints()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<PointerCtor>();
			tinker.AddClass<ManualPointerCtor>();
			tinker.AddClassCtor<ManualPointerCtor, int32*>();
			tinker.AddClassVar<ManualPointerCtor, const "IsNull">();
			tinker.AddMethod<function bool(int32*)>("Direct", => PointerAPI.OnlyInt32);
			tinker.AddMethod<delegate bool(float*)>("Delegate", new (value) => value == null);
			if (lua.DoString("""
				assert(PointerCtor(nullptr.int32).Kind == 1)
				assert(PointerCtor(nullptr.int32):Pick(nullptr.int32) == 1)
				assert(ManualPointerCtor(nullptr.void).IsNull)
				assert(Direct(nullptr.int32))
				assert(Delegate(nullptr.void))
				assert(not pcall(function() Delegate(nullptr.int32) end))
				assert(not pcall(function() Direct(int32.cast(0)) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestVariadicNullPointers()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<PointerAPI>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNullPointerArguments.PointerAPI
				assert(api.Variadic(nullptr.int32, nullptr.void) == 2)
				assert(api.Variadic() == 0)
				local ok, err = pcall(function() api.Variadic(nullptr.void) end)
				assert(not ok and err:find("ambiguous null pointer overload at argument 1", 1, true), tostring(err))
				assert(not pcall(function() api.Variadic(nullptr.int32, int32.cast(0)) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNullHintsRejectNonPointerArguments()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<PointerAPI>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNullPointerArguments.PointerAPI
				assert(not pcall(function() api.OnlyValue(nullptr.int32) end))
				assert(not pcall(function() api.OnlyValue(nullptr.void) end))
				assert(not pcall(function() api.RefOnly(nullptr.int32) end))
				assert(not pcall(function() api.RefOnly(nullptr.void) end))
				local ok, err = pcall(function() api.OnlyObject(nullptr.int32) end)
				assert(not ok and err:find("nullptr.int32 hint", 1, true), tostring(err))
				ok, err = pcall(function() api.OnlyObject(nullptr.void) end)
				assert(not ok and err:find("nullptr.void hint", 1, true), tostring(err))
				assert(not pcall(function() api.OnlyArray(nullptr.void) end))
				assert(not pcall(function() api.OnlySpan(nullptr.int32) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNullHintsAreNotOrdinaryPointerValues()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			if (lua.DoString("hint = nullptr.int32"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(tinker.GetValue<int32*>("hint") case .Err);
		}
	}
}
