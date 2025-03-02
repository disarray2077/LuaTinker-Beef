using System;

namespace LuaTinker.Wrappers
{
	public sealed class ClassInstanceWrapper<T> : PointerWrapperBase
		where T : var, class
	{
		public bool OwnsPointer { get; private set; }

		public this()
		{
		}

		public this(T instance, bool giveOwnership = false)
		{
			ClassInstance = instance;
			OwnsPointer = giveOwnership;
		}

	    public ~this()
		{
			if (OwnsPointer)
				delete ClassInstance;
		}

		public T ClassInstance
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
			ClassInstance = obj;
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

		public override ToObjectResult ToObject(ITypedAllocator allocator, out Object obj)
		{
			obj = ClassInstance;
			return .Object;
		}
	}

	extension ClassInstanceWrapper<T>
		where T : class, IDisposable
	{
		public ~this()
		{
			if (OwnsPointer)
				ClassInstance.Dispose();
		}
	}
}
