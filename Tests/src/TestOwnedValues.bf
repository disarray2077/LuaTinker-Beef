using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestOwnedValues
	{
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
