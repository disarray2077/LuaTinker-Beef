using System;
using KeraLua;
using System.Diagnostics;

namespace LuaTinker.StackHelpers
{
	public struct User2Type
	{
		[Inline]
		public static ref T GetTypeDirect<T>(Lua lua, int32 index)
		{
			if (!lua.IsUserData(index))
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"expected 'UserData' but got '{lua.TypeName(index)}'");
				lua.Error();
			}
			var ptr = lua.ToUserData(index);
			return ref *((T*)&ptr);
		}

		[Inline]
		public static Object UnsafeGetObject(Lua lua, int32 index)
		{
			return Internal.UnsafeCastToObject(lua.ToUserData(index));
		}

		[Inline]
		private static T* GetTypePtr<T>(void* ptr) where T : struct*
		{
			return (T*)ptr;
		}

		[Inline]
		private static T GetTypePtr<T>(void* ptr) where T : class
		{
			return (T)Internal.UnsafeCastToObject(ptr);
		}

		[Inline]
		public static T GetTypePtr<T>(Lua lua, int32 index) where T : var
		{
			if (!lua.IsUserData(index))
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"expected 'UserData' but got '{lua.TypeName(index)}'");
				lua.Error();
			}
			return GetTypePtr<T>(lua.ToUserData(index));
		}

		[Inline]
		public static T UnsafeGetTypePtr<T>(Lua lua, int32 index) where T : var
		{
			return GetTypePtr<T>(lua.ToUserData(index));
		}
	}
}
