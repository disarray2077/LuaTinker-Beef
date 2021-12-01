using System;
using System.Diagnostics;

namespace LuaTinker.Wrappers
{
	public sealed class ClassPointerWrapper<T> : PointerWrapperBase
		where T : var, class
	{
		public bool OwnsPointer { get; private set; }

	    public ~this()
		{
			if (OwnsPointer)
				delete ClassPointer;
		}

		public T ClassPointer
		{
			get => (T)Internal.UnsafeCastToObject(Ptr);
			set
			{
				Ptr = Internal.UnsafeCastToPtr(value);
				OwnsPointer = false;
			}
		}

		private void InternalSet(T obj)
		{
			GC.Mark!(obj);
			ClassPointer = obj;
			OwnsPointer = true;
		}

	    public void Create()
			=> InternalSet(new T());

	    public void Create<T1>(T1 t1) where T1 : var
			=> InternalSet(new T(t1));

	    public void Create<T1, T2>(T1 t1, T2 t2) where T1 : var where T2 : var
			=> InternalSet(new T(t1, t2));

	    public void Create<T1, T2, T3>(T1 t1, T2 t2, T3 t3) where T1 : var where T2 : var where T3 : var
			=> InternalSet(new T(t1, t2, t3));

		public override Type Type => typeof(T);

		public override ToObjectResult ToObject(out Object obj)
		{
			obj = ClassPointer;
			return .Object;
		}
	}

	extension ClassPointerWrapper<T>
		where T : class, IDisposable
	{
		public ~this()
		{
			if (OwnsPointer)
				ClassPointer.Dispose();
		}
	}
}
