using System;
using KeraLua;
using LuaTinker.Helpers;

using internal KeraLua;
using internal LuaTinker;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpers;

extension PopDispatch<T> where T : Delegate where IsDelegate<T>.Result : Yes
{
	public new static mixin Pop(Lua lua, int32 index, LuaType? knownType)
	{
		SingleAllocator allocator = scope:mixin .(StackHelper.GetDelegateAllocationSize<T>(lua));
		StackHelper.PopAlloc!<T>(lua, index, allocator)
	}
}

extension StackHelper
{
	[Inline]
	public static int GetDelegateAllocationSize<D>(Lua lua) where D : Delegate
		=> lua.TinkerState.GetDelegateAllocationSize(typeof(D));

	public static mixin PopAlloc<D>(Lua lua, int32 index, ITypedAllocator allocator)
		where D : Delegate
	{
		PopDelegate<D>(lua, index, allocator)
	}

	private static D PopDelegate<D>(Lua lua, int32 index, ITypedAllocator allocator) where D : Delegate
	{
		if (lua.Type(index) != .Function)
			return Pop<D>(lua, index);
		let result = (D)lua.TinkerState.CreateDelegate(typeof(D), lua, index, allocator);
		if (result == null)
			TryThrowError(lua);
		return result;
	}

	public static bool IsDelegateArgument(Lua lua, int32 index, Type type)
	{
		if (lua.Type(index) == .Function)
			return lua.TinkerState.IsDelegateRegistered(type);
		return lua.IsNil(index) || User2Type.IsObjectTypeCompatible(lua, index, type);
	}
}
