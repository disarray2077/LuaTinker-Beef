using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.StackHelpers;

using internal KeraLua;
using internal LuaTinker.StackHelpers;

namespace LuaTinker
{
	public enum LuaUserdataKind : uint8
	{
		Pointer,
		Variable,
		Indexer
	}

	public struct LuaUserdataAllocator : IRawAllocator
	{
		private struct Header
		{
			public int32 Offset;
		}

		private Lua mLua;
		private LuaUserdataKind mKind;

		public this(Lua lua, LuaUserdataKind kind = .Pointer)
		{
			mLua = lua;
			mKind = kind;
		}

		[Inline]
		public void* AllocTyped(Type type, int size, int align)
		{
#if BF_ENABLE_OBJECT_DEBUG_FLAGS
			// COMPILER-BUG: Work around Beef's custom allocation path omitting the required debug append record.
			// Reserve and zero it here; [Friend] is needed because Type has no public query for this flag.
			if (type.[Friend]mTypeFlags.HasFlag(.HasAppendWantMark))
			{
				let appendInfoSize = 4 * sizeof(int);
				let payload = Alloc(size + appendInfoSize, align);
				Internal.MemSet((uint8*)payload + size, 0, appendInfoSize);
				return payload;
			}
#endif
			return Alloc(size, align);
		}

		[Inline]
		public void* Alloc(int size, int align)
		{
			Debug.Assert(size >= 0 && align > 0 && size <= int32.MaxValue - sizeof(Header) - align);
			let basePtr = (uint8*)mLua.NewUserData((.) (size + sizeof(Header) + align - 1));
			let payload = (void*)(int)Math.Align((int64)(int)(void*)basePtr + sizeof(Header), (int64)align);
			let header = (Header*)basePtr;
			header.Offset = (int32)((uint8*)payload - basePtr);
			UserdataMetatables.PushFamily(mLua, mKind);
			mLua.SetMetaTable(-2);
			return payload;
		}

		public static bool TryGetPayload(Lua lua, int32 index, LuaUserdataKind expectedKind, out void* payload)
		{
			payload = null;
			if (!UserdataMetatables.IsKind(lua, index, expectedKind))
				return false;
			let basePtr = (uint8*)lua.ToUserData(index);
			let header = (Header*)basePtr;
			payload = basePtr + header.Offset;
			return true;
		}

		public void Free(void* ptr)
		{
			Runtime.FatalError("This pointer is managed by Lua!");
		}
	}
}
