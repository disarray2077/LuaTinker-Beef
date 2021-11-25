using System;
using System.Diagnostics;

namespace LuaTinker.Wrappers
{
	class RefPointerWrapper<T> : PointerWrapperBase
		where T : var
	{
		public ref T Reference
		{
			get => ref *(T*)Ptr;
#unwarn // TODO: Remove this #unwarn when ref setters are available.
			set => Ptr = &value;
		}

		public override Type Type => typeof(T);
	}

	extension RefPointerWrapper<T>
		where T : class
	{
		public new override ToObjectResult ToObject(out Object obj)
		{
			obj = Internal.UnsafeCastToObject(Ptr);
			return .Object;
		}
	}

	extension RefPointerWrapper<T>
		where T : struct
	{
		public new override ToObjectResult ToObject(out Object obj)
		{
			obj = new box Reference;
			return .NewObject;
		}
	}
}