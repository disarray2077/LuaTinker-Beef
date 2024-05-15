using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestClassInheritance
	{
		class MyBaseTest
		{
			public int a = 15;

			public int GetA() => a;
		}

		class MyTest : MyBaseTest
		{
			public int b = 14;

			public int GetB() => b;
		}

		class My2BaseBaseTest
		{
			public int a = 16;

			public int GetA() => a;
		}

		class My2BaseTest : My2BaseBaseTest
		{
			public int b = 15;

			public int GetB() => b;
		}

		class My2Test : My2BaseTest
		{
			public int c = 14;

			public int GetC() => c;
		}

		[Test]
		public static void TestClass()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			// Parent depth: 1

			tinker.AddClass<MyBaseTest>();
			tinker.AddClassCtor<MyBaseTest>();
			tinker.AddClassVar<MyBaseTest, const "a">();
			tinker.AddClassMethod<MyBaseTest, function int(MyBaseTest this)>("GetA", => MyBaseTest.GetA);

			tinker.AddClass<MyTest>();
			tinker.AddClassCtor<MyTest>();
			tinker.AddClassParent<MyTest, MyBaseTest>();
			tinker.AddClassVar<MyTest, const "b">();
			tinker.AddClassMethod<MyTest, function int(MyTest this)>("GetB", => MyTest.GetB);

			// Parent depth: 2

			tinker.AddClass<My2BaseBaseTest>();
			tinker.AddClassCtor<My2BaseBaseTest>();
			tinker.AddClassVar<My2BaseBaseTest, const "a">();
			tinker.AddClassMethod<My2BaseBaseTest, function int(My2BaseBaseTest this)>("GetA", => My2BaseBaseTest.GetA);

			tinker.AddClass<My2BaseTest>();
			tinker.AddClassCtor<My2BaseTest>();
			tinker.AddClassParent<My2BaseTest, My2BaseBaseTest>();
			tinker.AddClassVar<My2BaseTest, const "b">();
			tinker.AddClassMethod<My2BaseTest, function int(My2BaseTest this)>("GetB", => My2BaseTest.GetB);

			tinker.AddClass<My2Test>();
			tinker.AddClassCtor<My2Test>();
			tinker.AddClassParent<My2Test, My2BaseTest>();
			tinker.AddClassVar<My2Test, const "c">();
			tinker.AddClassMethod<My2Test, function int(My2Test this)>("GetC", => My2Test.GetC);

			if (lua.DoString(
				@"""
				test = MyTest()
				assert(test.a == 15)
				assert(test.b == 14)
				assert(test:GetA() == test.a)
				assert(test:GetB() == test.b)

				test2 = My2Test()
				assert(test2.a == 16)
				assert(test2.b == 15)
				assert(test2.c == 14)
				assert(test2:GetA() == test2.a)
				assert(test2:GetB() == test2.b)
				assert(test2:GetC() == test2.c)

				test2.a = 26
				assert(test2:GetA() == 26)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			// Calling MyTest method with Base instance shouldn't be allowed.
			Test.Assert(lua.DoString(
				@"""
				testBase = MyBaseTest()
				test = MyTest()
				assert(test.GetA(testBase) == test.a)
				assert(test.GetB(testBase) == test.b)
				"""
			));
		}

		struct MyBaseTestStruct
		{
			public int a = 15;

			public int GetA() => a;
		}

		struct MyTestStruct : MyBaseTestStruct
		{
			public int b = 14;

			public int GetB() => b;
		}

		[Test]
		public static void TestStruct()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.AddClass<MyBaseTestStruct>("MyBaseTest");
			tinker.AddClassCtor<MyBaseTestStruct>();
			tinker.AddClassVar<MyBaseTestStruct, const "a">();
			tinker.AddClassMethod<MyBaseTestStruct, function int(MyBaseTestStruct this)>("GetA", => MyBaseTestStruct.GetA);

			tinker.AddClass<MyTestStruct>("MyTest");
			tinker.AddClassCtor<MyTestStruct>();
			tinker.AddClassParent<MyTestStruct, MyBaseTestStruct>();
			tinker.AddClassVar<MyTestStruct, const "b">();
			tinker.AddClassMethod<MyTestStruct, function int(MyTestStruct this)>("GetB", => MyTestStruct.GetB);

			if (lua.DoString(
				@"""
				test = MyTest()
				assert(test.a == 15)
				assert(test.b == 14)
				assert(test:GetA() == test.a)
				assert(test:GetB() == test.b)

				test.a = 26
				assert(test:GetA() == 26)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
		}
	}
}
