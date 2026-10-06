using System;
using KeraLua;
using System.Diagnostics;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpers
{
	public struct User2Type
	{
		[Inline]
		internal static bool IsLuaTinkerPointerUserdata(Lua lua, int32 index)
			=> UserdataMetatables.IsKind(lua, index, .Pointer);

		/// Decodes LuaTinker-owned, pointer-sized function values stored as light userdata.
		internal static T GetLightUserDataValue<T>(Lua lua, int32 index) where T : var, struct
		{
			if (sizeof(T) > sizeof(void*))
				Runtime.FatalError(scope $"Light userdata value {typeof(T)} is {sizeof(T)} bytes (pointer: {sizeof(void*)})");
			if (lua.Type(index) != .LightUserData)
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"expected 'LightUserData' but got '{lua.TypeName(index)}'");
				StackHelper.TryThrowError(lua, luaTinker);
				return default;
			}
			var ptr = lua.ToUserData(index);
			return *((T*)&ptr);
		}

		public static Object GetObject(Lua lua, int32 index)
		{
			if (!LuaUserdataAllocator.TryGetPayload(lua, index, .Pointer, let ptr))
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert argument {index} ({lua.TypeName(index)}) to 'LuaTinker object'");
				StackHelper.TryThrowError(lua, luaTinker);
				return default;
			}
			return Internal.UnsafeCastToObject(ptr);
		}

		public static Type GetObjectType(Lua lua, int32 index)
		{
			if (!LuaUserdataAllocator.TryGetPayload(lua, index, .Pointer, let ptr))
				return null;
			Object object = Internal.UnsafeCastToObject(ptr);
			if (let wrapper = object as PointerWrapperBase)
				return wrapper.Type;
			return object.GetType();
		}

		public static bool IsObjectTypeCompatible(Lua lua, int32 index, Type expectedType)
		{
			if (lua.TinkerState.IsClassRegistered(expectedType))
				return StackHelper.ValidateClassMetatable(lua, index, expectedType) != .Error;
			let actualType = GetObjectType(lua, index);
			return actualType != null && actualType.IsSubtypeOf(expectedType);
		}

		private static T TryGetTypePtr<T>(Lua lua, int32 index, LuaUserdataKind kind) where T : class
		{
			if (!LuaUserdataAllocator.TryGetPayload(lua, index, kind, let ptr))
				return null;
			return Internal.UnsafeCastToObject(ptr) as T;
		}

		[Inline]
		public static T TryGetTypePtr<T>(Lua lua, int32 index) where T : PointerWrapperBase
			=> TryGetTypePtr<T>(lua, index, .Pointer);

		/// The validated Pointer metatable kind guarantees this exact family base.
		[Inline]
		public static T TryGetTypePtr<T>(Lua lua, int32 index) where T : PointerWrapperBase where PointerWrapperBase : T
			=> TryGetTrustedTypePtr<T>(lua, index, .Pointer);

		[Inline]
		public static T TryGetTypePtr<T>(Lua lua, int32 index) where T : VariableWrapperBase
			=> TryGetTypePtr<T>(lua, index, .Variable);

		/// The validated Variable metatable kind guarantees this exact family base.
		[Inline]
		public static T TryGetTypePtr<T>(Lua lua, int32 index) where T : VariableWrapperBase where VariableWrapperBase : T
			=> TryGetTrustedTypePtr<T>(lua, index, .Variable);

		[Inline]
		public static T TryGetTypePtr<T>(Lua lua, int32 index) where T : IndexerWrapperBase
			=> TryGetTypePtr<T>(lua, index, .Indexer);

		/// The validated Indexer metatable kind guarantees this exact family base.
		[Inline]
		public static T TryGetTypePtr<T>(Lua lua, int32 index) where T : IndexerWrapperBase where IndexerWrapperBase : T
			=> TryGetTrustedTypePtr<T>(lua, index, .Indexer);

		/// Callers guarantee the concrete wrapper by construction, or request its validated family base.
		/// Deliberate metatable/upvalue tampering is outside this helper's threat model.
		internal static T TryGetTrustedTypePtr<T>(Lua lua, int32 index, LuaUserdataKind kind) where T : class
		{
			if (!LuaUserdataAllocator.TryGetPayload(lua, index, kind, let ptr))
				return null;
			let obj = Internal.UnsafeCastToObject(ptr);
#if DEBUG
			let wrapper = obj as T;
			if (wrapper == null)
				Runtime.FatalError("Trusted LuaTinker userdata has an unexpected wrapper type");
			return wrapper;
#else
			return (T)obj;
#endif
		}

		/// Pointer kind validates the family; callers guarantee any concrete subtype by construction.
		[Inline]
		internal static T TryGetTrustedTypePtr<T>(Lua lua, int32 index) where T : PointerWrapperBase
			=> TryGetTrustedTypePtr<T>(lua, index, .Pointer);

		/// Variable kind validates the family; callers guarantee any concrete subtype by construction.
		[Inline]
		internal static T TryGetTrustedTypePtr<T>(Lua lua, int32 index) where T : VariableWrapperBase
			=> TryGetTrustedTypePtr<T>(lua, index, .Variable);

		/// Indexer kind validates the family; callers guarantee any concrete subtype by construction.
		[Inline]
		internal static T TryGetTrustedTypePtr<T>(Lua lua, int32 index) where T : IndexerWrapperBase
			=> TryGetTrustedTypePtr<T>(lua, index, .Indexer);


	}
}
