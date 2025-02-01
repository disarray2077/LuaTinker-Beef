using System;
using KeraLua;
using LuaTinker.Wrappers;

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
					// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
					lua.PushString($"can't convert argument {index} to 'System.Object'");
					lua.Error();
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
						// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
						lua.PushString($"can't convert argument {index} to 'System.Object'");
						lua.Error();
					}
				case .Boolean:
					return new:alloc box Pop<bool>(lua, index);
				case .String:
					return new:alloc box Pop<StringView>(lua, index);
				case .Nil:
					return null;
				default:
					// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
					lua.PushString($"can't convert argument {index} to 'System.Object'");
					lua.Error();
				}
			}
		}

		public static mixin Pop<T>(Lua lua, int32 index)
			where T : String, class
		{
			SingleAllocator alloc = scope:mixin .(96);
			_PopAlloc<T>(lua, index, alloc)
		}

		private static String _PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
			where T : String
		{
			if (lua.IsUserData(index))
			{
				let wrapper = User2Type.GetTypePtr<ClassInstanceWrapper<T>>(lua, index);
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
