using System;
using System.Diagnostics;
using System.Collections;
using System.Reflection;
using KeraLua;
using LuaTinker.Layers;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		/*private static void AddContainerMate<T>(Lua lua)
			where T : var
		{
			String name = scope $"container_{typeof(T).TypeId}";
			ClassName<T>.Name = name;

			lua.CreateTable(0, 8);

			lua.PushString("__name");
			lua.PushString(name);
			lua.RawSet(-3);

			// TODO
			/*lua.PushString("__index");
			lua.PushCClosure(=> MetaContainerGetLayer<T>, 0);
			lua.RawSet(-3);

			lua.PushString("__newindex");
			lua.PushCClosure(detail::meta_container_set<base_type<T>>, 0);
			lua.RawSet(-3);

			lua.PushString("__pairs");
			lua.PushCClosure(detail::meta_container_make_range<base_type<T>>, 0);
			lua.RawSet(-3);

			lua.PushString("__len");
			lua.PushCClosure(detail::meta_container_get_len<base_type<T>>, 0);
			lua.RawSet(-3);

			lua.PushString("to_table");
			lua.PushCClosure(detail::meta_container_to_table<base_type<T>>, 0);
			lua.RawSet(-3);

			lua.PushString("push");
			lua.PushCClosure(detail::meta_container_push<base_type<T>>, 0);
			lua.RawSet(-3);

			lua.PushString("erase");
			lua.PushCClosure(detail::meta_container_erase<base_type<T>>, 0);
			lua.RawSet(-3);*/

			lua.PushString("__gc");
			lua.PushCClosure(=> DataDestroyerLayer, 0);
			lua.RawSet(-3);

			lua.SetGlobal(name);
		}

		private static void NoRegType2User<T, TVal>(Lua lua, T val)
			where T : ICollection<TVal>
			where TVal : var
		{
			AddContainerMate<T>(lua);
			lua.GetGlobal(ClassName<T>.Name);
			lua.SetMetaTable(-2);
		}*/

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
