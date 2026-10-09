using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestOwnedValues
	{
		public static class CellAPI
		{
			public static void Bump(ref int32 value) { value += 4; }
			public static void Bump(ref uint32 value) { value += 2; }
			public static void Write(int32* value) { *value = 41; }
			public static void Write(uint32* value) { *value = 4000000000; }
			public static int32 Read(int32 value) => value;
		}

		[Test]
		public static void TestPrimitiveCellValues()
		{
			let lua = scope Lua(true);
			scope LuaTinker(lua);
			if (lua.DoString("""
				local signed = ref.int32(-7)
				local unsigned = ref.uint32(4294967295)
				assert(signed.value == -7 and unsigned.value == 4294967295)
				signed.value = -2147483648
				assert(signed.value == -2147483648)
				assert(not pcall(function() signed.value = 2147483648 end))
				assert(signed.value == -2147483648)
				assert(not pcall(function() unsigned.value = -1 end))
				assert(unsigned.value == 4294967295)
				assert(not pcall(function() signed.value = unsigned end))
				assert(not pcall(function() ref.int32(2147483648) end))
				assert(not pcall(function() ref.uint32(-1) end))
				assert(not pcall(function() ref.int32(1.5) end))
				assert(not pcall(function() ref.int32() end))
				assert(not pcall(function() ref.int32(1, 2) end))
				assert(not pcall(function() ref.int32('3') end))
				assert(not pcall(function() ref.int32(int32.cast(7)) end))
				assert(not pcall(function() ref.uint32(uint32.cast(7)) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestPrimitiveCellReferences()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<CellAPI>();
			tinker.AddMethod<function void(ref int32)>("DirectBump", (value) => { value++; });
			tinker.AddMethod<delegate void(ref int32)>("DelegateBump", new (value) => { value++; });
			if (lua.DoString("""
				local CellAPI = LuaTinker.Tests.TestOwnedValues.CellAPI
				local signed = ref.int32(-4)
				local unsigned = ref.uint32(3)
				CellAPI.Bump(signed)
				CellAPI.Bump(unsigned)
				assert(signed.value == 0 and unsigned.value == 5)
				DirectBump(signed)
				DelegateBump(signed)
				assert(signed.value == 2)
				assert(not pcall(function() DirectBump(unsigned) end))
				assert(not pcall(function() CellAPI.Bump(5) end))
				assert(not pcall(function() CellAPI.Read(signed) end))
				assert(CellAPI.Read(signed.value) == 2)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestPrimitiveCellPointers()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<CellAPI>();
			tinker.AddMethod<function void(int32*)>("DirectWrite", (value) => { *value += 1; });
			if (lua.DoString("""
				local CellAPI = LuaTinker.Tests.TestOwnedValues.CellAPI
				local signed = ref.int32(0)
				local unsigned = ref.uint32(0)
				CellAPI.Write(signed)
				CellAPI.Write(unsigned)
				assert(signed.value == 41 and unsigned.value == 4000000000)
				DirectWrite(signed)
				assert(signed.value == 42)
				assert(not pcall(function() DirectWrite(unsigned) end))
				assert(not pcall(function() CellAPI.Write({}) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestPrimitiveCellHostAccess()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			if (lua.DoString("signed = ref.int32(-7); unsigned = ref.uint32(4294967295)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));

			let signed = tinker.GetValue<int32*>("signed").Get();
			let unsigned = tinker.GetValue<uint32*>("unsigned").Get();
			Test.Assert(*signed == -7);
			Test.Assert(*unsigned == 4294967295);
			*signed = 41;
			*unsigned = 4000000000;

			if (lua.DoString("assert(signed.value == 41 and unsigned.value == 4000000000)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestPrimitiveCellLifetime()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<CellAPI>();
			if (lua.DoString("""
				local CellAPI = LuaTinker.Tests.TestOwnedValues.CellAPI
				do
					local value = ref.int32(7)
					held = value
				end
				collectgarbage('collect')
				CellAPI.Bump(held)
				assert(held.value == 11)
				held = nil
				collectgarbage('collect')
				pending = ref.uint32(9)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		public struct DisposableValue : IDisposable
		{
			public static int32 Disposed;
			public int32 Value;
			public int32* Heap;

			public this(int32 a, int32 b, int32 c, int32 d, int32 e)
			{
				Value = ((((a * 10) + b) * 10 + c) * 10 + d) * 10 + e;
				Heap = new int32();
				*Heap = 7;
			}

			public void Dispose() mut
			{
				delete Heap;
				Disposed++;
			}
		}

		[Test]
		public static void TestOwnedStructLifetime()
		{
			DisposableValue.Disposed = 0;
			for (int mode < 2)
			{
				{
					let lua = scope Lua(true);
					let tinker = scope LuaTinker(lua);
					tinker.AddClass<DisposableValue>();
					if (mode == 0)
						tinker.AddClassCtor<DisposableValue, (int32, int32, int32, int32, int32)>();
					else
						tinker.AddClassCtor<DisposableValue>();
					tinker.AddMethod<function int32(DisposableValue)>("ReadDisposable", (value) => value.Value + *value.Heap);
					tinker.AddMethod<function int32(DisposableValue*)>("BumpDisposablePointer", (value) =>
						{
							value.Value++;
							*value.Heap += 2;
							return value.Value + *value.Heap;
						});
					tinker.AddMethod<function int32(ref DisposableValue)>("BumpDisposableRef", (value) =>
						{
							value.Value++;
							return value.Value + *value.Heap;
						});

					if (lua.DoString("""
						local value = DisposableValue(1,2,3,4,5)
						assert(ReadDisposable(value) == 12352)
						assert(BumpDisposablePointer(value) == 12355)
						held = value
						"""))
						Test.FatalError(lua.ToString(-1, .. scope .()));
					if (lua.DoString("collectgarbage('collect'); assert(BumpDisposableRef(held) == 12356)"))
						Test.FatalError(lua.ToString(-1, .. scope .()));
					Test.Assert(DisposableValue.Disposed == mode * 2);

					if (lua.DoString("held = nil; collectgarbage('collect'); collectgarbage('collect')"))
						Test.FatalError(lua.ToString(-1, .. scope .()));
					Test.Assert(DisposableValue.Disposed == mode * 2 + 1);

					if (lua.DoString("pending = DisposableValue(5,4,3,2,1)"))
						Test.FatalError(lua.ToString(-1, .. scope .()));
				}
				Test.Assert(DisposableValue.Disposed == mode * 2 + 2);
			}
		}
	}
}
