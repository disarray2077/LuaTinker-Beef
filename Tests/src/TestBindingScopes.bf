using System;
using KeraLua;

namespace LuaTinker.Tests
{
	class TestBindingScopes
	{
		public enum Choice { One = 1 }

		public class Value
		{
			public int32 Number;
			public this(int32 value) { Number = value; }
			public int32 Double() => Number * 2;
			public int32 Property { get => Number; set => Number = value; }
			public int32 ReadChoice(Choice choice) => (int32)choice;
		}

		public class StaticValues
		{
			public static int32 Counter;
			public static int32 Compute(int32 value) => value + 4;
			public int32 Read() => 5;
		}

		[Test]
		public static void TestNamespaceMethodsAndNesting()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			int32 counter = 7;
			StaticValues.Counter = 5;
			using (let ns = tinker.BeginNamespace("Bindings"))
			{
				ns.AddMethod<function int32(int32)>("Twice", (value) => value * 2);
				ns.AddMethod<delegate int32(int32)>("Triple", new (value) => value * 3);
				ns.AddEnum<Choice>();
				ns.AddVar<int32>("reference", ref counter);
				ns.AddMethod<function int32(int32*)>("ReadReference", (value) => *value);
				ns.AddMethod<StaticValues, const "Compute">();
				ns.AddVar<StaticValues, const "Counter">();
				using (let nested = ns.BeginNamespace("Nested"))
					nested.AddVar<int32>("constant", 42);
				ns.AddVar<int32>("afterNested", 13);
			}
			counter = 9;
			if (lua.DoString("""
				assert(Bindings.Twice(21) == 42 and Bindings.Triple(7) == 21)
				assert(Bindings.Choice.One == 1)
				assert(Bindings.ReadReference(Bindings.reference) == 9)
				assert(Bindings.Compute(3) == 7 and Bindings.Nested.constant == 42)
				assert(Bindings.afterNested == 13)
				Bindings.Counter = 11
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(StaticValues.Counter == 11);
		}

		[Test]
		public static void TestClassBindings()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			using (let ns = tinker.BeginNamespace("Bindings"))
			using (let cls = ns.BeginClass<Value>("Number"))
			{
				cls.AddCtor<int32>();
				cls.AddVar<const "Number">();
				cls.AddMethod<const "Double">();
				cls.AddMethod<function int32(Value, int32)>("Add", (value, amount) => value.Number + amount);
				cls.AddProperty<const "Property">();
				cls.AddProperty<int32>("ReadOnly", (value) => value.Number + 1, null);
			}
			if (lua.DoString("""
				local value = Bindings.Number(7)
				assert(value:Double() == 14 and value:Add(3) == 10)
				value.Number = 9
				assert(value.Number == 9)
				value.Property = 11
				assert(value.Number == 11 and value.Property == 11)
				assert(value.ReadOnly == 12)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestRootClassScope()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			using (let text = tinker.BeginClass<String>("Text"))
			{
				text.AddCtor();
				text.AddMethod<function void(String, String)>("Append", (instance, value) => instance.Append(value));
				text.AddProperty<const "Length">();
			}
			if (lua.DoString("local text = Text(); text:Append('hello'); assert(text.Length == 5)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestScopedStaticAutoTink()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			using (let ns = tinker.BeginNamespace("Bindings"))
			{
				ns.AutoTinkClass<StaticValues>(.Shallow);
				using (let flat = ns.BeginNamespace("Flat"))
					flat.AutoTinkClass<StaticValues>(.Deep, .Inline);
			}
			if (lua.DoString("""
				assert(Bindings.StaticValues.Compute(3) == 7)
				assert(Bindings.Compute == nil)
				assert(Bindings.Flat.Compute(3) == 7)
				assert(Bindings.Flat.StaticValues == nil)
				assert(Bindings.Flat.Read == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestScopedAutoTink()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			using (let ns = tinker.BeginNamespace("Bindings"))
				ns.AutoTinkClass<Value, ?>(.Deep, .IncludeEnums);
			if (lua.DoString("assert(Bindings.Value(7):ReadChoice(Bindings.Choice.One) == 1)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}
	}
}
