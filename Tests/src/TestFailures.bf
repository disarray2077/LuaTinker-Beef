using KeraLua;
using System;
using System.Collections;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

namespace LuaTinker.Tests
{
	class TestFailures
	{
		class MyTestClass
		{
			public int Value;
			public this(int val) { Value = val; }
			public int Add(int other) => Value + other;
			public bool IsSame(MyTestClass other) => this == other;
		}

		class NoAllocationAllocator : ITypedAllocator
		{
			public void* Alloc(int size, int align)
			{
				Test.FatalError("Rejected String conversion must not allocate");
				return null;
			}
			public void* AllocTyped(Type type, int size, int align) => Alloc(size, align);
			public void Free(void* ptr) {}
		}

		[Test]
		public static void TestStringConversionDoesNotBoxValues()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			let state = tinker.[Friend]mTinkerState;
			let allocator = scope NoAllocationAllocator();
			var value = 123;
			Type2User.Create(lua, value);
			Test.Assert(StackHelper.[Friend]PopString(lua, -1, allocator) == null);
			Test.Assert(state.GetLastError().Contains("to 'String'"));
			Test.Assert(lua.GetTop() == 1);
			lua.Pop(1);
			state.ClearError();

			Type2User.Create(lua, ref value);
			Test.Assert(StackHelper.[Friend]PopString(lua, -1, allocator) == null);
			Test.Assert(state.GetLastError().Contains("to 'String'"));
			Test.Assert(lua.GetTop() == 1);
			lua.Pop(1);
		}

		[Test]
		public static void TestStringUserdataConversion()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			let state = tinker.[Friend]mTinkerState;
			let str = scope String("borrowed string");
			Type2User.Create(lua, str);
			Test.Assert(StackHelper.Pop!<String>(lua, -1) === str);
			Test.Assert(!state.HasError);
			lua.Pop(1);

			Type2User.Create<Object>(lua, str);
			Test.Assert(StackHelper.Pop!<String>(lua, -1) === str);
			Test.Assert(!state.HasError);
			lua.Pop(1);

			let other = scope MyTestClass(1);
			Type2User.Create(lua, other);
			Test.Assert(StackHelper.Pop!<String>(lua, -1) == null);
			Test.Assert(state.GetLastError().Contains("to 'String'"));
			lua.Pop(1);
			state.ClearError();

			lua.NewUserData(1);
			Test.Assert(StackHelper.Pop!<String>(lua, -1) == null);
			Test.Assert(state.GetLastError().Contains("to 'LuaTinker object'"));
			Test.Assert(lua.GetTop() == 1);
			lua.Pop(1);
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
		public static void TestHostPopForeignUserdata()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			let state = tinker.[Friend]mTinkerState;
			Test.Assert(!lua.DoString("return assert(io.tmpfile())"));

			let classValue = StackHelper.Pop<MyTestClass>(lua, 1);
			Test.Assert(classValue == null);
			Test.Assert(state.HasError);
			Test.Assert(state.GetLastError().Contains("can't convert argument"));

			state.ClearError();
			lua.SetTop(1);
			StackHelper.Pop<DateTime>(lua, 1);
			Test.Assert(state.HasError);
			Test.Assert(state.GetLastError().Contains("can't convert argument"));

