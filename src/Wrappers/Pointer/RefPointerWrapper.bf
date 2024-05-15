using System;
using System.Diagnostics;

namespace LuaTinker.Wrappers
{
	public sealed class RefPointerWrapper<T> : PointerWrapperBase
		where T : var
	{
		public ref T Reference
		{
			get => ref *(T*)Ptr;
			set ref => Ptr = &value;
		}

		public override Type Type => typeof(T);
	}

	extension RefPointerWrapper<T>
		where T : class
	{
		public new override ToObjectResult ToObject(ITypedAllocator allocator, out Object obj)
		{
			obj = Internal.UnsafeCastToObject(Ptr);
			return .Object;
		}
	}

	extension RefPointerWrapper<T>
		where T : struct
	{
		public new override ToObjectResult ToObject(ITypedAllocator allocator, out Object obj)
		{
			obj = new:allocator box Reference;
			return .NewObject;
		}
	}
}