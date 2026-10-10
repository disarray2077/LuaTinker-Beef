using System;
using KeraLua;
using LuaTinker.Wrappers;
using LuaTinker.Helpers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	// PopDispatch works around a limitation in Beef: conditional generic constraints work reliably for types, but not individual methods.
	// Placing Run on a generic type lets us use a conditional type extension to replace its implementation.
	internal struct PopDispatch<T> where T : var
	{
		public static mixin Pop(Lua lua, int32 index)
		{
			StackHelper.Pop<T>(lua, index)
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
	}
}
