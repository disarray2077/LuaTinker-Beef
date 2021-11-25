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
			Object obj = ?;
			if (lua.IsUserData(index))
			{
				let wrapper = User2Type.UnsafeGetTypePtr<PointerWrapperBase>(lua, index);
				switch (wrapper.ToObject(out obj))
				{
				case .Object:
					// no need to do anything
				case .NewObject:
					defer:mixin delete obj;
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
						obj = scope:mixin box i;
					else if (let n = lua.ToNumberX(index))
						obj = scope:mixin box n;
					else
					{
						// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
						lua.PushString($"can't convert argument {index} to 'System.Object'");
						lua.Error();
					}
				case .Boolean:
					obj = scope:mixin box Pop<bool>(lua, index);
				case .String:
					obj = scope:mixin box Pop<StringView>(lua, index);
				case .Nil:
					obj = null;
				default:
					// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
					lua.PushString($"can't convert argument {index} to 'System.Object'");
					lua.Error();
				}
			}
			obj
		}

		public static mixin Pop<T>(Lua lua, int32 index)
			where T : String
		{
			String str;
			if (lua.IsUserData(index))
			{
				let wrapper = User2Type.GetTypePtr<ClassPointerWrapper<T>>(lua, index);
				str = (String)Internal.UnsafeCastToObject(wrapper.[Friend]mPtr);
			}
			else
			{
				str = scope:mixin String()..Reference(Pop<T>(lua, index));
			}
			str
		}
	}
}
