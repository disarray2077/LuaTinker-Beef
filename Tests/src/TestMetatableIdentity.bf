using System;
using System.Collections;
using KeraLua;
using LuaTinker.StackHelpers;

namespace LuaTinker.Tests
{
	class TestMetatableIdentity
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

		struct BorrowedValue
		{
			public int Value;
		}

		private static void AssertMetatableValidity<T>(Lua lua, bool valid)
		{
			let top = lua.GetTop();
			Test.Assert(StackHelper.CheckMetaTableValidity<T>(lua, -1) == valid);
			Test.Assert((StackHelper.EnsureValidMetaTable<T>(lua, -1) != .Error) == valid);
			Test.Assert(lua.GetTop() == top);
			lua.Pop(1);
		}

		[Test]
		public static void TestMetatableValidationAgreement()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			lua.PushInteger(1);
			AssertMetatableValidity<BorrowedValue>(lua, false);
			lua.PushString("value");
			AssertMetatableValidity<BorrowedValue>(lua, false);
			lua.CreateTable(0, 0);
			AssertMetatableValidity<BorrowedValue>(lua, false);
			lua.NewUserData(1);
			AssertMetatableValidity<BorrowedValue>(lua, false);
			uint8 foreign = 0;
			lua.PushLightUserData(&foreign);
			AssertMetatableValidity<BorrowedValue>(lua, false);

			var value = BorrowedValue() { Value = 1 };
			Type2User.Create(lua, ref value);
			AssertMetatableValidity<BorrowedValue>(lua, true);

			tinker.AddClass<BaseValue>("BaseValue");
			tinker.AddClass<DerivedValue>("DerivedValue");
			tinker.AddClassParent<DerivedValue, BaseValue>();
			let derived = scope DerivedValue(2);
			tinker.SetValue("derived", derived);
			lua.GetGlobal("derived");
			AssertMetatableValidity<BaseValue>(lua, true);
		}

		[Test]
		public static void TestReboundGlobals()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<BaseValue>("BaseValue");
			tinker.AddClass<DerivedValue>("DerivedValue");
			tinker.AddClass<List<int>>("IntList");
			Test.Assert(!lua.DoString("SavedBase = BaseValue; SavedDerived = DerivedValue; SavedList = IntList; BaseValue = {}; DerivedValue = nil; IntList = false"));

			tinker.AddClassCtor<BaseValue, int>();
			tinker.AddClassCtor<DerivedValue>();
			tinker.AddClassParent<DerivedValue, BaseValue>();
			tinker.AddClassVar<BaseValue, const "Value">();
			tinker.AddClassProperty<BaseValue, const "Property">();
			tinker.AddClassMethod<BaseValue, function int(BaseValue this)>("Read", => BaseValue.Read);
			tinker.AddClassMethod<BaseValue, const "Read">("DynamicRead");
			tinker.AddClassIndexer<List<int>, int>();
			let borrowed = scope DerivedValue(20);
			let list = scope List<int>() { 30 };
			tinker.SetValue("borrowed", borrowed);
			tinker.SetValue("list", list);
			tinker.SetValue<DerivedValue>("nilValue", null);
			if (lua.DoString(
				"""
				created = SavedDerived(10)
				assert(created.Value == 10)
				created.Property = 11
				assert(created:Read() == 11 and created:DynamicRead() == 11)
				assert(SavedBase(12):Read() == 12)
				assert(borrowed:Read() == 20)
				borrowed.Value = 21
				assert(list[0] == 30)
				list[0] = 31
				assert(nilValue == nil)
				assert(not pcall(function() SavedBase.Read(list) end))
				"""
			))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(borrowed.Value == 21);
			Test.Assert(list[0] == 31);
			Test.Assert(tinker.GetValue<BaseValue>("created") case .Ok);
			Test.Assert(tinker.GetValue<DerivedValue>("borrowed").Get() == borrowed);
			Test.Assert(tinker.GetValue<BaseValue>("list") case .Err);
			lua.GetGlobal("list");
			Test.Assert(StackHelper.Pop<BaseValue>(lua, -1) == null);
			Test.Assert(tinker.[Friend]mTinkerState.HasError);
			Test.Assert(lua.GetTop() == 1);
			lua.Pop(1);
			Test.Assert(lua.GetTop() == 0);
		}

		[Test]
		public static void TestBorrowedAndUnregisteredValues()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			var value = BorrowedValue() { Value = 1 };
			tinker.SetValue("unregistered", ref value);
			lua.GetGlobal("unregistered");
			ref BorrowedValue popped = ref StackHelper.Pop<BorrowedValue>(lua, -1);
			Test.Assert(&popped == &value);
			lua.Pop(1);
			tinker.AddClass<BorrowedValue>("BorrowedValue");
			tinker.AddClassVar<BorrowedValue, const "Value">();
			tinker.SetValue("registered", ref value);
			Test.Assert(!lua.DoString("BorrowedValue = nil; registered.Value = 2"));
			Test.Assert(value.Value == 2);
			Test.Assert(tinker.GetValue<BorrowedValue>("registered").Get().Value == 2);
		}

		[Test]
		public static void TestUserdataWithoutLuaTinkerMetatable()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<BaseValue>("BaseValue");
			let state = tinker.[Friend]mTinkerState;
			lua.NewUserData(1);
			Test.Assert(StackHelper.Pop<BaseValue>(lua, -1) == null);
			Test.Assert(state.HasError);
			Test.Assert(lua.GetTop() == 1);
			state.ClearError();
			StackHelper.Pop<BorrowedValue>(lua, -1);
			Test.Assert(state.HasError);
			Test.Assert(lua.GetTop() == 1);
			lua.Pop(1);
			state.ClearError();
			uint8 foreign = 0;
			lua.PushLightUserData(&foreign);
			Test.Assert(StackHelper.Pop<BaseValue>(lua, -1) == null);
			Test.Assert(state.HasError);
			Test.Assert(lua.GetTop() == 1);
			lua.Pop(1);
		}
	}
}
