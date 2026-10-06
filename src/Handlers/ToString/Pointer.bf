using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 PointerToStringHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			let obj = User2Type.TryGetTypePtr<PointerWrapperBase>(lua, 1);
			if (obj == null)
			{
				lua.TinkerState.SetLastError($"can't convert argument 1 ({lua.TypeName(1)}) to 'String'. (not a LuaTinker object.)");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}

			StackHelper.Push(lua, obj.ToString(.. scope .()));

			return 1;
		}
	}
}
