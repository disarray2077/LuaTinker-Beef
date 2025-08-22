using System.Diagnostics;
using System;

namespace LuaTinker.Wrappers
{
	public class PointerWrapperBase : ILuaOwnedObject
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
				Runtime.Assert(!mReadOnlyPtr);
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
		
		public virtual void OnAddedToLua(LuaTinkerState tinkerState) {}
		public virtual void OnRemovedFromLua(LuaTinkerState tinkerState) {}

	    protected void* mPtr;
		protected bool mReadOnlyPtr = false;
	}
}
