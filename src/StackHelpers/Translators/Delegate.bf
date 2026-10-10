using System;
using KeraLua;
using LuaTinker.Helpers;

using internal KeraLua;
using internal LuaTinker;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpers;

extension PopDispatch<T> where T : Delegate where IsDelegate<T>.Result : Yes
{
	public new static mixin Pop(Lua lua, int32 index)
	{
		SingleAllocator allocator = scope:mixin .(StackHelper.GetDelegateAllocationSize<T>(lua));
		StackHelper.PopAlloc!<T>(lua, index, allocator)
	}
}

extension StackHelper
{
	public static mixin PopAlloc<D>(Lua lua, int32 index, ITypedAllocator allocator)
		where D : Delegate
	{
		PopDelegate<D>(lua, index, allocator)
	}

	private static D PopDelegate<D>(Lua lua, int32 index, ITypedAllocator allocator)
		where D : Delegate
	{
		if (lua.Type(index) != .Function)
			return Pop<D>(lua, index);
		let result = (D)lua.TinkerState.CreateDelegate(typeof(D), lua, index, allocator);
		if (result == null)
			TryThrowError(lua);
		return result;
	}
}
