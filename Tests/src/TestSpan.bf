using System;
using KeraLua;
using LuaTinker.StackHelpers;

namespace LuaTinker.Tests
{
	class TestSpan
	{
		public enum Choice : int32 { One = 1, Two = 2 }
		public struct Distance : float {}
		public struct Value { public int32 Number; }
		public class BaseValue { public int32 Number; }
		public class DerivedValue : BaseValue {}

		public static class SpanOverloads
		{
			public static int32 WithFallback(String value) => 1;
			public static int32 WithFallback(Object value) => 2;
			public static int32 WithFallback(Span<String> values) => 3;
			public static int32 WithFallback(Span<int32> values) => 4;
			public static int32 Select(Span<String> values) => 10 + (int32)values.Length;
			public static int32 Select(Span<int32> values) => 20 + (int32)values.Length;
			public static int32 Numeric(Span<int32> values) => 32;
			public static int32 Numeric(Span<uint32> values) => 132;
			public static int32 PreferInt(Span<int32> values) => 32;
			public static int32 PreferInt(Span<float> values) => 132;
			public static int32 OtherNumeric(Span<uint32> values) => 32;
			public static int32 OtherNumeric(Span<float> values) => 132;
			public static int32 Elements(Span<uint8> values) => 1;
			public static int32 Elements(Span<bool> values) => 2;
			public static int32 Elements(Span<BaseValue> values) => values[0].Number;
			public static int32 Single(Span<BaseValue> values) => values[0].Number;
		}

		public class SpanTarget
		{
			public int32 Calls;
			public int32 Reserve(Object value) { Calls++; return -1; }
			public int32 Reserve(Span<int32> values) { Calls++; return Fingerprint(values); }
			public int32 Pair(Span<String> names, Span<int32> values) { Calls++; return (int32)(names.Length + values.Length); }
		}

		public class Reflected
		{
			public int32 Value;
			public this(Span<int32> values) { Value = Fingerprint(values); }
			public int32 Read(Span<int32> values) => Fingerprint(values);
		}

		public class Direct
		{
			public int32 Value;
			public this(Span<int32> values) { Value = Fingerprint(values); }
		}

		public static int32 Fingerprint(Span<int32> values)
		{
			int32 result = 0;
			for (let value in values)
				result = result * 10 + value;
			return result;
		}
		public static int32 ReadTables(Span<LuaTable> values)
		{
			var table = values[0];
			return table.GetValue<int32>("value").Get();
		}

