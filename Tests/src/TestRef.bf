using KeraLua;
using System;

namespace LuaTinker.Tests
{
	class TestRef
	{
		static void AddNum(int n)
		{
			mNum += n;
		}

		static void AddNum(int* n)
		{
			mNum += *n;
		}

		static void AddNum(ref int n)
		{
			mNum += n;
		}

		static int GetNum()
		{
			return mNum;
		}

		static int* GetNumPtr()
		{
			return &mNum;
		}

		static ref int GetNumRef()
		{
			return ref mNum;
		}

		static int mNum;

		[Test]
		public static void Test1()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			tinker.AddMethod("AddNum", (function void(int)) => AddNum);
			tinker.AddMethod("AddNumPtr", (function void(int*)) => AddNum);
			tinker.AddMethod("AddNumRef", (function void(ref int)) => AddNum);
			tinker.AddMethod("GetNum", (function int()) => GetNum);
			tinker.AddMethod("GetNumPtr", (function int*()) => GetNumPtr);
			tinker.AddMethod("GetNumRef", (function ref int()) => GetNumRef);

			tinker.SetValue("NumRef", ref mNum);

			if (lua.DoString(
				@"""
				AddNum(2)
				assert(GetNum() == 2)

				AddNumRef(GetNumRef())
				assert(GetNum() == 4)

				AddNumPtr(GetNumPtr())
				assert(GetNum() == 8)
				
				AddNumRef(NumRef)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			Test.Assert(GetNum() == 16);
		}

		public class TestClass : this(int A);

		public static TestClass sTest1;
		public static TestClass sTest2;

		public static TestClass GetTest1()
		{
			return sTest1;
		}

		public static ref TestClass GetTest1Ref()
		{
			return ref sTest1;
		}

		public static ref TestClass GetTest2Ref()
		{
			return ref sTest2;
		}

		public static void SetTestRef(ref TestClass test, ref TestClass newTest)
		{
			test = newTest;
		}

		[Test]
		public static void Test2()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			sTest1 = new .(1);
			defer delete sTest1;

			sTest2 = new .(2);
			defer delete sTest2;

			LuaTinker tinker = scope .(lua);

			tinker.AddMethod<function ref TestClass()>("GetTest1Ref", => GetTest1Ref);
			tinker.AddMethod<function ref TestClass()>("GetTest2Ref", => GetTest2Ref);
			tinker.AddMethod<function void(ref TestClass, ref TestClass)>("SetTestRef", => SetTestRef);
			
			if (lua.DoString(
				@"""
				SetTestRef(GetTest1Ref(), GetTest2Ref())
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			Test.Assert(sTest1.A == 2);

			tinker.AddMethod<function TestClass()>("GetTest1", => GetTest1);

			Test.Assert(lua.DoString(
				@"""
				SetTestRef(GetTest1(), GetTest2Ref())
				"""
			));
		}
	}
}
