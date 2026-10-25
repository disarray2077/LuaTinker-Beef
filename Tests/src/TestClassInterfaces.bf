using System;
using KeraLua;
using LuaTinker.StackHelpers;

namespace LuaTinker.Tests
{
	class TestClassInterfaces
	{
		interface IReadable { int Read(); }

		class Value : IReadable
		{
			private int mValue;
			public this(int value) { mValue = value; }
			public int Read() => mValue;
		}

		class Derived : Value
		{
			public this(int value) : base(value) {}
		}

		class Unrelated {}
		struct ValueStruct : IReadable { public int Read() => 1; }

		class Consumer
		{
			private IReadable mValue;
			public this(IReadable value) { mValue = value; }
			public int Read() => mValue.Read();
		}

		[Test]
		public static void TestInterfaceArguments()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<Value>(.Shallow);
			tinker.AutoTinkClass<Derived>(.Shallow);
			tinker.AddClassCtor<Derived>(.Heap);
			tinker.AutoTinkClass<Consumer>(.Shallow);
			tinker.AddMethod<function int(IReadable)>("Read", (value) => value == null ? -1 : value.Read());
			let borrowed = scope Derived(9);
			let unrelated = scope Unrelated();
			tinker.SetValue<Object>("borrowed", borrowed);
			tinker.SetValue("unrelated", unrelated);
			tinker.SetValue("valueStruct", ValueStruct());
			if (lua.DoString("""
				local value = Value(7)
				local derived = Derived(8)
				assert(Read(value) == 7 and Read(derived) == 8 and Read(borrowed) == 9)
				assert(Consumer(value):Read() == 7)
				assert(Read(nil) == -1)
				assert(not pcall(function() Read(unrelated) end))
				assert(not pcall(function() Read(valueStruct) end))
				assert(not pcall(function() Consumer(unrelated) end))
				assert(not pcall(function() Read({}) end))
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestHostInterfaceConversions()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			let instance = scope Derived(7);
			Value reference = instance;
			tinker.SetValue("reference", ref reference);
			tinker.SetValue("pointer", &reference);
			Test.Assert(tinker.GetValue<IReadable>("reference").Get() == instance);
			Test.Assert(tinker.GetValue<IReadable>("pointer").Get() == instance);
			lua.GetGlobal("reference");
			Test.Assert(StackHelper.Pop<IReadable>(lua, -1) == instance);
			lua.Pop(1);
			lua.PushNil();
			Test.Assert(StackHelper.Pop<IReadable>(lua, -1) == null);
			lua.Pop(1);
			let unrelated = scope Unrelated();
			StackHelper.Push(lua, unrelated);
			Test.Assert(StackHelper.Pop<IReadable>(lua, -1) == null);
			Test.Assert(lua.TinkerState.HasError && lua.GetTop() == 1);
			lua.Pop(1);
			tinker.SetValue("unrelated", unrelated);
			Test.Assert(tinker.GetValue<IReadable>("unrelated") case .Err);
		}
	}
}