		[Test]
		public static void TestInputSpanUsesPrimitivePopConversions()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function bool(Span<bool>)>("ReadBool", (values) => values[0]);
			tinker.AddMethod<function char8(Span<char8>)>("ReadChar", (values) => values[0]);
			tinker.AddMethod<function Distance(Span<Distance>)>("ReadDistance", (values) => values[0]);
			tinker.AddMethod<function StringView(Span<StringView>)>("ReadView", (values) => values[0]);
			if (lua.DoString("""
				assert(ReadBool({true}))
				assert(ReadChar({65}) == 65)
				assert(ReadDistance({1.5}) == 1.5)
				assert(ReadView({"text"}) == "text")
				assert(not pcall(function() ReadBool({1}) end))
				assert(not pcall(function() ReadDistance({1e40}) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestInputSpanWrapperConversions()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddClass<BaseValue>();
			tinker.AddClass<DerivedValue>();
			tinker.AddClassParent<DerivedValue, BaseValue>();
			tinker.AutoTinkClass<SpanOverloads>();
			let instance = scope DerivedValue() { Number = 7 };
			tinker.SetValue("instance", instance);
			Value value = .() { Number = 9 };
			tinker.SetValue("value", ref value);
			int32 pointed = 11;
			tinker.SetValue("pointer", &pointed);
			tinker.AddMethod<function int32(Span<Value>)>("ReadValue", (values) => values[0].Number);
			tinker.AddMethod<function int32(Span<int32*>)>("ReadPointer", (values) => *values[0]);
			tinker.AddMethod<function int32(Span<Object>)>("ReadObjectValue", (values) => (values[0] as BaseValue).Number);
			tinker.AddMethod<function String(Span<String>)>("StringFirst", (values) => values[0]);
			let borrowedString = scope String("borrowed");
			Type2User.Create(lua, borrowedString);
			lua.SetGlobal("borrowedString");
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestSpan.SpanOverloads
				assert(api.Elements({1}) == 1)
				assert(not pcall(function() api.Elements({true}) end))
				assert(not pcall(function() api.Elements({instance}) end))
				assert(api.Single({instance}) == 7)
				assert(ReadValue({value}) == 9)
				assert(ReadPointer({pointer}) == 11)
				assert(ReadObjectValue({instance}) == 7)
				assert(StringFirst({borrowedString}) == "borrowed")
				instances = {instance}
				foreign = {io.stdout}
				assert(not pcall(function() api.Elements({value}) end))
				assert(not pcall(function() ReadValue({instance}) end))
				assert(not pcall(function() ReadPointer({value}) end))
				assert(not pcall(function() ReadObjectValue({pointer}) end))
				assert(not pcall(function() api.Elements(foreign) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert((tinker.GetSpan!<BaseValue>("instances") case .Ok(let instances)) && instances[0] == instance);
			Test.Assert(tinker.GetSpan!<BaseValue>("foreign") case .Err);
			Test.Assert(lua.GetTop() == 0);
		}

		[Test]
		public static void TestNestedAndObjectInputSpans()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(Span<Span<int32>>)>("ReadNested", (values) => Fingerprint(values[0]) + Fingerprint(values[1]));
			tinker.AddMethod<function bool(Span<Object>)>("ReadObjects", (values) => (values[0] as int64?) == 4 && (values[1] as bool?) == true);
			if (lua.DoString("""
				assert(ReadNested({{4, 1}, {3}}) == 44)
				assert(ReadObjects({4, true}))
				assert(not pcall(function() ReadNested({{4}, {true}}) end))
				assert(not pcall(function() ReadObjects({function() end}) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestLuaTableSpanLifetime()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(Span<LuaTable>)>("ReadTables", => ReadTables);
			tinker.AddMethod<function int32(Span<Span<LuaTable>>)>("ReadNestedTables", (values) => ReadTables(values[0]));
			if (lua.DoString("""
				local value = {value = 7}
				weak = setmetatable({value}, {__mode = 'v'})
				assert(ReadTables({value}) == 7)
				assert(ReadNestedTables({{value}}) == 7)
				value = nil
				collectgarbage('collect')
				assert(weak[1] == nil)
				values = {{value = 9}}
				weak[1] = values[1]
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			{
				let result = tinker.GetSpan!<LuaTable>("values");
				Test.Assert(result case .Ok);
				if (lua.DoString("values = nil; collectgarbage('collect')"))
					Test.FatalError(lua.ToString(-1, .. scope .()));
				Test.Assert(ReadTables(result.Get()) == 9);
			}
			if (lua.DoString("collectgarbage('collect'); assert(weak[1] == nil)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestInputSpanConversion()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddEnum<Choice>();
			tinker.AddMethod<function int32(Span<int32>)>("Fingerprint", => Fingerprint);
			tinker.AddMethod<function int32(Span<int32>)>("Length", (values) => (int32)values.Length);
			tinker.AddMethod<function (Choice, Choice)(Span<Choice>)>("EnumPair", (values) => (values[0], values[1]));
			tinker.AddMethod<function (float, float)(Span<float>)>("FloatPair", (values) => (values[0], values[1]));
			tinker.AddMethod<function (String, String)(Span<String>)>("StringPair", (values) => (values[0], values[1]));
			tinker.AddMethod<function String(Span<String>)>("StringFirst", (values) => values[0]);
			tinker.AddMethod<function void(Span<int32>)>("Modify", (values) => { values[0] = 99; });
			if (lua.DoString("""
				assert(Fingerprint({[3]=3, [1]=4, [2]=1}) == 413)
				assert(Length({}) == 0)
				local a, b = EnumPair({Choice.One, Choice.Two})
				assert(a == Choice.One and b == Choice.Two)
				a, b = FloatPair({1.5, 2.5})
				assert(a == 1.5 and b == 2.5)
				a, b = StringPair({"alpha", "beta"})
				assert(a == "alpha" and b == "beta")
				assert(StringFirst({"a" .. string.char(0) .. "b"}) == "a" .. string.char(0) .. "b")
				assert(StringFirst({1}) == "1")
				assert(Fingerprint({"4", "1", "3"}) == 413)
				local values = {4, 1, 3}
				Modify(values)
				assert(values[1] == 4)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestInputSpanOverloadSelection()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<SpanOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestSpan.SpanOverloads
				assert(api.Select({"alpha"}) == 11)
				assert(api.Select({4}) == 21)
				assert(api.Numeric({1}) == 32)
				assert(api.Numeric({2147483648}) == 132)
				assert(api.PreferInt({1}) == 32)
				assert(api.PreferInt({1.5}) == 132)
				local ok, err = pcall(function() api.Select({}) end)
				assert(not ok and err:find("ambiguous span overload at argument 1", 1, true), tostring(err))
				assert(not pcall(function() api.OtherNumeric({1}) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestSpanOverloadsWithOrdinaryFallback()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<SpanOverloads>();
			if (lua.DoString("""
				local api = LuaTinker.Tests.TestSpan.SpanOverloads
				assert(api.WithFallback({"alpha"}) == 3)
				assert(api.WithFallback({4}) == 4)
				assert(api.WithFallback("text") == 1)
				assert(api.WithFallback(true) == 2)
				assert(not pcall(function() api.WithFallback({}) end))
				assert(not pcall(function() api.WithFallback({true}) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestInputSpanRejectsInvalidSequences()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(Span<int32>)>("Fingerprint", => Fingerprint);
			if (lua.DoString("""
				local ok, err = pcall(function() Fingerprint({[1]=1, [3]=3}) end)
				assert(not ok and err:find("missing element 2", 1, true), tostring(err))
				assert(not pcall(function() Fingerprint({[2147483647]=1}) end))
				assert(not pcall(function() Fingerprint({[2147483648]=1}) end))
				assert(not pcall(function() Fingerprint({[0]=1}) end))
				assert(not pcall(function() Fingerprint({[-1]=1}) end))
				assert(not pcall(function() Fingerprint({[1.5]=1}) end))
				assert(not pcall(function() Fingerprint({label=1}) end))
				assert(not pcall(function() Fingerprint(setmetatable({[1]=1, [3]=3}, {
				    __len = function() return 3 end,
				    __index = function() return 7 end
				})) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestInputSpanRejectsInvalidElements()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(Span<uint8>)>("Narrow", (values) => values[0]);
			tinker.AddMethod<function float(Span<float>)>("FloatFirst", (values) => values[0]);
			tinker.AddMethod<function String(Span<String>)>("StringFirst", (values) => values[0]);
			if (lua.DoString("""
				assert(not pcall(function() Narrow({256}) end))
				assert(not pcall(function() Narrow({1, "bad"}) end))
				assert(not pcall(function() Narrow({{}}) end))
				assert(not pcall(function() Narrow({int32.cast(1)}) end))
				assert(not pcall(function() Narrow(nullptr.int32) end))
				assert(not pcall(function() Narrow(7) end))
				assert(not pcall(function() StringFirst({true}) end))
				assert(not pcall(function() FloatFirst({1e40}) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestSpanTablesDoNotFallBackToObject()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<SpanTarget>();
			let target = scope SpanTarget();
			tinker.SetValue("target", target);
			if (lua.DoString("""
				assert(not pcall(function() target:Reserve({label="table"}) end))
				assert(not pcall(function() target:Pair({"alpha"}, {[1]=1, [3]=3}) end))
				assert(target.Calls == 0)
				assert(target:Reserve({4, 1, 3}) == 413)
				assert(target.Calls == 1)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestInputSpanBindingEntryPoints()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<Reflected>();
			tinker.AddClass<Direct>();
			tinker.AddClassCtor<Direct, Span<int32>>();
			tinker.AddClassVar<Direct, const "Value">();
			tinker.AddMethod<delegate int32(Span<int32>)>("DelegateSpan", new (values) => Fingerprint(values));
			if (lua.DoString("""
				assert(Reflected({4, 1}).Value == 41)
				assert(Direct({4, 1}).Value == 41)
				assert(Reflected({4, 1}):Read({1, 3}) == 13)
				assert(DelegateSpan({4, 1}) == 41)
				assert(not pcall(function() Direct({[1]=4, [3]=1}) end))
				assert(not pcall(function() Reflected({[1]=4, [3]=1}) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestGetSpanConversionAndLifetime()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			if (lua.DoString("""
				ordered = {4, 1, 3}
				words = {string.rep("alpha", 20), "b" .. string.char(0) .. "c"}
				empty = {}
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			let orderedResult = tinker.GetSpan!<int32>("ordered");
			Test.Assert((orderedResult case .Ok(let ordered)) && Fingerprint(ordered) == 413);
			let wordsResult = tinker.GetSpan!<String>("words");
			String expectedWord = scope .();
			for (int i < 20)
				expectedWord.Append("alpha");
			Test.Assert((wordsResult case .Ok(let words)) && words.Length == 2 && words[0] == expectedWord && words[1] == "b\0c");
			Test.Assert((tinker.GetSpan!<int32>("empty") case .Ok(let empty)) && empty.Length == 0);
			if (lua.DoString("ordered = nil; words = nil; collectgarbage('collect')"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert((orderedResult case .Ok(let retained)) && Fingerprint(retained) == 413);
			Test.Assert((wordsResult case .Ok(let retainedWords)) && retainedWords[0] == expectedWord && retainedWords[1] == "b\0c");
		}

		[Test]
		public static void TestGetSpanFailuresRestoreStack()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			if (lua.DoString("""
				sparse = {[1]=4, [3]=3}
				wrong_element = {4, "bad"}
				not_a_table = 7
				hint = nullptr.int32
				valid = {4, 1, 3}
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(tinker.GetSpan!<int32>("sparse") case .Err);
			Test.Assert(lua.GetTop() == 0);
			Test.Assert(tinker.GetSpan!<int32>("wrong_element") case .Err);
			Test.Assert(lua.GetTop() == 0);
			Test.Assert(tinker.GetSpan!<int32>("not_a_table") case .Err);
			Test.Assert(lua.GetTop() == 0);
			Test.Assert(tinker.GetSpan!<int32>("missing") case .Err);
			Test.Assert(lua.GetTop() == 0);
			Test.Assert(tinker.GetSpan!<int32>("hint") case .Err);
			Test.Assert((tinker.GetSpan!<int32>("valid") case .Ok(let recovered)) && Fingerprint(recovered) == 413);
			tinker.AddMethod<delegate bool()>("ReadSparse", new () => tinker.GetSpan!<int32>("sparse") case .Err);
			if (lua.DoString("assert(not pcall(ReadSparse))"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestBorrowedSpanBindingsRemainSupported()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			int32[3] values = .(4, 1, 3);
			Span<int32> borrowed = .(&values[0], values.Count);
			tinker.SetValue("borrowed", ref borrowed);
			Test.Assert((tinker.GetSpan!<int32>("borrowed") case .Ok(let result)) && result.Ptr == borrowed.Ptr && result.Length == borrowed.Length);
			bool[1] booleans = .(true);
			Span<bool> borrowedBool = .(&booleans[0], booleans.Count);
			tinker.SetValue("borrowedBool", ref borrowedBool);
			tinker.AddMethod<function int32(Span<int32>)>("Fingerprint", => Fingerprint);
			tinker.AddMethod<function bool(Span<bool>)>("ReadBool", (values) => values[0]);
			tinker.AutoTinkClass<SpanOverloads>();
			if (lua.DoString("""
				assert(Fingerprint(borrowed) == 413)
				assert(ReadBool(borrowedBool))
				assert(LuaTinker.Tests.TestSpan.SpanOverloads.Select(borrowed) == 23)
				assert(LuaTinker.Tests.TestSpan.SpanOverloads.Elements(borrowedBool) == 2)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}
	}
}
