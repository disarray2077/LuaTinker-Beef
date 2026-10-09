using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestOwnedClasses
	{
		public class AppendBuffer : IDisposable
		{
			public static int32 Disposed;
			public static int32 Destroyed;
			public static int32 DisposedFingerprint;
			public static int32 DestroyedFingerprint;

			private int32* mData;
			private int mLength;

			[AllowAppend]
			public this(params Span<int32> values)
			{
				let data = append int32[values.Length]*(?);
				mLength = values.Length;
				mData = data;
				for (let value in values)
					mData[@value.Index] = value;
			}

			public int32 this[int index]
			{
				get => mData[index];
				set => mData[index] = value;
			}

			public void Add(int index, int32 amount)
			{
				mData[index] += amount;
			}

			public int32 Fingerprint()
			{
				int32 result = 0;
				for (int i < mLength)
					result = result * 10 + mData[i];
				return result;
			}

			public void Dispose()
			{
				Disposed++;
				DisposedFingerprint += Fingerprint();
			}

			public ~this()
			{
				Destroyed++;
				DestroyedFingerprint += Fingerprint();
			}
		}

		static void ResetLifetime()
		{
			AppendBuffer.Disposed = 0;
			AppendBuffer.Destroyed = 0;
			AppendBuffer.DisposedFingerprint = 0;
			AppendBuffer.DestroyedFingerprint = 0;
		}

		[Test]
		public static void TestAppendClassLifetime()
		{
			for (int mode < 2)
			{
				ResetLifetime();
				{
					let lua = scope Lua(true);
					let tinker = scope LuaTinker(lua);
					if (mode == 0)
					{
						tinker.AddClass<AppendBuffer>();
						tinker.AddClassCtor<AppendBuffer, (int32, int32, int32)>();
						tinker.AddClassIndexer<AppendBuffer, int>();
						tinker.AddClassMethod<AppendBuffer, function void(AppendBuffer this, int, int32)>("Add", => AppendBuffer.Add);
						tinker.AddClassMethod<AppendBuffer, function int32(AppendBuffer this)>("Fingerprint", => AppendBuffer.Fingerprint);
					}
					else
						tinker.AutoTinkClass<AppendBuffer>();

					if (lua.DoString("assert(not pcall(function() AppendBuffer(1,2,'bad') end)); held = AppendBuffer(1,2,3)"))
						Test.FatalError(lua.ToString(-1, .. scope .()));

					if (lua.DoString(
						"""
						held:Add(1,5)
						assert(held[1] == 7)
						held[0] = 8
						collectgarbage('collect')
						assert(held:Fingerprint() == 873)
						"""
					))
						Test.FatalError(lua.ToString(-1, .. scope .()));
					Test.Assert(AppendBuffer.Disposed == 0 && AppendBuffer.Destroyed == 0);

					if (lua.DoString("held = nil; collectgarbage('collect'); collectgarbage('collect')"))
						Test.FatalError(lua.ToString(-1, .. scope .()));
					Test.Assert(AppendBuffer.Disposed == 1 && AppendBuffer.Destroyed == 1);
					Test.Assert(AppendBuffer.DisposedFingerprint == 873 && AppendBuffer.DestroyedFingerprint == 873);

					if (lua.DoString("pending = AppendBuffer(4,5,6)"))
						Test.FatalError(lua.ToString(-1, .. scope .()));
				}
				Test.Assert(AppendBuffer.Disposed == 2 && AppendBuffer.Destroyed == 2);
				Test.Assert(AppendBuffer.DisposedFingerprint == 1329 && AppendBuffer.DestroyedFingerprint == 1329);
			}
		}

		[Test]
		public static void TestBorrowedAppendClassLifetime()
		{
			ResetLifetime();
			{
				let original = new AppendBuffer(4,5,6);
				defer { delete original; }
				{
					let lua = scope Lua(true);
					let tinker = scope LuaTinker(lua);
					tinker.AutoTinkClass<AppendBuffer>();
					tinker.SetValue("borrowed", original);
					Test.Assert((tinker.GetValue<AppendBuffer>("borrowed") case .Ok(let recovered)) && recovered == original);

					if (lua.DoString(
						"""
						borrowed[0] = 9
						borrowed:Add(1,2)
						assert(borrowed:Fingerprint() == 976)
						borrowed = nil
						collectgarbage('collect')
						collectgarbage('collect')
						"""
					))
						Test.FatalError(lua.ToString(-1, .. scope .()));
					Test.Assert(AppendBuffer.Disposed == 0 && AppendBuffer.Destroyed == 0);
					Test.Assert(original.Fingerprint() == 976);
					tinker.SetValue("pending", original);
				}
				Test.Assert(AppendBuffer.Disposed == 0 && AppendBuffer.Destroyed == 0);
				Test.Assert(original.Fingerprint() == 976);
			}
			Test.Assert(AppendBuffer.Disposed == 0 && AppendBuffer.Destroyed == 1);
			Test.Assert(AppendBuffer.DestroyedFingerprint == 976);
		}
	}
}
