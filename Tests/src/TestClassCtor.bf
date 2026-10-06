using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestClassCtor
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.AddClass<String>("StringBuilder");
			tinker.AddClassCtor<String, String>();
			tinker.AddClassMethod<String, function Result<void>(String this, StringView, params Span<Object>)>("AppendF", => String.AppendF);
			tinker.AddClassMethod<String, function String(String)>("str", (str) => str);

			if (lua.DoString(
				@"""
				str = StringBuilder("Hello ")
				str:AppendF("'{}'", "LuaTinker")
				assert(str:str() == "Hello 'LuaTinker'")
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}

		struct ConstructedDisposable : IDisposable
		{
			public static int DisposeCount;
			public int Value;
			public this(int value) { Value = value; }
			public void Dispose() { DisposeCount++; }
		}

		[Test]
		public static void TestFailedStructConstructionFinalization()
		{
			ConstructedDisposable.DisposeCount = 0;
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<ConstructedDisposable>();
			tinker.AddClassCtor<ConstructedDisposable, int>();
			tinker.AddClassVar<ConstructedDisposable, const "Value">();
			tinker.AddMethod<function int()>("DisposeCount", () => ConstructedDisposable.DisposeCount);
			if (lua.DoString(
				"""
				assert(not pcall(function() ConstructedDisposable('invalid') end))
				collectgarbage()
				assert(DisposeCount() == 0)
				instance = ConstructedDisposable(7)
				assert(instance.Value == 7)
				instance = nil
				collectgarbage()
				assert(DisposeCount() == 1)
				"""
			))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestFailedDynamicStructConstructionFinalization()
		{
			ConstructedDisposable.DisposeCount = 0;
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<ConstructedDisposable>();
			tinker.AddClassCtor<ConstructedDisposable>();
			tinker.AddClassVar<ConstructedDisposable, const "Value">();
			tinker.AddMethod<function int()>("DisposeCount", () => ConstructedDisposable.DisposeCount);
			if (lua.DoString(
				"""
				assert(not pcall(function() ConstructedDisposable('invalid') end))
				collectgarbage()
				assert(DisposeCount() == 0)
				instance = ConstructedDisposable(7)
				assert(instance.Value == 7)
				instance = nil
				collectgarbage()
				assert(DisposeCount() == 1)
				"""
			))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

	}
}
