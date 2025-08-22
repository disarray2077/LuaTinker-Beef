using System;
using KeraLua;
using LuaTinker.Wrappers;

namespace LuaTinker.StackHelpers
{
	public struct Type2User
	{
		// value to lua
		public static void Create<T>(Lua lua, T val) where T : struct
		{
			let alloc = LuaUserdataAllocator(lua);
			let wrapper = new:alloc ValueTypeWrapper<T>();
			(*wrapper.ValuePointer) = val;
		}

		// class to lua
		public static void Create<T>(Lua lua, T val) where T : class
		{
			if (val == null)
			{
				lua.PushNil();
				return;
			}
			let alloc = LuaUserdataAllocator(lua);
			let wrapper = new:alloc ClassInstanceWrapper<T>(); // TODO: Use ClassTypeWrapper (Type2User will need some refactoring)
			wrapper.ClassInstance = val;
		}

		// ref to lua
		public static void Create<T>(Lua lua, ref T val) where T : var
		{
			let alloc = LuaUserdataAllocator(lua);
			let wrapper = new:alloc RefPointerWrapper<T>();
			wrapper.Reference = ref val;
		}

		// ptr to lua
		public static void Create<T>(Lua lua, T* val) where T : var
		{
			if (val == null)
			{
				lua.PushNil();
				return;
			}
			let alloc = LuaUserdataAllocator(lua);
			let wrapper = new:alloc PointerWrapper<T>();
			wrapper.Ptr = val;
		}
	}
}
