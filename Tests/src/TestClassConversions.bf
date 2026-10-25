using System;
using KeraLua;

namespace LuaTinker.Tests
{
	class TestClassConversions
	{
		class Value {}

		[Test]
		public static void TestClassReferenceAsObject()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			let instance = scope Value();
			var reference = instance;
			tinker.SetValue("reference", ref reference);
			tinker.AddMethod<function Object(Object)>("Identity", (value) => value);
			Test.Assert(tinker.Eval<Object>("return Identity(reference)").Get() == instance);
		}

		[Test]
		public static void TestStringClassReferences()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AddClass<StringBuilder>("StringBuilder");
			let instance = scope StringBuilder("value");
			StringBuilder reference = instance;
			tinker.SetValue("reference", ref reference);
			tinker.SetValue("pointer", &reference);
			Test.Assert(tinker.GetValue<StringBuilder>("reference").Get() == instance);
			Test.Assert(tinker.GetValue<StringBuilder>("pointer").Get() == instance);
			tinker.AddMethod<function int(String)>("Length", (value) => value.Length);
			if (lua.DoString("assert(Length(reference) == 5 and Length(pointer) == 5)"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}
	}
}
