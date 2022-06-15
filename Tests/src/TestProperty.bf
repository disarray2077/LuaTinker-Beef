using System;
using KeraLua;

namespace LuaTinker.Tests
{
	static class TestProperty
	{
		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			
			tinker.AddClass<Type>("Type");
			function int32(Type this) getSizeFunc = (.) (void*) ((function int32(Type)) (self) => self.Size);
			tinker.AddClassProperty<Type, int32>("Size", getSizeFunc, null);

			int magic = 0;
			tinker.AddClassProperty<Type, int32, delegate int32(Type), delegate void(Type, int32)>("Magic",
				new (self) => {
					return self.Size + (.)self.TypeId;
				},
				new [&](self, value) => {
					magic = value;
				});

			tinker.AddMethod("GetType", (function Type())
				() => { return typeof(Self); });

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
			function int32(Type this) getSizeFunc = (.) (void*) ((function int32(Type)) (self) => self.Size);
			tinker.AddClassProperty<Type, int32>("Size", getSizeFunc, null);
			tinker.AddClassProperty<Type, int32, delegate int32(Type), delegate void(Type, int32)>("Magic",
				new (self) => {
					return self.Size + (.)self.TypeId;
				},
				null);

			tinker.AddMethod("GetType", (function Type())
				() => { return typeof(Self); });

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
			function void(Type this, int32) setSizeFunc = (.) (void*) ((function void(Type, int32)) => FakeSetSize);
			tinker.AddClassProperty<Type, int32>("Size", null, setSizeFunc);

			int magic = 0;
			tinker.AddClassProperty<Type, int32, delegate int32(Type), delegate void(Type, int32)>("Magic",
				null,
				new [&](self, value) => {
					magic = value;
				});

			tinker.AddMethod("GetType", (function Type())
				() => { return typeof(Self); });

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
			tinker.AddClassProperty<Type, int32>("Size", null, null);
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
