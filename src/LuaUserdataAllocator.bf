using System;
using System.Diagnostics;
using KeraLua;

using internal KeraLua;

namespace LuaTinker
{
	public struct LuaUserdataAllocator : IRawAllocator
	{
		private Lua mLua;

		public this(Lua lua)
		{
			mLua = lua;
		}

		[Inline]
		public void* Alloc(int size, int align)
		{
			Debug.Assert(size <= int32.MaxValue);
			return mLua.NewUserData((.)Math.Align(size, align));
		}

		public void Free(void* ptr)
		{
			Runtime.FatalError("This pointer is managed by Lua!");
		}
	}
}
