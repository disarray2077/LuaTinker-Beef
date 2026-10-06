using System;
using KeraLua;

namespace LuaTinker.Tests
{
	class TestUnregisteredValues
	{
		struct UnregisteredValue : IDisposable
		{
			public int* DisposeCount;
			public void Dispose() { (*DisposeCount)++; }
			public override void ToString(String buffer) { buffer.Append("unregistered value"); }
		}

		class UnregisteredClass
		{
			private int* mDeleteCount;
			public this(int* deleteCount) { mDeleteCount = deleteCount; }
			public ~this() { (*mDeleteCount)++; }
			public override void ToString(String buffer) { buffer.Append("unregistered class"); }
		}

		[Test]
		public static void TestUnregisteredToStringAndNil()
		{
			int disposeCount = 0;
			int deleteCount = 0;
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			var value = UnregisteredValue() { DisposeCount = &disposeCount };
			let borrowedClass = scope UnregisteredClass(&deleteCount);
			tinker.SetValue("value", value);
			tinker.SetValue("reference", ref value);
			tinker.SetValue("pointer", &value);
			tinker.SetValue("borrowedClass", borrowedClass);
			tinker.SetValue<UnregisteredClass>("nullClass", null);
			tinker.SetValue<UnregisteredValue*>("nullPointer", null);
			tinker.SetString("expectedPointer", (&value).ToString(.. scope .()));
			if (lua.DoString(
				"""
				assert(tostring(value) == "unregistered value")
				assert(tostring(reference) == "unregistered value")
				assert(tostring(pointer) == expectedPointer)
				assert(tostring(borrowedClass) == "unregistered class")
				assert(nullClass == nil and nullPointer == nil)
				"""
			))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestUnregisteredFinalization()
		{
			int disposeCount = 0;
			int deleteCount = 0;
			let lua = scope Lua(true);
			LuaTinker tinker = scope .(lua);
			var value = UnregisteredValue() { DisposeCount = &disposeCount };
			let borrowedClass = scope UnregisteredClass(&deleteCount);
			tinker.SetValue("value", value);
			tinker.SetValue("reference", ref value);
			tinker.SetValue("pointer", &value);
			tinker.SetValue("borrowedClass", borrowedClass);
			let disposeCountPtr = &disposeCount;
			let deleteCountPtr = &deleteCount;
			tinker.AddMethod<delegate int()>("DisposeCount", new () => *disposeCountPtr);
			tinker.AddMethod<delegate int()>("DeleteCount", new () => *deleteCountPtr);
			if (lua.DoString(
				"""
				collectgarbage()
				assert(DisposeCount() == 0 and DeleteCount() == 0)
				value = nil
				reference = nil
				pointer = nil
				borrowedClass = nil
				collectgarbage()
				assert(DisposeCount() == 1 and DeleteCount() == 0)
				collectgarbage()
				assert(DisposeCount() == 1 and DeleteCount() == 0)
				"""
			))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

	}
}
