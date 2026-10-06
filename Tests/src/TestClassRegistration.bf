using System;
using System.Collections;
using KeraLua;

namespace LuaTinker.Tests
{
	class TestClassRegistration
	{
		class BaseValue
		{
			public int Value;
			public this(int value) { Value = value; }
			public int Read() => Value;
			public int Property { get => Value; set => Value = value; }
		}

		class DerivedValue : BaseValue
		{
			public this(int value) : base(value) {}
		}

		class UnregisteredClass {}

		[Test(ShouldFail=true)]
		public static void TestBindingBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassMethod<BaseValue, function int(BaseValue this)>("Read", => BaseValue.Read);
		}

		[Test(ShouldFail=true)]
		public static void TestDynamicMethodBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassMethod<BaseValue, const "Read">();
		}

		[Test(ShouldFail=true)]
		public static void TestConstructorBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassCtor<BaseValue, int>();
		}

		[Test(ShouldFail=true)]
		public static void TestDynamicConstructorBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassCtor<BaseValue>();
		}

		[Test(ShouldFail=true)]
		public static void TestFieldBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassVar<BaseValue, const "Value">();
		}

		[Test(ShouldFail=true)]
		public static void TestReflectedPropertyBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassProperty<BaseValue, const "Property">();
		}

		[Test(ShouldFail=true)]
		public static void TestFunctionPropertyBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassProperty<BaseValue, int>("Property", (self) => self.Value, (self, value) => self.Value = value);
		}

		[Test(ShouldFail=true)]
		public static void TestThisFunctionPropertyBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassProperty<BaseValue, int>("Property", (function int(BaseValue this)) => BaseValue.Read, (function void(BaseValue this, int))null);
		}

		[Test(ShouldFail=true)]
		public static void TestDelegatePropertyBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			delegate int(BaseValue) getter = new (self) => self.Value;
			defer delete getter;
			tinker.AddClassProperty<BaseValue, int, delegate int(BaseValue), delegate void(BaseValue, int)>("Property", getter, null);
		}

		[Test(ShouldFail=true)]
		public static void TestIndexerBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassIndexer<List<int>, int>();
		}

		[Test(ShouldFail=true)]
		public static void TestInheritanceBeforeClassRegistration()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClassParent<DerivedValue, BaseValue>();
		}

		[Test(ShouldFail=true)]
		public static void TestUnregisteredParent()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<BaseValue>();
			tinker.AddClass<DerivedValue>();
			tinker.AddClassParent<DerivedValue, BaseValue>();
			tinker.AddClassParent<DerivedValue, UnregisteredClass>();
		}

		[Test(ShouldFail=true)]
		public static void TestUnregisteredChild()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<BaseValue>();
			tinker.AddClassParent<UnregisteredClass, BaseValue>();
		}

		[Test(ShouldFail=true)]
		public static void TestDuplicateClassName()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<BaseValue>("SharedName");
			tinker.AddClass<DerivedValue>("SharedName");
		}

		[Test(ShouldFail=true)]
		public static void TestDuplicateClassType()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<BaseValue>("SharedName");
			tinker.AddClass<BaseValue>("OtherName");
		}

		[Test(ShouldFail=true)]
		public static void TestDuplicateClassNameAfterGlobalRebinding()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<BaseValue>("SharedName");
			lua.PushNil();
			lua.SetGlobal("SharedName");
			tinker.AddClass<DerivedValue>("SharedName");
		}

	}
}
