using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestEnum
	{
		static StringSplitOptions GetSSO()
		{
			return .RemoveEmptyEntries;
		}

		static void SetSSO(StringSplitOptions sso)
		{
			Test.Assert(sso == .None);
		}

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			tinker.AddEnum<StringSplitOptions>();
			tinker.AddMethod("GetSSO", (function StringSplitOptions()) => GetSSO);
			tinker.AddMethod("SetSSO", (function void(StringSplitOptions)) => SetSSO);

			if (lua.DoString(
				@"""
				assert(GetSSO() == StringSplitOptions.RemoveEmptyEntries)
				assert(GetSSO() == 1)
				SetSSO(StringSplitOptions.None)
				SetSSO(0)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}

		[Test]
		public static void TestTypedEnumViews()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddEnum<TestNumericArguments.SignedChoice>("NumericChoice");
			tinker.AddEnum<TestNumericArguments.SignedChoice>("TypedChoice", true);
			tinker.AddNamespace("Choices");
			tinker.AddNamespaceEnum<TestNumericArguments.UnsignedChoice>("Choices", "NumericChoice");
			tinker.AddNamespaceEnum<TestNumericArguments.UnsignedChoice>("Choices", "TypedChoice", true);
			tinker.AutoTinkClass<TestNumericArguments.NumericOverloads>();

			if (lua.DoString(
				"""
				local api = LuaTinker.Tests.TestNumericArguments.NumericOverloads
				assert(api.Mixed(TypedChoice.One) == 101)
				assert(api.Mixed(NumericChoice.cast(NumericChoice.One)) == 101)
				assert(api.Mixed(int32.cast(NumericChoice.One)) == 32)
				assert(api.PickEnum(Choices.TypedChoice.One) == 2)
				assert(not pcall(function() api.Mixed(NumericChoice.One) end))
				assert(not pcall(function() api.PickEnum(Choices.NumericChoice.One) end))
				"""
			))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestNamespace()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			tinker.AddNamespace("System");
			tinker.AddNamespaceEnum<StringSplitOptions>("System");
			tinker.AddMethod("GetSSO", (function StringSplitOptions()) => GetSSO);
			tinker.AddMethod("SetSSO", (function void(StringSplitOptions)) => SetSSO);

			if (lua.DoString(
				@"""
				assert(GetSSO() == System.StringSplitOptions.RemoveEmptyEntries)
				assert(GetSSO() == 1)
				SetSSO(System.StringSplitOptions.None)
				SetSSO(0)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}
