using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		public static mixin PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
			where T : String, class where String : T
		{
			PopString(lua, index, alloc)
		}

		public static mixin Pop<T>(Lua lua, int32 index)
			where T : String, class where String : T
		{
			SingleAllocator alloc = scope:mixin .(96);
			PopString(lua, index, alloc)
		}

		private static String PopString(Lua lua, int32 index, ITypedAllocator alloc)
		{
			let valueType = lua.Type(index);
			if (valueType == .UserData)
			{
				let wrapper = User2Type.GetObject(lua, index) as PointerWrapperBase;
				if (wrapper == null)
					return default;
				if (!wrapper.Type.IsValueType && (wrapper.ToObject(alloc, let obj) case .Object))
				{
					if (let str = obj as String)
						return str;
				}
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert argument {index} to 'String'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			else
			{
				if (let strView = Pop<String>(lua, index))
				{
					let str = new:alloc String();
					// PCall borrows rooted Lua strings; numeric conversion produces an unrooted temporary.
					if (valueType == .String && lua.TinkerState.IsPCall)
						str.Reference(strView);
					else
						str.Append(strView);
					return str;
				}
				else
					return null;
			}
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
			if (result == .Error)
				return null;

			let stackObject = User2Type.GetObject(lua, index);
			if (stackObject == null)
				return null;

			if (result != .OkUnregisteredType)
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
