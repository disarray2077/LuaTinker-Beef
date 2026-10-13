using System;
using KeraLua;

namespace LuaTinker.Tests;

class TestDefaultArguments
{
	enum Mode { First, Second }

	class Target
	{
		public int Value;
		public static int RuntimeValue = 7;
		public this(int value = 10) { Value = value; }
		public static int Multiply(int value, int multiplier = 3, bool enabled = true) => enabled ? value * multiplier : -1;
		public static StringView Text(StringView text = "fallback") => text;
		public static bool IsNull(String text = "fallback") => text == null;
		public static int Dynamic(int value = RuntimeValue) => value;
		public static int EnumDefault(Mode mode = .Second) => (int)mode;
		public int Add(int value = 4) => Value + value;
		public ref int Cell(int unused = 0) => ref Value;
		public static int Choose(int value, int multiplier = 3) => 1;
		public static int Choose(int value) => 2;
		public static int Sum(int first = 5, params Span<int> rest)
		{
			int total = first;
			for (let value in rest)
				total += value;
			return total;
		}
	}

	class OverloadedConstructor
	{
		public int Value;
		public this(int value, bool enabled = true) { Value = enabled ? value : -1; }
		public this(int value) { Value = value + 100; }
	}

	class Appended
	{
		private int* mValue;
		[AllowAppend]
		public this(int value = 17)
		{
			let data = append int[1]*(?);
			mValue = data;
			*mValue = value;
		}
		public int Read() => *mValue;
	}

	struct Value
	{
		public int Number;
		public this(int number, bool enabled = true) { Number = enabled ? number : -1; }
		public int Read() => Number;
	}

	public function int DefaultFunction(int value, int multiplier = 4);
	public delegate int DefaultDelegate(int value, int multiplier = 5);

	[Test]
	public static void TestReflectedDefaults()
	{
		let lua = scope Lua(true);
		LuaTinker tinker = scope .(lua);
		tinker.AddNamespace("Target");
		tinker.AddNamespaceMethod<Target, const "Multiply">("Target");
		tinker.AddNamespaceMethod<Target, const "Text">("Target");
		tinker.AddNamespaceMethod<Target, const "IsNull">("Target");
		tinker.AddNamespaceMethod<Target, const "Dynamic">("Target");
		tinker.AddNamespaceMethod<Target, const "EnumDefault">("Target");
		Target.RuntimeValue = 7;
		defer { Target.RuntimeValue = 7; }
		if (lua.DoString("""
			assert(Target.Multiply(2) == 6)
			assert(Target.Multiply(2, 4) == 8)
			assert(Target.Multiply(2, 4, false) == -1)
			assert(Target.Text() == 'fallback')
			assert(Target.Text('given') == 'given')
			assert(not Target.IsNull())
			assert(Target.IsNull(nil))
			assert(Target.Dynamic() == 7)
			assert(Target.EnumDefault() == 1)
			assert(not pcall(function() Target.Multiply(2, false) end))
			assert(not pcall(function() Target.Multiply(2, nil) end))
			assert(not pcall(function() Target.Multiply(2, 4, true, 5) end))
			local ok, err = pcall(function() Target.Multiply() end)
			assert(not ok and err:find("expected '1, 2 or 3' arguments but got '0'", 1, true), tostring(err))
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
		Target.RuntimeValue = 12;
		Test.Assert(tinker.Eval<int>("return Target.Dynamic()").Get() == 12);
	}

	[Test]
	public static void TestAutomaticDefaultsAndConstructors()
	{
		let lua = scope Lua(true);
		LuaTinker tinker = scope .(lua);
		tinker.AutoTinkClass<Target, const "Target">();
		tinker.AddMethod<function void(ref int)>("IncrementCell", (value) => { value++; });
		tinker.AutoTinkClass<OverloadedConstructor, const "OverloadedConstructor">();
		tinker.AddClass<Appended>("Appended");
		tinker.AddClassCtor<Appended>();
		tinker.AddClassMethod<Appended, const "Read">();
		tinker.AddClass<Value>("Value");
		tinker.AddClassCtor<Value>();
		tinker.AddClassMethod<Value, const "Read">();
		if (lua.DoString("""
			local target = Target()
			assert(target.Value == 10)
			assert(target:Add() == 14)
			assert(target:Add(2) == 12)
			assert(Target(20):Add() == 24)
			IncrementCell(target:Cell())
			assert(target.Value == 11)
			IncrementCell(target:Cell(0))
			assert(target.Value == 12)
			assert(OverloadedConstructor(8).Value == 108)
			assert(OverloadedConstructor(8, false).Value == -1)
			assert(Appended():Read() == 17)
			assert(Appended(9):Read() == 9)
			assert(Value(8):Read() == 8)
			assert(Value(8, false):Read() == -1)
			assert(not pcall(function() Target(false) end))
			assert(not pcall(function() Value() end))
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
		// A single static method with defaults also takes AutoTink's reflected path.
		let result = tinker.Eval<int>("return LuaTinker.Tests.TestDefaultArguments.Target.Multiply(2)");
		if (result case .Err(let error))
			Test.FatalError(scope String(error));
		Test.Assert(result.Get() == 6);
	}

	[Test]
	public static void TestDefaultOverloadsAndVariadics()
	{
		let lua = scope Lua(true);
		LuaTinker tinker = scope .(lua);
		tinker.AddNamespace("Target");
		tinker.AddNamespaceMethod<Target, const "Choose">("Target");
		tinker.AddNamespaceMethod<Target, const "Sum">("Target");
		if (lua.DoString("""
			assert(Target.Choose(2) == 2)
			assert(Target.Choose(2, 4) == 1)
			assert(Target.Sum() == 5)
			assert(Target.Sum(10) == 10)
			assert(Target.Sum(10, 1, 2) == 13)
			assert(not pcall(function() Target.Sum(false) end))
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
	}

	[Test]
	public static void TestNamedCallableDefaults()
	{
		let lua = scope Lua(true);
		LuaTinker tinker = scope .(lua);
		tinker.AddMethod<DefaultFunction>("Function", (value, multiplier) => value * multiplier);
		tinker.AddMethod<DefaultDelegate>("Delegate", new (value, multiplier) => value * multiplier);
		if (lua.DoString("""
			assert(Function(2) == 8)
			assert(Function(2, 6) == 12)
			assert(Delegate(2) == 10)
			assert(Delegate(2, 6) == 12)
			assert(not pcall(function() Function() end))
			assert(not pcall(function() Delegate(2, 6, 8) end))
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
	}
}
