using System;
using System.Diagnostics;

namespace LuaTinker.Wrappers
{
	class ValuePointerWrapper<T> : PointerWrapperBase
		where T : var, struct
	{
	    public ~this()
		{
			delete ValuePointer;
		}

		public T* ValuePointer => (T*)Ptr;

		public void CreateUninitialized()
			=> base.Ptr = (.)new uint8[typeof(T).Size]* (?);

	    public void Create()
			=> base.Ptr = new T();

	    public void Create<T1>(T1 t1) where T1 : var
			=> base.Ptr = new T(t1);

	    public void Create<T1, T2>(T1 t1, T2 t2) where T1 : var where T2 : var
			=> base.Ptr = new T(t1, t2);

	    public void Create<T1, T2, T3>(T1 t1, T2 t2, T3 t3) where T1 : var where T2 : var where T3 : var
			=> base.Ptr = new T(t1, t2, t3);

		public override Type Type => typeof(T);

		public override ToObjectResult ToObject(out Object obj)
		{
			obj = new box *ValuePointer;
			return .NewObject;
		}
	}

	extension ValuePointerWrapper<T>
		where T : struct, IDisposable
	{
		public ~this()
		{
			ValuePointer.Dispose();
		}
	}
}
