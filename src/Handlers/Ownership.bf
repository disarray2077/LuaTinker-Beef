using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 TakeOwnershipHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			let wrapper = lua.GetTop() == 1 ? User2Type.TryGetTypePtr<PointerWrapperBase>(lua, 1) : null;
			if (wrapper == null || !wrapper.TryTakeOwnership(lua.TinkerState))
			{
				lua.TinkerState.SetLastError("take_ownership expects one class instance");
				StackHelper.TryThrowError(lua, lua.TinkerState);
				return 0;
			}
			lua.PushValue(1);
			return 1;
		}
	}
}
