using KeraLua;
using System;
using System.Collections;

namespace LuaTinker.Tests
{
	class TestFailures
	{
		class MyTestClass
		{
			public int Value;
			public this(int val) { Value = val; }
			public int Add(int other) => Value + other;
		}

		[Test]
		public static void TestGetValue()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;
			LuaTinker tinker = scope .(lua);

			if (lua.DoString(
				@"""
				my_num = 123.45
				my_int = 500
				my_str = "hello world"
				my_bool = true
				"""
				))
			{
				Test.FatalError("Failed to setup Lua state for GetValue tests.");
			}

			Test.Assert(tinker.GetValue<StringBuilder>("my_num") case .Err);
			Test.Assert(tinker.GetString!("my_num") case .Ok);
			Test.Assert(tinker.GetValue<StringView>("my_num") case .Ok);
			Test.Assert(tinker.GetValue<int>("my_str") case .Err);
			Test.Assert(tinker.GetValue<double>("my_bool") case .Err);
			Test.Assert(tinker.GetValue<uint8>("my_int") case .Err);
			Test.Assert(tinker.GetValue<int>("non_existent_var") case .Err);
		}

		[Test]
		public static void TestCallLua()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;
			LuaTinker tinker = scope .(lua);

			if (lua.DoString(
				@"""
				function returns_string()
					return "this is not a number"
				end
				"""
				))
			{
				Test.FatalError("Failed to setup Lua state for CallLua tests.");
			}

			Test.Assert(tinker.Call<int>("returns_string") case .Err);
			Test.Assert(tinker.Call<bool>("returns_string") case .Err);
			Test.Assert(tinker.Call<void>("non_existent_function") case .Err);
		}

		[Test]
		public static void TestMethodCallFailures()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;
			LuaTinker tinker = scope .(lua);

			tinker.AddClass<MyTestClass>();
			tinker.AddClassCtor<MyTestClass, int>();
			tinker.AddClassMethod<MyTestClass, function int(MyTestClass this, int)>("Add", => MyTestClass.Add);

			Test.Assert(lua.DoString(
				@"""
				obj = MyTestClass(10)
				obj:Add() -- Missing argument
				"""
			));

			Test.Assert(lua.DoString(
				@"""
				obj = MyTestClass(10)
				obj:Add(5, 10) -- Too many arguments
				"""
			));

			Test.Assert(lua.DoString(
				@"""
				obj = MyTestClass(10)
				obj:Add("hello") -- Wrong argument type
				"""
			));
		}

		[Test]
		public static void TestConstructorFailures()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;
			LuaTinker tinker = scope .(lua);

			tinker.AddClass<MyTestClass>();
			tinker.AddClassCtor<MyTestClass, int>();

			Test.Assert(lua.DoString(
				@"""
				obj = MyTestClass() -- Default constructor not registered
				"""
			));

			Test.Assert(lua.DoString(
				@"""
				obj = MyTestClass("world") -- Wrong argument type for registered constructor
				"""
			));
		}

		[Test]
		public static void TestMemberAccessFailures()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;
			LuaTinker tinker = scope .(lua);

			tinker.AddClass<MyTestClass>();
			tinker.AddClassCtor<MyTestClass, int>();
			tinker.AddClassVar<MyTestClass, const "Value">();

			Test.Assert(lua.DoString(
				@"""
				obj = MyTestClass(10)
				print(obj.NonExistentMember)
				"""
			));

			Test.Assert(lua.DoString(
				@"""
				obj = MyTestClass(10)
				obj:NonExistentMethod()
				"""
			));

			tinker.AddMethod<function MyTestClass()>("GetNilObject", () => null);
			Test.Assert(lua.DoString(
				@"""
				obj = GetNilObject()
				obj:Add(5) -- Calling method on nil
				"""
			));
		}

		[Test]
		public static void TestIndexerFailures()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;
			LuaTinker tinker = scope .(lua);

			tinker.AddClass<List<int>>("IntList");
			tinker.AddClassCtor<List<int>>();
			tinker.AddClassIndexer<List<int>, int>();
			tinker.AddMethod<delegate List<int>()>("CreateList", new () => new List<int>() { 10, 20, 30 });

			Test.Assert(lua.DoString(
				@"""
				list = CreateList()
				val = list["key"] -- String key instead of integer
				"""
			));

			Test.Assert(lua.DoString(
				@"""
				list = CreateList()
				list[false] = 100 -- Boolean key instead of integer
				"""
			));
		}
	}
}