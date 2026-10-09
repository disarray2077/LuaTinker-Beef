using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal LuaTinker.StackHelpers;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 NamespaceIndexGetHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			if (StackHelper.GetNamespaceBinding(lua) == .UserData)
				User2Type.TryGetTypePtr<VariableWrapperBase>(lua, -1).Get(lua);
			return 1;
		}

		public static int32 NamespaceIndexSetHandler(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
			if (StackHelper.GetNamespaceBinding(lua) == .Nil)
			{
				lua.SetTop(3);
				lua.RawSet(1);
				return 0;
			}
			let field = User2Type.TryGetTypePtr<VariableWrapperBase>(lua, -1);
			// VariableWrapper.Set expects its value at index 2; namespace assignment also supplies a key.
			lua.Remove(2);
			field.Set(lua);
			return 0;
		}
	}
}
