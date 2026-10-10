using System;
using KeraLua;
using LuaTinker.Helpers;

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
}
