using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 OwnedValueConstructorHandler<T>(lua_State L) where T : var, struct, INumeric
		{
			let lua = Lua.FromIntPtr(L);
			if (lua.GetTop() != 1 || lua.Type(1) != .Number || !StackHelper.IsNumericArgument(lua, 1, typeof(T)))
			{
				lua.TinkerState.SetLastError("owned value constructor expects one compatible numeric value");
				StackHelper.TryThrowError(lua, lua.TinkerState);
				return 0;
			}

			let initialValue = StackHelper.Pop<T>(lua, 1);
			let alloc = LuaUserdataAllocator(lua);
			let wrapper = new:alloc ValueTypeWrapper<T>();
			*wrapper.ValuePointer = initialValue;
			lua.TinkerState.RegisterAliveObject(wrapper);
			lua.PushValue(Lua.UpValueIndex(1));
			lua.SetMetaTable(-2);
			return 1;
		}
	}
}