			state.ClearError();
			lua.SetTop(1);
			let stringBuilderValue = StackHelper.Pop<StringBuilder>(lua, 1);
			Test.Assert(stringBuilderValue == null);
			Test.Assert(state.HasError);
			Test.Assert(state.GetLastError().Contains("can't convert argument"));
		}

		[Test]
		public static void TestUserdataKindExtraction()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<MyTestClass>();
			tinker.AddClassCtor<MyTestClass, int>();
			tinker.AddClassVar<MyTestClass, const "Value">();
			tinker.AddClass<List<int>>("IntList");
			tinker.AddClassIndexer<List<int>, int>();
			if (lua.DoString(
				"""
				instance = MyTestClass(10)
				variableWrapper = getmetatable(instance).Value
				indexerWrapper = IntList.__bfindexer
				"""
			))
				Test.FatalError(lua.ToString(-1, .. scope .()));

			lua.GetGlobal("instance");
			Test.Assert(User2Type.TryGetTypePtr<PointerWrapperBase>(lua, -1) != null);
			Test.Assert(User2Type.TryGetTypePtr<VariableWrapperBase>(lua, -1) == null);
			Test.Assert(User2Type.TryGetTypePtr<IndexerWrapperBase>(lua, -1) == null);
			Test.Assert(User2Type.TryGetTypePtr<ClassInstanceWrapper<String>>(lua, -1) == null);
			Test.Assert(!lua.[Friend]TinkerState.HasError);
			lua.Pop(1);

			lua.GetGlobal("variableWrapper");
			Test.Assert(User2Type.TryGetTypePtr<VariableWrapperBase>(lua, -1) != null);
			Test.Assert(User2Type.TryGetTypePtr<PointerWrapperBase>(lua, -1) == null);
			Test.Assert(User2Type.TryGetTypePtr<IndexerWrapperBase>(lua, -1) == null);
			Test.Assert(!lua.[Friend]TinkerState.HasError);
			lua.Pop(1);

			lua.GetGlobal("indexerWrapper");
			Test.Assert(User2Type.TryGetTypePtr<IndexerWrapperBase>(lua, -1) != null);
			Test.Assert(User2Type.TryGetTypePtr<PointerWrapperBase>(lua, -1) == null);
			Test.Assert(User2Type.TryGetTypePtr<VariableWrapperBase>(lua, -1) == null);
			Test.Assert(!lua.[Friend]TinkerState.HasError);
			lua.Pop(1);
		}

		[Test]
		public static void TestForeignUserdata()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<MyTestClass>();
			tinker.AddClassCtor<MyTestClass, int>();
			tinker.AddClassMethod<MyTestClass, function int(MyTestClass this, int)>("Add", => MyTestClass.Add);
			tinker.AddClassMethod<MyTestClass, const "Add">("DynamicAdd");
			tinker.AddClassMethod<MyTestClass, function bool(MyTestClass this, MyTestClass)>("IsSame", => MyTestClass.IsSame);
			tinker.AddMethod<function int(MyTestClass)>("ReadClass", (value) => value.Value);
			tinker.AddMethod<function int(Object)>("ReadObject", (value) => 1);
			tinker.AddMethod<function int(int32*)>("ReadPointer", (value) => 1);

			if (lua.DoString(
				"""
				foreign = assert(io.tmpfile())
				local obj = MyTestClass(10)
				assert(obj:Add(2) == 12)
				assert(obj:DynamicAdd(2) == 12)
				assert(obj:IsSame(obj))
				assert(not pcall(function() obj:IsSame(foreign) end))
				assert(not pcall(function() ReadClass(foreign) end))
				assert(not pcall(function() ReadObject(foreign) end))
				assert(not pcall(function() ReadPointer(foreign) end))
				assert(not pcall(function() MyTestClass.Add(foreign, 2) end))
				assert(not pcall(function() MyTestClass.DynamicAdd(foreign, 2) end))
				"""
			))
				Test.FatalError(lua.ToString(-1, .. scope .()));

			Test.Assert(tinker.GetValue<MyTestClass>("foreign") case .Err);
			Test.Assert(tinker.GetValue<Object>("foreign") case .Err);
			Test.Assert(tinker.GetValue<int32*>("foreign") case .Err);
			if (lua.DoString("foreign:close()"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
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

			List<int> list = scope List<int>() { 10, 20, 30 };

			tinker.AddClass<List<int>>("IntList");
			tinker.AddClassCtor<List<int>>();
			tinker.AddClassIndexer<List<int>, int>();
			tinker.AddMethod<delegate List<int>()>("CreateList", new () => list);

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
