using System.Diagnostics;
using System;

namespace LuaTinker.Wrappers
{
	public class PointerWrapperBase
	{
		public enum ToObjectResult
		{
			Object,
			NewObject,
			Error
		}

	    public ~this()
		{
		}

		public void* Ptr
		{
			get => mPtr;
			protected set
			{
				Debug.Assert(mPtr == null);
				mPtr = value;
			}
		}

		public virtual Type Type => null;

		public virtual ToObjectResult ToObject(ITypedAllocator allocator, out Object obj)
		{
			obj = null;
			return .Error;
		}

	    private void* mPtr;
	}
}
