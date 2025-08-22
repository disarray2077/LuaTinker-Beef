using System;
using KeraLua;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		public static mixin Pop<T>(Lua lua, int32 index)
			where T : var
		{
			// pass through
			Pop<T>(lua, index)
		}

		public static mixin PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
			where T : Object where Object : T
		{
			_PopAlloc<T>(lua, index, alloc)
		}

		public static mixin Pop<T>(Lua lua, int32 index)
			where T : Object where Object : T
		{
			SingleAllocator alloc = scope:mixin .(88);
			_PopAlloc<T>(lua, index, alloc)
		}

		private static Object _PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
			where T : Object
		{
			if (lua.IsUserData(index))
			{
				let wrapper = User2Type.UnsafeGetTypePtr<PointerWrapperBase>(lua, index);
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

		public static mixin Pop<T>(Lua lua, int32 index)
			where T : String, class where String : T
		{
			SingleAllocator alloc = scope:mixin .(96);
			_PopAlloc<T>(lua, index, alloc)
		}

		private static String _PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
			where T : String where String : T
		{
			if (lua.IsUserData(index))
			{
				let wrapper = User2Type.GetTypePtr<PointerWrapperBase>(lua, index);
				return (String)Internal.UnsafeCastToObject(wrapper.[Friend]mPtr);
			}
			else
			{
				if (let strView = Pop<T>(lua, index))
					return new:alloc String()..Reference(strView);
				else
					return null;
			}
		}
	}
}
