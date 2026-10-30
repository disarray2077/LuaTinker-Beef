using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		public static mixin PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
			where T : String, class where String : T
		{
			PopString(lua, index, alloc)
		}

		public static mixin Pop<T>(Lua lua, int32 index)
			where T : String, class where String : T
		{
			SingleAllocator alloc = scope:mixin .(96);
			PopString(lua, index, alloc)
		}

		private static String PopString(Lua lua, int32 index, ITypedAllocator alloc)
		{
			let valueType = lua.Type(index);
			if (valueType == .UserData)
			{
				let wrapper = User2Type.GetObject(lua, index) as PointerWrapperBase;
				if (wrapper == null)
					return default;
				if (let str = User2Type.TryGetClassInstance(wrapper) as String)
					return str;
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert argument {index} to 'String'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			else
			{
				if (let strView = Pop<String>(lua, index))
				{
					let str = new:alloc String();
					// PCall borrows rooted Lua strings; numeric conversion produces an unrooted temporary.
					if (valueType == .String && lua.TinkerState.IsPCall)
						str.Reference(strView);
					else
						str.Append(strView);
					return str;
				}
				else
					return null;
			}
		}

		[Inline]
		public static void Push(Lua lua, StringBuilder val)
		{
			StackHelper.Push<StringBuilder>(lua, val);
		}

		[Inline]
		public static StringBuilder Pop<T>(Lua lua, int32 index)
			where T : class, StringBuilder where StringBuilder : T
			=> PopClass<StringBuilder>(lua, index);
	}
}
