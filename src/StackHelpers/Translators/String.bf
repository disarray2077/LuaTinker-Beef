using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		[Inline]
		public static void Push(Lua lua, String val)
		{
			lua.PushString(val);
		}

		public static StringView? Pop<T>(Lua lua, int32 index)
			where T : class, String where String : T
		{
			if (lua.IsNil(index))
			{
				return null;
			}
			else if (!lua.IsStringOrNumber(index))
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"expected 'String' but got '{lua.TypeName(index)}'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			return lua.ToStringView(index);
		}

		[Inline]
		public static void Push(Lua lua, StringBuilder val)
		{
			StackHelper.Push<StringBuilder>(lua, val);
		}

		public static StringBuilder Pop<T>(Lua lua, int32 index)
			where T : class, StringBuilder where StringBuilder : T
		{
			if (lua.IsNil(index))
				return null;

			let result = EnsureValidMetaTable<StringBuilder>(lua, index);

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

				return (StringBuilder)Internal.UnsafeCastToObject(ptr);
			}

			if (let valueWrapper = stackObject as ClassInstanceWrapper<StringBuilder>)
				return valueWrapper.ClassInstance;
			else if (let refPtrWrapper = stackObject as RefPointerWrapper<StringBuilder>)
				return refPtrWrapper.Reference;
			else if (let ptrWrapper = stackObject as PointerWrapper<StringBuilder>)
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
					tinkerState.SetLastError($"can't convert argument {index} ({lua.TypeName(index)}) to '{GetBestLuaClassName<StringBuilder>(tinkerState, .. scope .())}'");
				}
				TryThrowError(lua, tinkerState);
				return default;
			}
		}
	}
}
