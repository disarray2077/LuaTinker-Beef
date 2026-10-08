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

		[Reflect(.All)]
		public class VariadicConstruction
		{
			public int Value;
			public this(params Span<int> values)
			{
				for (let value in values)
					Value += value;
			}
		}

		[Test]
		public static void TestVariadicConstructorArguments()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<VariadicConstruction>();
			tinker.AddClassCtor<VariadicConstruction>();
			tinker.AddClassVar<VariadicConstruction, const "Value">();
			if (lua.DoString("""
				assert(VariadicConstruction().Value == 0)
				assert(VariadicConstruction(1, 2, 3).Value == 6)
				assert(not pcall(function() VariadicConstruction(1, 'bad') end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		struct ConstructedDisposable : IDisposable
		{
			public static int DisposeCount;
			public int Value;
			public this(int value) { Value = value; }
			public void Dispose() { DisposeCount++; }
		}

		[Test]
		public static void TestConstructorArgumentDiagnostics()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<ConstructedDisposable>();
			tinker.AddClassCtor<ConstructedDisposable>();
			if (lua.DoString("""
				local ok, err = pcall(function() ConstructedDisposable('invalid') end)
				assert(not ok and err:find("at argument 1 but got 'string'", 1, true), tostring(err))
				ok, err = pcall(function() ConstructedDisposable() end)
				assert(not ok and err:find("expected '1' arguments but got '0'", 1, true), tostring(err))
				ok, err = pcall(function() ConstructedDisposable(1, 2) end)
				assert(not ok and err:find("expected '1' arguments but got '2'", 1, true), tostring(err))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
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
