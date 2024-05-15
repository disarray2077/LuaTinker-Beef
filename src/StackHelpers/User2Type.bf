using System;
using KeraLua;
using System.Diagnostics;
using LuaTinker.Wrappers;

namespace LuaTinker.StackHelpers
{
	public struct User2Type
	{
		public static T GetTypeDirect<T>(Lua lua, int32 index)
		{
			if (!lua.IsUserData(index))
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"expected 'UserData' but got '{lua.TypeName(index)}'");
				lua.Error();
			}
			var ptr = lua.ToUserData(index);
			return *((T*)&ptr);
		}

		public static Object GetObject(Lua lua, int32 index)
		{
			if (!lua.IsUserData(index))
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"expected 'UserData' but got '{lua.TypeName(index)}'");
				lua.Error();
			}
			return Internal.UnsafeCastToObject(lua.ToUserData(index));
		}

		public static Type GetObjectType(Lua lua, int32 index)
		{
			if (!lua.IsUserData(index))
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"expected 'UserData' but got '{lua.TypeName(index)}'");
				lua.Error();
			}
			Object object = Internal.UnsafeCastToObject(lua.ToUserData(index));
			if (let wrapper = object as PointerWrapperBase)
				return wrapper.Type;
			return object.GetType();
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
