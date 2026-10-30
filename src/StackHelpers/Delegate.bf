using System;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.Handlers;

using internal KeraLua;
using internal LuaTinker;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpers;

extension StackHelper
{
	[Inline]
	public static int GetDelegateAllocationSize<D>(Lua lua) where D : Delegate
		=> lua.TinkerState.GetDelegateAllocationSize(typeof(D));

	public static bool IsDelegateArgument(Lua lua, int32 index, Type type)
	{
		if (lua.Type(index) == .Function)
			return lua.TinkerState.IsDelegateRegistered(type);
		return lua.IsNil(index) || User2Type.IsObjectTypeCompatible(lua, index, type);
	}

	internal static void SetFunctionPointer(Lua lua, void* key, LuaFunction callHandler)
	{
		if (lua.RawGetByHashCode(LuaRegistry.Index, key) != .Table)
		{
			lua.Pop(1);
			lua.CreateTable(0, 5);
			UserdataMetatables.Mark(lua, -1, .Pointer);
			lua.PushString("__gc");
			lua.PushCClosure(=> PointerDestructorHandler, 0);
			lua.RawSet(-3);
			lua.PushString("__tostring");
			lua.PushCClosure(=> PointerToStringHandler, 0);
			lua.RawSet(-3);
			lua.PushString("__call");
			lua.PushCClosure(callHandler, 0);
			lua.RawSet(-3);
			lua.PushString("__index");
			lua.PushCClosure(=> FunctionPointerIndexGetHandler, 0);
			lua.RawSet(-3);
			lua.PushValue(-1);
			lua.RawSetByHashCode(LuaRegistry.Index, key);
		}
		lua.SetMetaTable(-2);
	}
}
