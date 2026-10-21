using System;
using System.Collections;
using KeraLua;

namespace LuaTinker.Tests
{
	static class TestProperty
	{
		struct Counter
		{
			public int32 Value;
		}

		struct PropertyValue
		{
			public int32 Value { get; set mut; }
			public ref Counter Nested { get mut; set mut; }
			public int32 Next { get mut => ++Value; }
			public int32 Read() => Value;
			public void Write(int32 value) mut => Value = value;
			public void Write(int32 first, int32 second) mut => Value = first + second;
		}

		[Test]
		public static void TestStructPropertyBindings()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			PropertyValue value = .();
			tinker.AutoTinkClass<PropertyValue>(.Deep);
			tinker.SetValue("value", ref value);
			if (lua.DoString("""
				value.Value = 7
				assert(value.Value == 7)
				value.Nested.Value = 9
				value:Write(11)
				assert(value.Value == 11)
				value:Write(12, 13)
				assert(value.Next == 26)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(value.Value == 26 && value.Nested.Value == 9);
		}

		[Test]
		public static void TestStructPropertyAccessors()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			PropertyValue value = .();
			using (let binding = tinker.BeginClass<PropertyValue>())
			{
				binding.AddProperty<const "Value">();
				binding.AddProperty<int32>("StaticValue", (self) => self.Value, (self, value) => self.Value = value);
				binding.AddProperty<int32>("MethodValue",
					(function int32(PropertyValue this)) => PropertyValue.Read,
					(function void(mut PropertyValue this, int32)) => PropertyValue.Write);
				binding.AddProperty<int32, delegate int32(PropertyValue), delegate void(ref PropertyValue, int32)>(
					"DelegateValue", new (self) => self.Value, new (self, value) => self.Value = value);
			}
			tinker.SetValue("value", ref value);
			if (lua.DoString("""
				value.StaticValue = 1
				assert(value.MethodValue == 1)
				value.MethodValue = 2
				assert(value.DelegateValue == 2)
				value.DelegateValue = 3
				assert(value.Value == 3)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
			Test.Assert(value.Value == 3);
		}

		class RefHolder
		{
			private Counter* mReference;
			public ref Counter Value { get; set; }
			public ref Counter ReadOnly
			{
				get => ref Value;
				private set => Value = value;
			}
			public ref Counter Reference
			{
				get => ref *mReference;
				set ref => mReference = &value;
			}
			public this() { mReference = &Value; }
		}

		[Test]
		public static void TestRefPropertyBindings()
		{
			for (int mode < 2)
			{
				let lua = scope Lua(true);
				let tinker = scope LuaTinker(lua);
				let holder = scope RefHolder();
				Counter replacement = .() { Value = 11 };
				if (mode == 0)
					tinker.AutoTinkClass<RefHolder>(.Deep);
				else
				{
					tinker.AddClass<Counter>();
					tinker.AddClassVar<Counter, const "Value">();
					tinker.AddClass<RefHolder>();
					tinker.AddClassProperty<RefHolder, const "Value">();
					tinker.AddClassProperty<RefHolder, const "ReadOnly">();
					tinker.AddClassProperty<RefHolder, const "Reference">();
				}
				tinker.SetValue("holder", holder);
				tinker.SetValue("replacement", ref replacement);
				if (lua.DoString("""
					holder.Value.Value = 7
					assert(holder.ReadOnly.Value == 7)
					holder.Value = replacement
					assert(holder.ReadOnly.Value == 11)
					holder.Reference = replacement
					holder.Reference.Value = 13
					assert(not pcall(function() holder.ReadOnly = replacement end))
					"""))
					Test.FatalError(lua.ToString(-1, .. scope .()));
				Test.Assert(holder.Value.Value == 11 && replacement.Value == 13);
			}
		}

		class TextHolder
		{
			public append String Text = .(32);
			public this() { Text.Set("initial"); }
			public StringView Read() => Text;
			public void Write(StringView value) { Text.Set(value); }
		}

		[Test]
		public static void TestStructReturningPropertyFunctions()
		{
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			tinker.AddClass<TextHolder>("TextHolder");
			tinker.AddClassCtor<TextHolder>();
			tinker.AddClassProperty<TextHolder, StringView>("StaticText",
				(self) => self.Text, (self, value) => self.Write(value));
			tinker.AddClassProperty<TextHolder, StringView>("MethodText",
				(function StringView(TextHolder this)) => TextHolder.Read,
				(function void(TextHolder this, StringView)) => TextHolder.Write);
			if (lua.DoString("""
				local holder = TextHolder()
				assert(holder.StaticText == "initial")
				holder.StaticText = "static setter"
				assert(holder.MethodText == "static setter")
				holder.MethodText = "method setter"
				assert(holder.StaticText == "method setter")
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			
			tinker.AddClass<Type>("Type");
			tinker.AddClassProperty<Type, int32>("Size", (self) => self.Size, null);

			int magic = 0;
			tinker.AddClassProperty<Type, int32, delegate int32(Type), delegate void(Type, int32)>(
				"Magic",
				new (self) => {
					return self.Size + (.)self.TypeId;
				},
				new [&](self, value) => {
					magic = value;
				});

			tinker.AddMethod("GetType", (function Type())
				() => typeof(Self));

			if (lua.DoString(
				@"""
				type = GetType()
				type.Magic = type.Magic - type.Size + 5
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			Test.Assert(magic == (.)typeof(TestProperty).TypeId + 5);
		}

		[Test]
		public static void TestReadonlyProperty()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			
			tinker.AddClass<Type>("Type");
			tinker.AddClassProperty<Type, int32>("Size", (self) => self.Size, null);
			tinker.AddClassProperty<Type, int32, delegate int32(Type), delegate void(Type, int32)>(
				"Magic",
				new (self) => {
					return self.Size + (.)self.TypeId;
				},
				null);

			tinker.AddMethod("GetType", (function Type())
				() => typeof(Self));

			Test.Assert(lua.DoString(
				@"""
				type = GetType()
				type.Size = 5
				"""
			));

			Test.Assert(lua.DoString(
				@"""
				type = GetType()
				type.Magic = 5
				"""
			));
		}

		[Test]
		public static void TestReflectedClassProperty()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			tinker.AddClass<List<float>>("FloatList");
			tinker.AddClassCtor<List<float>>();
			tinker.AddClassProperty<List<float>, const "Count">();
			tinker.AddClassProperty<List<float>, const "IsEmpty">();

			if (lua.DoString(
				"""
				local list = FloatList()
				list.Count = 2
				assert(list.Count == 2)
				local ok = pcall(function() list.IsEmpty = true end)
				assert(not ok)
				"""
			))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		public static void FakeSetSize(Type type, int32 size)
		{
			Test.Assert(size == 5);
		}

		[Test]
		public static void TestWriteonlyProperty()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			
			tinker.AddClass<Type>("Type");
			tinker.AddClassProperty<Type, int32>("Size", null, (function void(Type, int32)) => FakeSetSize);

			int magic = 0;
			tinker.AddClassProperty<Type, int32, delegate int32(Type), delegate void(Type, int32)>(
				"Magic",
				null,
				new [&](self, value) => {
					magic = value;
				});

			tinker.AddMethod("GetType", (function Type())
				() => typeof(Self));

			Test.Assert(lua.DoString(
				@"""
				type = GetType()
				type.Size = 5
				print(type.Size)
				"""
			));

			Test.Assert(lua.DoString(
				@"""
				type = GetType()
				type.Magic = 5
				print(type.Magic)
				"""
			));

			Test.Assert(magic == 5);
		}

		[Test(ShouldFail=true)]
		public static void TestInvalidFuncProperty()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			
			tinker.AddClass<Type>("Type");
			tinker.AddClassProperty<Type, int32>("Size", (function int32(Type)) null, null);
		}
		
		[Test(ShouldFail=true)]
		public static void TestInvalidDlgProperty()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.AddClassProperty<Type, int32, delegate int32(Type), delegate void(Type, int32)>("Magic", null, null);
		}
	}
}
