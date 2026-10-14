using System;
using KeraLua;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		private struct ClassWrapperTypes : this(Type Instance, Type Owned, Type Reference, Type Pointer);

		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, class
		{
			static ClassWrapperTypes wrappers = .(
				typeof(ClassInstanceWrapper<T>), typeof(ClassTypeWrapper<T>),
				typeof(RefPointerWrapper<T>), typeof(PointerWrapper<T>));
			return (T)PopClass(lua, index, typeof(T), ref wrappers);
		}

		private static Object PopClass(Lua lua, int32 index, Type expectedType, ref ClassWrapperTypes wrappers)
		{
			if (lua.IsNil(index))
				return null;
			let result = EnsureValidMetaTable(lua, index, expectedType);
			if (result == .Error)
				return null;
			let wrapper = User2Type.GetObject(lua, index) as PointerWrapperBase;
			if (wrapper == null)
				return null;

			if (result != .OkUnregisteredType)
			{
				if (wrapper.Ptr == null)
				{
					lua.TinkerState.SetLastError("null pointer dereference");
					TryThrowError(lua);
					return null;
				}
				return Internal.UnsafeCastToObject(wrapper.Ptr);
			}
			let wrapperType = wrapper.GetType();
			// These wrapper classes are sealed, so exact type identity preserves the typed casts.
			if (wrapperType == wrappers.Instance || wrapperType == wrappers.Owned)
				return Internal.UnsafeCastToObject(wrapper.Ptr);
			if (wrapperType == wrappers.Reference || wrapperType == wrappers.Pointer)
			{
				if (wrapperType == wrappers.Pointer && wrapper.Ptr == null)
				{
					lua.TinkerState.SetLastError("null pointer dereference");
					TryThrowError(lua);
					return null;
				}
				// Reference and pointer wrappers address an object-reference slot, not the object itself.
				return *(Object*)wrapper.Ptr;
			}
			let state = lua.TinkerState;
			state.SetLastError($"can't convert argument {index} ({lua.TypeName(index)}) to '{GetBestLuaClassName(state, expectedType)}'");
			TryThrowError(lua, state);
			return null;
		}
	}
}
