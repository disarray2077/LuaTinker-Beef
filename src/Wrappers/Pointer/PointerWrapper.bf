using System;
using System.Diagnostics;

namespace LuaTinker.Wrappers
{
	public sealed class PointerWrapper<T> : PointerWrapperBase
		where T : var
	{
		public new T* Ptr
		{
			get => (T*)base.Ptr;
			set => base.Ptr = value;
		}

		public override Type Type => typeof(T);

		public override ToObjectResult ToObject(out Object obj)
		{
			obj = null;
			return .Error;
		}
	}
}