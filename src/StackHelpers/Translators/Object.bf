using System;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpers;

extension StackHelper
{
	public static mixin PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
		where T : Object where Object : T
	{
		PopObject(lua, index, alloc)
	}

	public static mixin Pop<T>(Lua lua, int32 index)
		where T : Object where Object : T
	{
		SingleAllocator alloc = scope:mixin .(88);
		PopObject(lua, index, alloc)
	}

	private static Object PopObject(Lua lua, int32 index, ITypedAllocator alloc)
	{
		if (!EnsureNotArgumentHint(lua, index))
			return default;
		if (lua.IsUserData(index))
		{
			let wrapper = User2Type.GetObject(lua, index) as PointerWrapperBase;
			if (wrapper == null)
				return default;
			switch (wrapper.ToObject(alloc, let obj))
			{
			case .Object, .NewObject:
				return obj;
			case .Error:
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert argument {index} to 'System.Object'");
				TryThrowError(lua, luaTinker);
				return default;
			}
		}
		else
		{
			switch (lua.Type(index))
			{
			case .Number:
				if (let i = lua.ToIntegerX(index))
					return new:alloc box i;
				else if (let n = lua.ToNumberX(index))
					return new:alloc box n;
				else
				{
					let luaTinker = lua.TinkerState;
					luaTinker.SetLastError($"can't convert argument {index} to 'System.Object'");
					TryThrowError(lua, luaTinker);
					return default;
				}
			case .Boolean:
				return new:alloc box Pop<bool>(lua, index);
			case .String:
				return new:alloc box Pop<StringView>(lua, index);
			case .Table:
				return new:alloc box Pop<LuaTable>(lua, index);
			case .Nil:
				return null;
			default:
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert argument {index} to 'System.Object'");
				TryThrowError(lua, luaTinker);
				return default;
			}
		}
	}
}
