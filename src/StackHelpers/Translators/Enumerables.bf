using System;
using System.Diagnostics;
using KeraLua;
using System.Collections;
using LuaTinker.Wrappers;
using internal KeraLua;
using LuaTinker.StackHelpers;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpersStackHelpers
{
	extension StackHelper
	{
		public static int32 Iterator<T>(lua_State L)
			where T : var
		{
			let lua = Lua.FromIntPtr(L);

			// Push creates this upvalue via Type2User.Create<decltype(val)>, allocating ValueTypeWrapper<T>.
			let wrapper = User2Type.TryGetTrustedTypePtr<ValueTypeWrapper<T>>(lua, Lua.UpValueIndex(1));
			if (wrapper == null)
			{
				lua.TinkerState.SetLastError("can't advance iterator. (not a LuaTinker object.)");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}
			var iter = ref *wrapper.ValuePointer;

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
