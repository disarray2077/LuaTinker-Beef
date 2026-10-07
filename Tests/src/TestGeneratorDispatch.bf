using System;
using KeraLua;

namespace LuaTinker.Tests
{
	class TestGeneratorDispatch
	{
		[Reflect(.All)]
		class Target
		{
			public int Value = 10;
			public static int Numeric(int32 value) => 1;
			public static int Numeric(double value) => 2;
			public static int FloatingFirst(double value) => 2;
			public static int FloatingFirst(int32 value) => 1;
			public static int CatchAll(Object value) => 3;
			public static int CatchAll(int32 value) => 4;
			public static int Specific(String value) => 5;
			public static int Specific(Object value) => 6;
			public static int Nullable(String value) => 7;
			public static int Nullable(Target value) => 8;
			public static int Zero() => 9;
			public static int Zero(int32 value) => value;
			public static int Zero(params Span<int> values) => 99;
			public static (int, StringView) Tuple() => (12, "tuple");
			public int Instance() => Value;
			public int Instance(int32 value) => Value + value;
			public static int Sum(params Span<int> values)
			{
				int result = 0;
				for (let value in values) result += value;
				return result;
			}
			public static int FixedSum(int first, params Span<int> values) => first + Sum(params values);
			public int InstanceSum(int first, params Span<int> values) => Value + FixedSum(first, params values);
		}

		[Test]
		public static void TestOverloadOrderAndDispatch()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<Target>();
			tinker.AddClassCtor<Target>();
			tinker.AddNamespaceMethod<Target, const "Numeric">("Target");
			tinker.AddNamespaceMethod<Target, const "FloatingFirst">("Target");
			tinker.AddNamespaceMethod<Target, const "CatchAll">("Target");
			tinker.AddNamespaceMethod<Target, const "Specific">("Target");
			tinker.AddNamespaceMethod<Target, const "Nullable">("Target");
			tinker.AddNamespaceMethod<Target, const "Zero">("Target");
			tinker.AddNamespaceMethod<Target, const "Tuple">("Target");
			tinker.AddMethod<delegate (int, StringView)()>("DelegateTuple", new () => Target.Tuple());
			tinker.AddClassMethod<Target, const "Instance">();
			if (lua.DoString("""
				assert(Target.Numeric(3) == 1)
				assert(not pcall(function() Target.Numeric(3.5) end))
				assert(Target.FloatingFirst(3) == 2)
				assert(Target.FloatingFirst(3.5) == 2)
				assert(Target.CatchAll(3) == 3)
				assert(Target.Specific('text') == 5)
				assert(Target.Specific(false) == 6)
				assert(Target.Nullable(nil) == 7)
				local target = Target()
				assert(Target.Nullable(target) == 8)
				assert(Target.Zero() == 9)
				assert(Target.Zero(11) == 11)
				assert(Target.Zero(1, 2) == 99)
				for _, tuple in ipairs({Target.Tuple, DelegateTuple}) do
				    local number, text = tuple()
				    assert(number == 12 and text == 'tuple')
				end
				assert(target:Instance() == 10)
				assert(target:Instance(11) == 21)
				assert(not pcall(function() Target.Numeric(false) end))
				assert(not pcall(function() Target.Zero(false) end))
				assert(not pcall(function() Target.Instance() end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestVariadicCallPaths()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<Target>();
			tinker.AddClassCtor<Target>();
			tinker.AddNamespaceMethod<Target, const "Sum">("Target");
			tinker.AddNamespaceMethod<Target, const "FixedSum">("Target");
			tinker.AddClassMethod<Target, const "InstanceSum">();
			tinker.AddMethod<function int(params Span<int>)>("BoundSum", => Target.Sum);
			tinker.AddMethod<function int(int, params Span<int>)>("BoundFixedSum", => Target.FixedSum);
			tinker.AddMethod<delegate int(params Span<int>)>("DelegateSum", new (values) => Target.Sum(params values));
			tinker.AddMethod<delegate int(int, params Span<int>)>("DelegateFixedSum", new (first, values) => Target.FixedSum(first, params values));
			if (lua.DoString("""
				for _, sum in ipairs({Target.Sum, BoundSum, DelegateSum}) do
				    assert(sum() == 0)
				    assert(sum(1, 2, 3) == 6)
				    assert(not pcall(function() sum(1, false) end))
				end
				for _, sum in ipairs({Target.FixedSum, BoundFixedSum, DelegateFixedSum}) do
				    assert(sum(10) == 10)
				    assert(sum(10, 1, 2) == 13)
				    assert(not pcall(function() sum() end))
				end
				local target = Target()
				assert(target:InstanceSum(5) == 15)
				assert(target:InstanceSum(5, 1, 2) == 18)
				assert(not pcall(function() target:InstanceSum() end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}
	}
}
