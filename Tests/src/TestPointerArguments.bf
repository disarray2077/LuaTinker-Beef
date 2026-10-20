using System;
using KeraLua;

namespace LuaTinker.Tests
{
	class TestPointerArguments
	{
		public struct OpaqueHandle;

		public static class PointerAPI
		{
			public static int32 Select(void* value) => 200 + *(uint8*)value;
			public static int32 Select(uint8* value) => 100 + *value;
			public static int32 Select(uint32* value) => 300 + (int32)*value;
			public static int32 ReadByte(uint8* value) => *value;
			public static int32 ReadInt32(int32* value) => *value;
			public static float ReadFloat(float* value) => *value;
			public static int32 Sum(params Span<int32*> values)
			{
				int32 sum = 0;
				for (let value in values)
					sum += *value;
				return sum;
			}
			public static int32 ReadVoid(void* value) => *(uint8*)value;
			public static char8* ErrorText() => "native error";
			public static int32 CStringLength(char8* text) => text == null ? -1 : (int32)StringView(text).Length;
			public static int32 CStringLengths(params Span<char8*> texts)
			{
				int32 length = 0;
				for (let text in texts)
					length += CStringLength(text);
				return length;
			}
		}

		public struct CStringConstruction
		{
			public int32 Length;
			public this(char8* text) { Length = PointerAPI.CStringLength(text); }
		}

		public struct NumericPointerConstruction
		{
			public int32 Value;
			public this(int32* value) { Value = *value; }
			public int32 Add(int32* value) => Value + *value;
		}

