using System;
using KeraLua;
using LuaTinker.Wrappers;
using LuaTinker.Helpers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	// PopDispatch works around a limitation in Beef: conditional generic constraints work reliably for types, but not individual methods.
	// Placing Run on a generic type lets us use a conditional type extension to replace its implementation.
	internal static struct PopDispatch<T> where T : var
	{
		public static mixin Pop(Lua lua, int32 index)
		{
			StackHelper.Pop<T>(lua, index)
		}

		public static mixin PopHinted(Lua lua, int32 index)
		{
			StackHelper.PopHinted<T>(lua, index)
		}
	}

	extension PopDispatch<T> where T : var, struct* where IsNumericPointer<T>.Result : Yes
	{
		public new static mixin PopHinted(Lua lua, int32 index)
		{
			T result = default;
			if (lua.Type(index) == .Number)
			{
				// The pointee must survive until the enclosing binding call completes.
				RemovePtr<T>[] temporary = scope:mixin RemovePtr<T>[1](?);
				temporary[0] = StackHelper.Pop<RemovePtr<T>>(lua, index);
				result = (T)temporary.Ptr;
			}
			else
				result = StackHelper.PopHinted<T>(lua, index);
			result
		}
	}

	extension StackHelper
	{
		public static mixin Pop<T>(Lua lua, int32 index)
			where T : var
		{
			// Friend lets this public mixin use the internal dispatch type in the caller's scope.
#unwarn
			([Friend]PopDispatch<T>.Pop!:mixin(lua, index))
		}

		public static mixin PopHinted<T>(Lua lua, int32 index)
			where T : var
		{
			// Friend lets this public mixin use the internal dispatch type in the caller's scope.
#unwarn
			([Friend]PopDispatch<T>.PopHinted!:mixin(lua, index))
		}
	}
}
