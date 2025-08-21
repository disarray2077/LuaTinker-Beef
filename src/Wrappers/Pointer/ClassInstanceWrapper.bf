using System;
using System.Collections;
using System.Reflection;

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
		
		/*
		public static void GetParamsDecl(MethodInfo methodInfo, String strBuffer)
		{
			int useParamIdx = 0;
			for (int paramIdx < methodInfo.ParamCount)
			{
				var flag = methodInfo.GetParamFlags(paramIdx);
				if (flag.HasFlag(.Implicit))
					continue;
				if (useParamIdx > 0)
					strBuffer.Append(", ");
				if (flag.HasFlag(.Params))
					strBuffer.Append("params ");
				strBuffer.Append("comptype(");
				strBuffer.Append(methodInfo.GetParamType(paramIdx).GetTypeId());
				strBuffer.Append(") ");
				strBuffer.Append(methodInfo.GetParamName(paramIdx));
				useParamIdx++;
			}
		}

		[OnCompile(.TypeInit), Comptime]
		static void Init()
		{
			String emitStr = scope .();

			HashSet<String> foundSigs = scope .();

			for (var methodInfo in typeof(T).GetMethods(.Public | .DeclaredOnly))
			{
				if (methodInfo.IsStatic)
					continue;
				if (!methodInfo.IsConstructor)
					continue;

				var sig = methodInfo.GetMethodSig(.. new .());
				if (!foundSigs.Add(sig))
					continue;

				emitStr.AppendF("public void Create(");
				GetParamsDecl(methodInfo, emitStr);
				emitStr.AppendF(")\n");
				emitStr.AppendF("{{\n");
				emitStr.AppendF("\tInternalSet(new T(");
				methodInfo.GetArgsList(emitStr);
				emitStr.AppendF("));\n}}\n");
			}

			System.Diagnostics.Debug.WriteLine(emitStr);
			Compiler.EmitTypeBody(typeof(Self), emitStr);
		}
		*/

	    public void Create()
			=> InternalSet(new T());

	    public void Create<T1>(T1 t1) where T1 : var
			=> InternalSet(new T(t1));

	    public void Create<T1, T2>(T1 t1, T2 t2) where T1 : var where T2 : var
			=> InternalSet(new T(t1, t2));

	    public void Create<T1, T2, T3>(T1 t1, T2 t2, T3 t3) where T1 : var where T2 : var where T3 : var
			=> InternalSet(new T(t1, t2, t3));

	    public void Create<T1, T2, T3, T4>(T1 t1, T2 t2, T3 t3, T4 t4) where T1 : var where T2 : var where T3 : var where T4 : var
			=> InternalSet(new T(t1, t2, t3, t4));

	    public void CreateParams<T1>(params Span<T1> t1) where T1 : var
		{
			// This just doesn't work, so we emit instead.
			//InternalSet(new T(params t1));

			[Comptime]
			static void Emit()
			{
				if (typeof(T1).IsGenericParam)
					return;
				Compiler.MixinRoot(scope $"InternalSet(new comptype({typeof(T).GetTypeId()})(params t1));");
			}

			Emit();
		} 

		public override Type Type => typeof(T);

		public override ToObjectResult ToObject(ITypedAllocator allocator, out Object obj)
		{
			obj = ClassInstance;
			return .Object;
		}
		

		public override void OnRemoveFromLua(LuaTinkerState tinkerState)
		{
			if (OwnsPointer)
				tinkerState.DeregisterAliveObject(ClassInstance);
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
