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
			=> PopClass<T>(lua, index);

		[Inline]
		private static T PopClass<T>(Lua lua, int32 index) where T : var, class
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
			if (expectedType.IsInterface)
			{
				let instance = User2Type.TryGetClassInstance(lua, index);
				if (instance != null && instance.GetType().ImplementsInterface(expectedType))
					return instance;
				SetValueConversionError(lua, index, expectedType);
				return null;
			}
			let result = EnsureValidMetaTable(lua, index, expectedType);
			if (result == .Error)
				return null;
			let wrapper = User2Type.GetObject(lua, index) as PointerWrapperBase;
			if (wrapper == null)
				return null;

			let wrapperType = wrapper.GetType();
			// Unregistered classes require a wrapper specialized for the requested type.
			if (result != .OkUnregisteredType || wrapperType == wrappers.Instance || wrapperType == wrappers.Owned ||
				wrapperType == wrappers.Reference || wrapperType == wrappers.Pointer)
			{
				if (RequireValuePointer(lua, wrapper.Ptr) == null)
					return null;
				return User2Type.TryGetClassInstance(wrapper);
			}
			let state = lua.TinkerState;
			state.SetLastError($"can't convert argument {index} ({lua.TypeName(index)}) to '{GetBestLuaClassName(state, expectedType)}'");
			TryThrowError(lua, state);
			return null;
		}
	}
}
