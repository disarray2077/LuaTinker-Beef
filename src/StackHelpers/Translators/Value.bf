using System;
using KeraLua;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		private struct ValueWrapperTypes : this(Type Value, Type Reference, Type Pointer);

		[Inline]
		public static ref T Pop<T>(Lua lua, int32 index) where T : var, struct
		{
			static ValueWrapperTypes wrappers = .(
				typeof(ValueTypeWrapper<T>), typeof(RefPointerWrapper<T>), typeof(PointerWrapper<T>));
			let ptr = PopValue(lua, index, typeof(T), ref wrappers);
			if (ptr == null)
			{
				static T dummy = default;
				return ref dummy;
			}
			return ref *(T*)ptr;
		}

		private static void* PopValue(Lua lua, int32 index, Type expectedType, ref ValueWrapperTypes wrappers)
		{
			if (lua.IsNil(index))
			{
				SetValueConversionError(lua, index, expectedType);
				return null;
			}
			let result = EnsureValidMetaTable(lua, index, expectedType);
			if (result == .Error)
				return null;
			let wrapper = User2Type.GetObject(lua, index) as PointerWrapperBase;
			if (wrapper == null)
				return null;
			if (result != .OkUnregisteredType)
				return RequireValuePointer(lua, wrapper.Ptr);

			// All three wrapper classes are sealed; retain exact closed-type matching.
			let wrapperType = wrapper.GetType();
			if (wrapperType == wrappers.Value || wrapperType == wrappers.Reference)
				return wrapper.Ptr;
			if (wrapperType == wrappers.Pointer)
				return RequireValuePointer(lua, wrapper.Ptr);
			SetValueConversionError(lua, index, expectedType);
			return null;
		}

		[Inline]
		public static ref T PopRef<T>(Lua lua, int32 index) where T : var
		{
			static ValueWrapperTypes wrappers = .(null, typeof(RefPointerWrapper<T>), typeof(PointerWrapper<T>));
			return ref PopReference<T>(lua, index, ref wrappers);
		}

		[Inline]
		public static ref T PopRef<T>(Lua lua, int32 index) where T : var, struct
		{
			static ValueWrapperTypes wrappers = .(
				typeof(ValueTypeWrapper<T>), typeof(RefPointerWrapper<T>), typeof(PointerWrapper<T>));
			return ref PopReference<T>(lua, index, ref wrappers);
		}

		[Inline]
		private static ref T PopReference<T>(Lua lua, int32 index, ref ValueWrapperTypes wrappers) where T : var
		{
			let ptr = PopReference(lua, index, typeof(T), ref wrappers);
			if (ptr == null)
			{
				static T dummy = default;
				return ref dummy;
			}
			return ref *(T*)ptr;
		}

		private static void* PopReference(Lua lua, int32 index, Type expectedType, ref ValueWrapperTypes wrappers)
		{
			let wrapper = User2Type.GetObject(lua, index) as PointerWrapperBase;
			if (wrapper != null)
			{
				let wrapperType = wrapper.GetType();
				if (wrapperType == wrappers.Value || wrapperType == wrappers.Reference)
					return wrapper.Ptr;
				if (wrapperType == wrappers.Pointer)
					return RequireValuePointer(lua, wrapper.Ptr);
			}
			SetValueConversionError(lua, index, expectedType, true);
			return null;
		}

		private static void* RequireValuePointer(Lua lua, void* ptr)
		{
			if (ptr == null)
			{
				lua.TinkerState.SetLastError("null pointer dereference");
				TryThrowError(lua);
			}
			return ptr;
		}

		private static void SetValueConversionError(Lua lua, int32 index, Type expectedType, bool isReference = false)
		{
			let state = lua.TinkerState;
			{
				// Dispose the temporary type-name string before raising a Lua error.
				state.SetLastError($"can't convert argument {index} to '{isReference ? "ref " : ""}{GetBestLuaClassName(state, expectedType, .. scope .())}'");
			}
			TryThrowError(lua, state);
		}
	}
}
