using System;

namespace LuaTinker.Helpers;

internal sealed class DelegateHolder<D> where D : Delegate
{
	public const int StorageSize = typeof(D).InstanceSize + (Compiler.Options.AllocStackCount + 2) * sizeof(int) + typeof(D).InstanceAlign - 1;

	private D mCallback;
	private uint8[StorageSize] mDelegateStorage;

	[Inline]
	public D Callback => mCallback;

	private struct DelegateAllocator : IRawAllocator
	{
		public Span<uint8> Storage;
		public void* Alloc(int size, int align)
		{
			let pointer = (uint8*)(void*)(int)Math.Align((int)(void*)Storage.Ptr, align);
			Runtime.Assert(pointer + size <= Storage.Ptr + Storage.Length);
			return pointer;
		}
		[Inline]
		public void Free(void* pointer) { Runtime.FatalError("Delegate storage belongs to its holder"); }
	}

	public void Bind<Target, Method>(Target target) where Target : class where Method : const String
	{
		[Comptime]
		static void EmitDelegateBinding()
		{
			if (typeof(D).IsGenericParam || typeof(Target).IsGenericParam)
				return;
			Compiler.MixinRoot(scope $"""
				DelegateAllocator allocator = .() {{ Storage = mDelegateStorage }};
				comptype({typeof(D).GetTypeId()}) callback = new:allocator => target.{Method};
				mCallback = callback;
				""");
		}
		EmitDelegateBinding();
	}

	public ~this()
	{
		delete:null mCallback;
	}
}
