using System;
using System.Diagnostics;
using System.Collections;
using System.Reflection;
using KeraLua;
using LuaTinker.Handlers;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		[Inline]
		private static void NoRegType2User<T>(Lua lua)
			where T : struct
		{
			// register destructor
			lua.GetGlobal("__noreg_meta");
			Debug.Assert(lua.Type(-1) == .Table, "UserData GC isn't registered!");
			lua.SetMetaTable(-2);
		}

		[SkipCall]
		private static void NoRegType2User<T>(Lua lua)
			where T : String
		{
			// nothing
		}

		[SkipCall]
		private static void NoRegType2User<T>(Lua lua)
		{
			// nothing
		}

		public static void Push<T>(Lua lua, T? val) where T : var
		{
			if (!val.HasValue)
				lua.PushNil();
			else
				Push<T>(lua, val.Value);
		}

		public static void Push<T>(Lua lua, T val) where T : var
		{
			Type2User.Create(lua, val);

			let tinkerState = lua.TinkerState;
			if (!tinkerState.IsClassRegistered<RemovePtr<T>>())
			{
				NoRegType2User<T>(lua);
			}
			else
			{
				lua.GetGlobal(tinkerState.GetClassName<RemovePtr<T>>());
				lua.SetMetaTable(-2);
			}
		}

		public static void Push<T>(Lua lua, ref T val) where T : var
		{
			Type2User.Create<T>(lua, ref val);

			let tinkerState = lua.TinkerState;
			if (!tinkerState.IsClassRegistered<RemovePtr<T>>())
			{
				NoRegType2User<T>(lua);
			}
			else
			{
				lua.GetGlobal(tinkerState.GetClassName<RemovePtr<T>>());
				lua.SetMetaTable(-2);
			}
		}

		public static void Push(Lua lua, Object val)
		{
			if (val == null)
			{
				lua.PushNil();
				return;
			}

			if (var s = val as String)
			{
				lua.PushString(s);
			}
			else if (var sv = val as StringView?)
			{
				lua.PushString(sv);
			}
			else if (var n = val as INumeric)
			{
				lua.PushInteger((int64)n);
			}
			else if (var f = val as IFloating)
			{
				lua.PushNumber((double)f);
			}
			else if (var b = val as bool?)
			{
				lua.PushBoolean(b);
			}
			else
			{
				Push<Object>(lua, val);
			}
		}
		
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct*
		{
			if (lua.IsNil(index))
				return null;

			let stackObject = User2Type.GetObject(lua, index);
			if (let ptrWrapper = stackObject as PointerWrapper<RemovePtr<T>>)
				return ptrWrapper.Ptr;
			else if (let refPtrWrapper = stackObject as RefPointerWrapper<RemovePtr<T>>)
				return &refPtrWrapper.Reference;
			else
			{
				let tinkerState = lua.TinkerState;
				{
					// Set error in a different scope to make sure the temporary strings destructors run before throwing the error.
					tinkerState.SetLastError($"can't convert argument {index} to 'ptr {GetBestLuaClassName<T>(tinkerState, .. scope .())}'");
				}
				TryThrowError(lua, tinkerState);
				return default;
			}
		}

		public static ref T Pop<T>(Lua lua, int32 index) where T : var, struct
		{
			static T dummy = default;

			if (lua.IsNil(index))
			{
				let tinkerState = lua.TinkerState;
				{
					// Set error in a different scope to make sure the temporary strings destructors run before throwing the error.
					tinkerState.SetLastError($"can't convert argument {index} to '{GetBestLuaClassName<T>(tinkerState, .. scope .())}'");
				}
				TryThrowError(lua, tinkerState);
				return ref dummy;
			}

			let result = EnsureValidMetaTable<T>(lua, index);

			let stackObject = User2Type.UnsafeGetObject(lua, index);
			if (result != .OkNoMetaTable)
			{
				// We are sure that this conversion is valid, so let's just do it unsafely.
				let ptr = ((PointerWrapperBase)stackObject).Ptr;

				// This is necessary only because PointerWrapper<T> can contain a null pointer.
				if (ptr == null)
				{
					let tinkerState = lua.TinkerState;
					tinkerState.SetLastError("null pointer dereference");
					TryThrowError(lua, tinkerState);
					return ref dummy;
				}

				return ref *(T*)ptr;
			}

			if (let valueWrapper = stackObject as ValuePointerWrapper<T>)
				return ref *valueWrapper.ValuePointer;
			else if (let refPtrWrapper = stackObject as RefPointerWrapper<T>)
				return ref refPtrWrapper.Reference;
			else if (let ptrWrapper = stackObject as PointerWrapper<T>)
			{
				if (ptrWrapper.Ptr == null)
				{
					let tinkerState = lua.TinkerState;
					tinkerState.SetLastError("null pointer dereference");
					TryThrowError(lua, tinkerState);
					return ref dummy;
				}

				return ref *ptrWrapper.Ptr;
			}
			else
			{
				// We want an unregistered class, the supplied value is also unregistered but it isn't a compatible wrapper.
				let tinkerState = lua.TinkerState;
				{
					// Set error in a different scope to make sure the temporary strings destructors run before throwing the error.
					tinkerState.SetLastError($"can't convert argument {index} to '{GetBestLuaClassName<T>(tinkerState, .. scope .())}'");
				}
				TryThrowError(lua, tinkerState);
				return ref dummy;
			}
		}

		public static T Pop<T>(Lua lua, int32 index) where T : var, class
		{
			if (lua.IsNil(index))
				return null;

			let result = EnsureValidMetaTable<T>(lua, index);

			let stackObject = User2Type.UnsafeGetObject(lua, index);
			if (result != .OkNoMetaTable)
			{
				// We are sure that this conversion is valid, so let's just do it unsafely.
				let ptr = ((PointerWrapperBase)stackObject).Ptr;

				// This is necessary only because PointerWrapper<T> can contain a null pointer
				if (ptr == null)
				{
					let tinkerState = lua.TinkerState;
					tinkerState.SetLastError("null pointer dereference");
					TryThrowError(lua, tinkerState);
					return default;
				}

				return (T)Internal.UnsafeCastToObject(ptr);
			}

			if (let valueWrapper = stackObject as ClassInstanceWrapper<T>)
				return valueWrapper.ClassInstance;
			else if (let refPtrWrapper = stackObject as RefPointerWrapper<T>)
				return refPtrWrapper.Reference;
			else if (let ptrWrapper = stackObject as PointerWrapper<T>)
			{
				if (ptrWrapper.Ptr == null)
				{
					let tinkerState = lua.TinkerState;
					tinkerState.SetLastError("null pointer dereference");
					TryThrowError(lua, tinkerState);
					return default;
				}

				return *ptrWrapper.Ptr;
			}
			else
			{
				// We want an unregistered class, the supplied value is also unregistered but it isn't a compatible wrapper.
				let tinkerState = lua.TinkerState;
				{
					// Set error in a different scope to make sure the temporary strings destructors run before throwing the error.
					tinkerState.SetLastError($"can't convert argument {index} ({lua.TypeName(index)}) to '{GetBestLuaClassName<T>(tinkerState, .. scope .())}'");
				}
				TryThrowError(lua, tinkerState);
				return default;
			}
		}

		public static ref T PopRef<T>(Lua lua, int32 index) where T : var
		{
			static T dummy = default;

			let stackObject = User2Type.GetObject(lua, index);
			if (let refPtrWrapper = stackObject as RefPointerWrapper<T>)
				return ref refPtrWrapper.Reference;
			else if (let ptrWrapper = stackObject as PointerWrapper<T>)
			{
				if (ptrWrapper.Ptr == null)
				{
					let tinkerState = lua.TinkerState;
					tinkerState.SetLastError("null pointer dereference");
					TryThrowError(lua, tinkerState);
					return ref dummy;
				}

				return ref *ptrWrapper.Ptr;
			}
			else
			{
				let tinkerState = lua.TinkerState;
				{
					// Set error in a different scope to make sure the temporary strings destructors run before throwing the error.
					tinkerState.SetLastError($"can't convert argument {index} to 'ref {GetBestLuaClassName<T>(tinkerState, .. scope .())}'");
				}
				TryThrowError(lua, tinkerState);
				return ref dummy;
			}
		}
	}
}
