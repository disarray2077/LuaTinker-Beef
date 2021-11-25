using System;
using System.Diagnostics;
using System.Collections;
using System.Reflection;
using KeraLua;
using LuaTinker.Layers;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;

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

		private static void NoRegType2User<T>(Lua lua)
			where T : struct
		{
			// register destructor
			lua.GetGlobal("__onlygc_meta");
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

		public static void Push<T>(Lua lua, T val) where T : var
		{
			Type2User.Create(lua, val);

			let tinkerState = LuaTinkerState.Find(lua);
			if (!tinkerState.IsClassRegistered<T>())
			{
				NoRegType2User<T>(lua);
			}
			else
			{
				lua.GetGlobal(tinkerState.GetClassName<T>());
				lua.SetMetaTable(-2);
			}
		}

		public static void Push<T>(Lua lua, ref T val) where T : var
		{
			Type2User.Create<T>(lua, ref val);

			let tinkerState = LuaTinkerState.Find(lua);
			if (!tinkerState.IsClassRegistered<T>())
			{
				NoRegType2User<T>(lua);
			}
			else
			{
				lua.GetGlobal(tinkerState.GetClassName<T>());
				lua.SetMetaTable(-2);
			}
		}

		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct*
		{
			return User2Type.GetTypePtr<PointerWrapper<RemovePtr<T>>>(lua, index).Ptr;
		}

		[Inline]
		public static ref T Pop<T>(Lua lua, int32 index) where T : var, struct
		{
			let result = EnsureValidMetaTable<T>(lua, index);

			let stackObject = User2Type.UnsafeGetObject(lua, index);
			if (result != .OkNoMetaTable)
			{
				// We are sure that this conversion is valid, so let's just do it unsafely.
				let ptr = ((PointerWrapperBase)stackObject).Ptr;
				return ref *(T*)ptr;
			}

			if (let valueWrapper = stackObject as ValuePointerWrapper<T>)
				return ref *valueWrapper.ValuePointer;
			else if (let refPtrWrapper = stackObject as RefPointerWrapper<T>)
				return ref refPtrWrapper.Reference;
			else
			{
				// This should never happen.
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				Debug.FatalError("No valid conversion found!");
				lua.PushString("No valid conversion found!");
				lua.Error();
			}
		}

		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, class
		{
			let result = EnsureValidMetaTable<T>(lua, index);

			let stackObject = User2Type.UnsafeGetObject(lua, index);
			if (result != .OkNoMetaTable)
			{
				// We are sure that this conversion is valid, so let's just do it unsafely.
				let ptr = ((PointerWrapperBase)stackObject).Ptr;
				return (T)Internal.UnsafeCastToObject(ptr);
			}

			if (let valueWrapper = stackObject as ClassPointerWrapper<T>)
				return valueWrapper.ClassPointer;
			else if (let refPtrWrapper = stackObject as RefPointerWrapper<T>)
				return refPtrWrapper.Reference;
			else
			{
				// This should never happen.
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				Debug.FatalError("No valid conversion found!");
				lua.PushString("No valid conversion found!");
				lua.Error();
			}
		}

		public static ref T PopRef<T>(Lua lua, int32 index) where T : var
		{
			EnsureValidMetaTable<T>(lua, index);
			return ref User2Type.GetTypePtr<RefPointerWrapper<T>>(lua, index).Reference;
		}
	}
}
