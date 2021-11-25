using System;
using System.Diagnostics;
using KeraLua;
using System.Collections;
using LuaTinker.Wrappers;

namespace LuaTinker.StackHelpersStackHelpers
{
	extension StackHelper
	{
		public static int32 Iterator<T>(lua_State L)
			where T : var
		{
			let lua = Lua.FromIntPtr(L);

			var wrapper = User2Type.GetTypePtr<ValuePointerWrapper<T>>(lua, Lua.UpValueIndex(1));
			var iter = ref *wrapper.ValuePointer;//ref User2Type<T>.GetTypeRef(lua, Lua.UpValueIndex(1));

			let result = iter.GetNext();
			if (result case .Err)
				lua.PushNil();
			else
				StackHelper.Push(lua, result.Get());
			return 1;
		}

		public static void Push<T>(Lua lua, List<T>.Enumerator val)
			//where T : IEnumerator<TItem> // TODO/COMPILER-BUG! CRASH!
			//where TItem : var
		{
			Type2User.Create<decltype(val)>(lua, val);
			lua.PushCClosure(=> Iterator<decltype(val)>, 1);
		}
	}
}
