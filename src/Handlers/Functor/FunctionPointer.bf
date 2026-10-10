using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker.Handlers;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 FunctionPointerIndexGetHandler<F>(lua_State L) where F : var, struct
		{
			let lua = Lua.FromIntPtr(L);
			if (lua.Type(2) != .String || lua.ToStringView(2) != "IsNull")
			{
				lua.PushNil();
				return 1;
			}
			let wrapper = User2Type.TryGetTypePtr<ValueTypeWrapper<F>>(lua, 1);
			if (wrapper == null)
			{
				lua.TinkerState.SetLastError("can't get function pointer property. (not a LuaTinker object.)");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}
#unwarn
			lua.PushBoolean(*wrapper.ValuePointer == null);
			return 1;
		}

		public static int32 FunctionPointerCallHandler<F>(lua_State L) where F : var, struct
		{
			let lua = Lua.FromIntPtr(L);
			let wrapper = User2Type.TryGetTypePtr<ValueTypeWrapper<F>>(lua, 1);
			if (wrapper == null)
			{
				lua.TinkerState.SetLastError("can't call function. (not a LuaTinker object.)");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}
#unwarn
			let func = *wrapper.ValuePointer;
			if (func == null)
			{
				lua.TinkerState.SetLastError("can't call null function pointer");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}
			lua.Remove(1);

			EmitCallHandler<F>();
			
			// This is necessary to avoid the "Method must return" error
			Runtime.FatalError("Not reached");
		}
	}
}
