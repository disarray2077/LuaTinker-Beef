using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestNumericArguments
	{
		public enum SignedChoice : int32
		{
			One = 1
		}

		public enum UnsignedChoice : uint32
		{
			One = 1
		}

		public struct EmptyChoice : int32 {}
		public struct EmptyWideChoice : uint64 {}
		public struct Distance : float {}
		public struct WideDistance : double {}

		public enum WideChoice : uint64
		{
			Max = 0x7FFFFFFFFFFFFFFF
		}

		public enum DefinedChoice : int32
		{
			One = 1,
			Shared = 2
		}

		public enum OtherChoice : int32
		{
			Shared = 2,
			Three = 3
		}

		public class NumericSlot
		{
			public int32 Value;
		}

		public class NumericCtor
		{
			public int32 Kind;
			public this(int32 value) { Kind = 32; }
			public this(uint32 value) { Kind = 132; }
			public int32 Pick(uint8 value) => 8;
			public int32 Pick(uint32 value) => 32;
		}

		public class NarrowCtor
		{
			public this(uint8 value) {}
			public this(uint32 value) {}
		}

		public class ManualUIntCtor
		{
			public int32 Kind;
			public this(uint32 value) { Kind = (int32)value; }
		}

		public class NumericCallTarget
		{
			public int32 Calls;
			public int32 Narrow(uint8 value) { Calls++; return 8; }
			public int32 Narrow(uint32 value) { Calls++; return 132; }
		}

		public static class NumericOverloads
		{
			public static int32 Pick(int32 value) => 32;
			public static int32 Pick(uint32 value) => 132;
			public static int32 PickEnum(SignedChoice value) => 1;
			public static int32 PickEnum(UnsignedChoice value) => 2;
			public static int32 OnlyEnum(SignedChoice value) => 101;
			public static int32 PickDefined(EmptyChoice value) => 0;
			public static int32 PickDefined(DefinedChoice value) => 1;
			public static int32 PickDefined(OtherChoice value) => 2;
			public static int32 PickFallback(EmptyChoice value) => 0;
			public static int32 PickFallback(DefinedChoice value) => 1;
			public static int32 PickWide(EmptyWideChoice value) => 0;
			public static int32 PickWide(WideChoice value) => 1;

			public static int32 Mixed(int32 value) => 32;
			public static int32 Mixed(SignedChoice value) => 101;
			public static int32 EnumFirst(SignedChoice value) => 101;
			public static int32 EnumFirst(int32 value) => 32;
			public static int32 Pair(int32 first, uint32 second) => 12;
			public static int32 Pair(uint32 first, int32 second) => 21;
			public static int32 AmbiguousSecond(int32 first, uint8 second) => 8;
			public static int32 AmbiguousSecond(int32 first, uint32 second) => 32;
			public static int32 AmbiguousRange(uint8 value) => 8;
			public static int32 AmbiguousRange(uint16 value) => 16;
			public static int32 AmbiguousRange(uint32 value) => 32;
			public static int32 Later(uint8 first, bool second) => 8;
			public static int32 Later(uint32 first, StringView second) => 32;
			public static int32 PreferredPrefix(int32 first, bool second) => 1;
			public static int32 PreferredPrefix(uint32 first, StringView second) => 2;
			public static int32 Sum(int32 value) => value;
			public static int32 Sum(params Span<uint32> values)
			{
				int32 total = 0;
				for (var value in values)
					total += (int32)value;
				return total;
			}
			public static int32 Direct(uint32 value) => (int32)value;
			public static int32 DeepestFailure(bool first, bool second, StringView third) => 1;
			public static int32 DeepestFailure(Object first, int32 second) => 2;
		}

		public static class FloatingOverloads
		{
			public static (int32, double) Pick(float value) => (1, value);
			public static (int32, double) Pick(double value) => (2, value);
			public static (double, float) Pair(double first, float second) => (first, second);
		}

		public static class TypedFloatingOverloads
		{
			public static (int32, double) Pick(Distance value) => (1, (double)value);
			public static (int32, double) Pick(WideDistance value) => (2, (double)value);
		}

		[Test]
		public static void TestIntegerOverloadSelection()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(api.Pick(-1) == 32)
				assert(api.Pick(1) == 32)
				assert(api.Pick(int32.cast(1)) == 32)
				assert(api.Pick(uint32.cast(1)) == 132)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestEnumOverloadSelection()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddEnum<SignedChoice>();
			tinker.AddNamespace("Choices");
			tinker.AddNamespaceEnum<UnsignedChoice>("Choices");
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(api.PickEnum(SignedChoice.cast(1)) == 1)
				assert(api.PickEnum(Choices.UnsignedChoice.cast(1)) == 2)
				assert(api.PickEnum(4294967295) == 2)
				assert(api.OnlyEnum(SignedChoice.One) == 101)
				assert(api.OnlyEnum(SignedChoice.cast(1)) == 101)
				assert(not pcall(function() api.PickEnum(1) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestEnumIntegerSelectionIgnoresDeclarationOrder()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddEnum<SignedChoice>();
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(not pcall(function() api.Mixed(SignedChoice.One) end))
				assert(not pcall(function() api.Mixed(2) end))
				assert(not pcall(function() api.EnumFirst(1) end))
				assert(api.Mixed(int32.cast(1)) == 32)
				assert(api.Mixed(SignedChoice.cast(1)) == 101)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestMultipleArgumentSelection()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(api.Pair(1, 2) == 12)
				assert(api.Pair(int32.cast(1), uint32.cast(2)) == 12)
				assert(api.Pair(uint32.cast(1), int32.cast(2)) == 21)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNumericAmbiguityPrecedesLaterArguments()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(api.Later(300, "text") == 32)
				assert(not pcall(function() api.Later(1, true) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestPreferredNumericPrefixDoesNotRetry()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				local ok, err = pcall(function() api.PreferredPrefix(1, "text") end)
				assert(not ok and err:find("expected 'bool' at argument 2 but got 'string'", 1, true), tostring(err))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestOverloadArgumentDiagnostics()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				local ok, err = pcall(function() api.AmbiguousSecond(1, 1) end)
				assert(not ok and err:find("ambiguous numeric overload at argument 2 ('uint8' or 'uint32')", 1, true), tostring(err))
				ok, err = pcall(function() api.AmbiguousRange(300) end)
				assert(not ok and err:find("ambiguous numeric overload at argument 1 ('uint16' or 'uint32')", 1, true), tostring(err))
				ok, err = pcall(function() api.PreferredPrefix(true, "text") end)
				assert(not ok and err:find("'int32'", 1, true) and err:find("'uint32'", 1, true)
				    and err:find("at argument 1 but got 'boolean'", 1, true), tostring(err))
				ok, err = pcall(function() api.PickEnum(int32.cast(1)) end)
				assert(not ok and err:find("at argument 1 but got 'int32 cast'", 1, true), tostring(err))
				ok, err = pcall(function() api.DeepestFailure(int32.cast(1), false) end)
				assert(not ok and err:find("at argument 1 but got 'int32 cast'", 1, true), tostring(err))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestOverloadDiagnosticKeepsDeepestArgument()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(api.DeepestFailure(true, true, "text") == 1)
				assert(api.DeepestFailure({}, 1) == 2)
				local ok, err = pcall(function() api.DeepestFailure(true, true, {}) end)
				assert(not ok and err:find("argument 3", 1, true) and err:find("StringView", 1, true))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNumericOverloadArgumentCount()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(not pcall(function() api.PreferredPrefix() end))
				assert(not pcall(function() api.PreferredPrefix(true) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNumericHintBindingEntryPoints()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericCtor>();
			tinker.AddClass<ManualUIntCtor>();
			tinker.AddClassCtor<ManualUIntCtor, uint32>();
			tinker.AddClassVar<ManualUIntCtor, const "Kind">();
			tinker.AddMethod<function int32(uint32)>("DirectUInt", => NumericOverloads.Direct);
			tinker.AddMethod<delegate int32(uint32)>("DirectDelegate", new (value) => (int32)value + 1);
			if (lua.DoString("""
				assert(NumericCtor(1).Kind == 32)
				assert(NumericCtor(uint32.cast(1)).Kind == 132)
				assert(ManualUIntCtor(uint32.cast(7)).Kind == 7)
				assert(DirectUInt(uint32.cast(7)) == 7)
				assert(DirectDelegate(uint32.cast(7)) == 8)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestConstructorAndInstanceAmbiguityUsesVisibleArgumentIndices()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericCtor>();
			tinker.AutoTinkClass<NarrowCtor>();
			if (lua.DoString("""
				local ok, err = pcall(function() NumericCtor(1):Pick(1) end)
				assert(not ok and err:find("ambiguous numeric overload at argument 1", 1, true), tostring(err))
				ok, err = pcall(function() NarrowCtor(1) end)
				assert(not ok and err:find("ambiguous numeric overload at argument 1", 1, true), tostring(err))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNumericVariadicArguments()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(api.Sum(uint32.cast(1), uint32.cast(2)) == 3)
				assert(not pcall(function() api.Sum(1, 2) end))
				assert(not pcall(function() api.Sum(uint32.cast(1), int32.cast(2)) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestIntegerCastValidation()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddEnum<SignedChoice>();
			tinker.AddNamespace("Choices");
			tinker.AddNamespaceEnum<UnsignedChoice>("Choices");
			tinker.AddMethod<function int32(int32)>("SignedValue", (value) => value);
			tinker.AddMethod<function uint32(uint32)>("UnsignedValue", (value) => value);
			if (lua.DoString("""
				assert(SignedValue(int32.cast(-2147483648)) == -2147483648)
				assert(SignedValue(int32.cast(2147483647)) == 2147483647)
				assert(UnsignedValue(uint32.cast(4294967295)) == 4294967295)
				assert(not pcall(function() int32.cast(-2147483649) end))
				assert(not pcall(function() uint32.cast(-1) end))
				assert(not pcall(function() uint32.cast(4294967296) end))
				assert(not pcall(function() int32.cast(2147483648) end))
				assert(not pcall(function() int32.cast(1.5) end))
				assert(not pcall(function() SignedChoice.cast(2147483648) end))
				assert(not pcall(function() Choices.UnsignedChoice.cast(-1) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestFieldAssignmentRejectsNumericHints()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddClass<NumericSlot>();
			tinker.AddClassVar<NumericSlot, const "Value">();
			let slot = scope NumericSlot();
			slot.Value = 7;
			tinker.SetValue("slot", slot);
			if (lua.DoString("""
				assert(not pcall(function() slot.Value = int32.cast(3) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(slot.Value == 7);
		}

		[Test]
		public static void TestGetValueRejectsInvalidNumericConversions()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			if (lua.DoString("""
				tag = int32.cast(1)
				hint = uint32.cast(7)
				negative = -1
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(tinker.GetValue<int32>("tag") case .Err);
			Test.Assert(tinker.GetValue<LuaTable>("hint") case .Err);
			Test.Assert(tinker.GetValue<uint32>("negative") case .Err);
		}

		[Test]
		public static void TestRejectedNumericCallDoesNotInvokeTarget()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddClass<NumericCallTarget>();
			tinker.AddClassMethod<NumericCallTarget, const "Narrow">();
			let target = scope NumericCallTarget();
			tinker.SetValue("target", target);
			if (lua.DoString("""
				assert(not pcall(function() target:Narrow(1) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(target.Calls == 0);
			if (lua.DoString("""
				assert(target:Narrow(uint32.cast(1)) == 132)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(target.Calls == 1);
		}

		[Test]
		public static void TestFloatingOverloadSelection()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<FloatingOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.FloatingOverloads
				local kind, value = api.Pick(float.cast(0.25))
				assert(kind == 1 and value == 0.25)
				kind, value = api.Pick(double.cast(0.25))
				assert(kind == 2 and value == 0.25)
				kind, value = api.Pick(1e40)
				assert(kind == 2 and value == 1e40)
				local first, second = api.Pair(double.cast(9), float.cast(2))
				assert(first == 9 and second == 2)
				first, second = api.Pair(double.cast(1e40), float.cast(2))
				assert(first == 1e40 and second == 2)
				assert(not pcall(function() api.Pick(0.25) end))
				assert(not pcall(function() api.Pick(int32.cast(1)) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestFloatingTypedPrimitiveSelection()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<TypedFloatingOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.TypedFloatingOverloads
				local kind, value = api.Pick(1e40)
				assert(kind == 2 and value == 1e40)
				assert(not pcall(function() api.Pick(0.25) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestFloatingTypedPrimitiveConversion()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function double(Distance)>("ReadDistance", (value) => (double)value);
			tinker.AddMethod<function double(WideDistance)>("ReadWideDistance", (value) => (double)value);
			if (lua.DoString("""
				assert(ReadDistance(0.25) == 0.25)
				assert(not pcall(function() ReadDistance(1e40) end))
				assert(ReadWideDistance(1e40) == 1e40)
				assert(not pcall(function() ReadWideDistance(math.huge) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestFloatingCastValidation()
		{
			let lua = scope Lua(true);
			scope LuaTinker(lua);
			if (lua.DoString("""
				assert(not pcall(function() float.cast(1e40) end))
				assert(not pcall(function() double.cast(math.huge) end))
				assert(not pcall(function() double.cast(0 / 0) end))
				assert(not pcall(function() float.cast("0.5") end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestSignedByteConversionRange()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int8(int8)>("SignedByte", (value) => value);
			if (lua.DoString("""
				assert(SignedByte(-128) == -128)
				assert(SignedByte(127) == 127)
				assert(not pcall(function() SignedByte(-129) end))
				assert(not pcall(function() SignedByte(128) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestFloatingConversionRange()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function double(float)>("DirectFloat", (value) => value);
			tinker.AddMethod<function double(double)>("DirectDouble", (value) => value);
			if (lua.DoString("""
				assert(DirectFloat(0.25) == 0.25)
				assert(not pcall(function() DirectFloat(1e40) end))
				assert(not pcall(function() DirectFloat(-1e40) end))
				assert(DirectDouble(1e40) == 1e40)
				assert(not pcall(function() DirectDouble(math.huge) end))
				assert(not pcall(function() DirectDouble(0 / 0) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestFloatingHintConversion()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function double(float)>("DirectFloat", (value) => value);
			tinker.AddMethod<delegate double(double)>("DelegateDouble", new (value) => value);
			if (lua.DoString("""
				assert(DirectFloat(float.cast(0.25)) == 0.25)
				assert(DelegateDouble(double.cast(0.25)) == 0.25)
				assert(not pcall(function() DirectFloat(double.cast(0.25)) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestObjectAndTableRejectNumericHints()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(Object)>("ObjectArgument", (value) => 1);
			tinker.AddMethod<function int32(LuaTable)>("TableArgument", (value) => 2);
			if (lua.DoString("""
				assert(ObjectArgument({}) == 1)
				assert(TableArgument({}) == 2)
				assert(not pcall(function() ObjectArgument(int32.cast(1)) end))
				assert(not pcall(function() TableArgument(int32.cast(1)) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNumericCastArgumentValidation()
		{
			let lua = scope Lua(true);
			scope LuaTinker(lua);
			if (lua.DoString("""
				assert(not pcall(function() int32.cast('1') end))
				assert(not pcall(function() uint32.cast() end))
				assert(not pcall(function() double.cast(1, 2) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestPopHintedPreservesStackHeight()
		{
			let lua = scope Lua(true);
			scope LuaTinker(lua);
			if (lua.DoString("""
				hint = uint32.cast(7)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			lua.GetGlobal("hint");
			let top = lua.GetTop();
			Test.Assert(StackHelpers.StackHelper.PopHinted<uint32>(lua, -1) == 7);
			Test.Assert(lua.GetTop() == top);
			lua.Pop(1);
		}

		[Test]
		public static void TestDefinedEnumSelection()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddEnum<DefinedChoice>();
			tinker.AddEnum<OtherChoice>();
			tinker.AddEnum<WideChoice>();
			tinker.AutoTinkClass<NumericOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(api.PickDefined(DefinedChoice.One) == 1)
				assert(api.PickDefined(OtherChoice.Three) == 2)
				assert(api.PickWide(9223372036854775807) == 1)
				assert(api.PickFallback(DefinedChoice.cast(4)) == 1)
				local ok, err = pcall(function() api.PickDefined(2) end)
				assert(not ok and err:find("'LuaTinker.Tests.TestNumericArguments.DefinedChoice'", 1, true)
				    and err:find("'LuaTinker.Tests.TestNumericArguments.OtherChoice'", 1, true)
				    and not err:find("EmptyChoice", 1, true), tostring(err))
				assert(not pcall(function() api.PickFallback(4) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

	}
}
