using System;
using KeraLua;
using System.Diagnostics;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	public struct User2Type
	{
		public static T GetTypeDirect<T>(Lua lua, int32 index)
		{
			if (!lua.IsUserData(index))
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"expected 'UserData' but got '{lua.TypeName(index)}'");
				StackHelper.TryThrowError(lua, luaTinker);
				return default;
			}
			var ptr = lua.ToUserData(index);
			return *((T*)&ptr);
		}

		public static Object GetObject(Lua lua, int32 index)
		{
			if (!lua.IsUserData(index))
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"expected 'UserData' but got '{lua.TypeName(index)}'");
				StackHelper.TryThrowError(lua, luaTinker);
				return default;
			}
			return Internal.UnsafeCastToObject(lua.ToUserData(index));
		}

		public static Type GetObjectType(Lua lua, int32 index)
		{
			if (!lua.IsUserData(index))
			{
				/*let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"expected 'UserData' but got '{lua.TypeName(index)}'");
				StackHelper.TryThrowError(lua, luaTinker);*/
				return default;
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
		private static T* GetTypePtr<T>(Lua lua, void* ptr) where T : struct*
		{
			return (T*)ptr;
		}

		[Inline]
		private static T GetTypePtr<T>(Lua lua, void* ptr) where T : class
		{
#if DEBUG || BF_DYNAMIC_CAST_CHECK
			let obj = Internal.UnsafeCastToObject(ptr);
			if (let res = obj as T)
				return res;
#unwarn
			let luaTinker = lua.TinkerState;
			luaTinker.SetLastError($"expected '{typeof(T)}' but got '{obj.GetType()}'");
			StackHelper.TryThrowError(lua, luaTinker);
			return default;
#else
			return (T)Internal.UnsafeCastToObject(ptr);
#endif
		}

		public static T GetTypePtr<T>(Lua lua, int32 index) where T : var
		{
			if (!lua.IsUserData(index))
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"expected 'UserData' but got '{lua.TypeName(index)}'");
				StackHelper.TryThrowError(lua, luaTinker);
				return default;
			}
			return GetTypePtr<T>(lua, lua.ToUserData(index));
		}

		[Inline]
		public static T UnsafeGetTypePtr<T>(Lua lua, int32 index) where T : var
		{
			return GetTypePtr<T>(lua, lua.ToUserData(index));
		}
	}
}