		[Test]
		public static void TestNumericPointerArguments()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<PointerAPI>(.Shallow);
			tinker.AutoTinkClass<NumericPointerConstruction>(.Shallow);
			tinker.AddMethod<function uint32(uint32*)>("ReadWord", (value) => *value);
			tinker.AddMethod<delegate float(float*)>("ReadFloat", new (value) => *value);
			if (lua.DoString("""
				local api = PointerAPI
				assert(api.ReadByte(37) == 37)
				assert(api.Select(37) == 137)
				assert(api.Select(256) == 556)
				assert(api.ReadInt32(-9) == -9)
				assert(api.ReadFloat(1.5) == 1.5)
				assert(ReadWord(4294967295) == 4294967295)
				assert(ReadFloat(2.5) == 2.5)
				assert(NumericPointerConstruction(11):Add(7) == 18)
				assert(api.Sum(2, 5, 11) == 18)
				assert(api.Sum() == 0)
				assert(not pcall(function() api.ReadByte(256) end))
				assert(not pcall(function() ReadWord(-1) end))
				assert(not pcall(function() api.ReadInt32(1.5) end))
				assert(not pcall(function() ReadFloat(1e40) end))
				assert(not pcall(function() api.ReadVoid(7) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestOpaquePointerArguments()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function bool(OpaqueHandle*)>("IsNullHandle", (value) => value == null);
			if (lua.DoString("""
				assert(IsNullHandle(nil))
				assert(IsNullHandle(nullptr.void))
				assert(not pcall(function() IsNullHandle(7) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNumericPointerTemporaryAndCellWrites()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(int32*, int32*)>("WritePointers", (left, right) =>
				{
					*left += 10;
					*right += 20;
					return *left + *right;
				});
			tinker.AddMethod<function void(ref int32)>("WriteRef", (value) => { value = 42; });
			tinker.AddMethod<function void(out int32)>("WriteOut", (value) => { value = 7; });
			if (lua.DoString("""
				number = 3
				assert(WritePointers(number, 5) == 38)
				local cell = ref.int32(4)
				assert(WritePointers(cell, 5) == 39)
				assert(cell.value == 14)
				WriteRef(cell)
				assert(cell.value == 42)
				WriteOut(cell)
				assert(cell.value == 7)
				assert(not pcall(function() WriteRef(3) end))
				assert(not pcall(function() WriteOut(3) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(tinker.GetValue<int32*>("number") case .Err);
		}

		[Test]
		public static void TestBorrowedPointerDispatchAndVoidFallback()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<PointerAPI>(.Shallow);
			tinker.AutoTinkClass<System.Collections.List<uint8>>(.Shallow, name: "UInt8List");
			tinker.AddMethod<function int32(void*)>("DirectVoid", (value) => *(uint8*)value);
			tinker.AddMethod<function void*(void*)>("EchoVoid", (value) => value);
			uint8 byte = 37;
			uint32 word = 9;
			tinker.SetValue("bytePointer", &byte);
			tinker.SetValue("wordPointer", &word);
			tinker.SetValue("byteReference", ref byte);
			tinker.SetValue("voidPointer", (void*)&byte);
			if (lua.DoString("""
				local api = PointerAPI
				assert(api.Select(bytePointer) == 137)
				assert(api.Select(byteReference) == 137)
				assert(api.Select(wordPointer) == 309)
				assert(api.Select(voidPointer) == 237)
				local bytes = UInt8List()
				bytes:Add(17)
				assert(api.Select(bytes.Ptr) == 117)
				assert(api.ReadVoid(bytes.Ptr) == 17)
				assert(api.ReadVoid(bytePointer) == 37)
				assert(DirectVoid(byteReference) == 37)
				assert(api.ReadVoid(EchoVoid(bytePointer)) == 37)
				assert(not pcall(function() api.ReadByte(wordPointer) end))
				assert(not pcall(function() api.ReadByte(voidPointer) end))
				assert(not pcall(function() api.ReadVoid({}) end))
				assert(not pcall(function() api.ReadVoid(bytes) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));

			Test.Assert(tinker.GetValue<void*>("bytePointer").Get() == &byte);
			Test.Assert(tinker.GetValue<void*>("voidPointer").Get() == &byte);
			Test.Assert(tinker.GetValue<uint8*>("voidPointer") case .Err);
			Test.Assert(tinker.GetValue<uint32*>("bytePointer") case .Err);
		}

		[Test]
		public static void TestOwnedCellsAsVoidPointers()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddMethod<function int32(void*)>("ReadCell", (value) => *(int32*)value);
			if (lua.DoString("cell = ref.int32(7); assert(ReadCell(cell) == 7)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			let pointer = tinker.GetValue<void*>("cell").Get();
			*(int32*)pointer = 11;
			if (lua.DoString("assert(cell.value == 11)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestCStringBindingArguments()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<PointerAPI>(.Shallow);
			tinker.AutoTinkClass<CStringConstruction>(.Shallow);
			tinker.AddMethod<function int32(char8*)>("DirectLength", (text) => text == null ? -1 : (int32)StringView(text).Length);
			tinker.AddMethod<delegate int32(char8*)>("DelegateLength", new (text) => text == null ? -1 : (int32)StringView(text).Length);
			if (lua.DoString("""
				local api = PointerAPI
				assert(api.CStringLength('window') == 6)
				assert(api.CStringLength('A\0B') == 1)
				assert(api.CStringLength(nil) == -1)
				assert(api.CStringLength(nullptr.void) == -1)
				assert(DirectLength('abc') == 3)
				assert(DelegateLength('abcd') == 4)
				assert(CStringConstruction('hello').Length == 5)
				assert(api.CStringLengths('ab', 'c') == 3)
				assert(not pcall(function() api.CStringLength(42) end))
				assert(not pcall(function() DirectLength(42) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestExplicitCStringConversion()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<PointerAPI>(.Shallow);
			if (lua.DoString("""
				local api = PointerAPI
				pointer = api.ErrorText()
				assert(string.from_cstr(pointer) == 'native error')
				assert(tostring(pointer) ~= 'native error')
				assert(api.CStringLength(pointer) == 12)
				assert(string.from_cstr(nil) == nil)
				assert(string.from_cstr(nullptr.void) == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(StringView(tinker.GetValue<char8*>("pointer").Get()) == "native error");
		}

		[Test]
		public static void TestCStringConversionRejectsInvalidValues()
		{
			let lua = scope Lua(true);
			scope LuaTinker(lua);
			if (lua.DoString("""
				assert(not pcall(function() string.from_cstr('native error') end))
				assert(not pcall(function() string.from_cstr(ref.uint32(7)) end))
				assert(not pcall(function() string.from_cstr(nullptr.int32) end))
				assert(not pcall(function() string.from_cstr() end))
				assert(not pcall(function() string.from_cstr(nil, nil) end))
				local foreign = assert(io.tmpfile())
				assert(not pcall(function() string.from_cstr(foreign) end))
				foreign:close()
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}
	}
}
