using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestNull
	{
		public class TestClass
		{
		}

		public struct TestStruct
		{
		}

		public static void TestMethod1(TestClass a)
		{
			Test.Assert(a == null);
		}

		public static void TestMethod2(TestStruct a)
		{
			Runtime.NotImplemented();
		}

		public static void TestMethod3(TestStruct* a)
		{
			Test.Assert(a == null);
		}

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.AddMethod<function void(TestClass)>("TestMethod1", => TestMethod1);
			tinker.AddMethod<function void(TestStruct)>("TestMethod2", => TestMethod2);
			tinker.AddMethod<function void(TestStruct*)>("TestMethod3", => TestMethod3);

			if (lua.DoString(
				@"""
				TestMethod1(nil)
				TestMethod3(nil)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			Test.Assert(lua.DoString(
				@"""
				TestMethod2(nil)
				"""
			));
		}
	}
}
