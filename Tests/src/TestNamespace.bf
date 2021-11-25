using System;
using KeraLua;

namespace System
{
	extension Version
	{
		public bool Check(Version other)
		{
			return (Major > other.Major) || ((Major == other.Major) && (Minor > other.Minor)) ||
				((Major == other.Major) && (Minor == other.Minor) && (Build > other.Build)) ||
				((Major == other.Major) && (Minor == other.Minor) && (Build == other.Build) && (Revision >= other.Revision));
		}
	}
}

namespace LuaTinker.Tests
{
	static class TestNamespace
	{
		static int32 mNum;

		public static void TestCall(int8 i)
		{
			mNum += i;
		}

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);

			tinker.AddClass<Version>("Version");
			tinker.AddClassMethod<Version, function bool(Version this, Version)>("Check", => Version.Check);

			tinker.AddNamespace("LuaTinker.Tests");
			tinker.AddNamespaceMethod("LuaTinker.Tests", "TestCall", (function void(int8)) => TestCall);
			tinker.AddNamespaceVar("LuaTinker", "Version", Environment.OSVersion.Version);

			tinker.AddMethod("GetVersion", (function Version()) () => { return Environment.OSVersion.Version; });

			if (lua.DoString(
				@"""
				if not LuaTinker.Version:Check(GetVersion()) then
					error("Version check failed")
				end
				LuaTinker.Tests.TestCall(32)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}
			
			tinker.AddNamespace("LuaTinker.Tests.Networking.Factory.Services");
			tinker.AddNamespaceMethod("LuaTinker.Tests.Networking.Factory.Services", "CreateInstance", (function void(int8)) => TestCall);
			tinker.AddNamespaceMethod("LuaTinker.Tests.Networking", "SendData", (function void(int8)) => TestCall);
			
			if (lua.DoString(
				@"""
				LuaTinker.Tests.Networking.Factory.Services.CreateInstance(55)
				LuaTinker.Tests.Networking.SendData(-7)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			Test.Assert(mNum == 32 + 55 - 7);
		}
	}
}
