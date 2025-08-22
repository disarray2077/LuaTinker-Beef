using System;
using System.Collections;
using System.Reflection;

namespace LuaTinker.Wrappers
{
	public sealed class ClassTypeWrapper<T> : PointerWrapperBase
		where T : var, class
	{
		private T mData;

		public ~this()
		{
			delete:append mData;
			mData = null;
		}

		[OnCompile(.TypeInit), Comptime]
		static void Init()
		{
			String emitStr = scope .();

			for (var methodInfo in typeof(T).GetMethods(.Public | .DeclaredOnly))
			{
				if (methodInfo.IsStatic)
					continue;
				if (!methodInfo.IsConstructor)
					continue;

				if (methodInfo.AllowAppendKind == .Yes)
					emitStr.AppendF("[System.AllowAppend]\n");
				if (methodInfo.AllowAppendKind == .ZeroGap)
					emitStr.AppendF("[System.AllowAppend(ZeroGap=true)]\n");
				if (methodInfo.CheckedKind == .Checked)
					emitStr.AppendF("[System.Checked]\n");
				if (methodInfo.CheckedKind == .Unchecked)
					emitStr.AppendF("[System.Unchecked]\n");

				emitStr.AppendF("public this(");
				methodInfo.GetParamsDecl(emitStr);
				emitStr.AppendF(")\n");
				emitStr.AppendF("{{\n");
				emitStr.AppendF("\tvar val = append T(");
				methodInfo.GetArgsList(emitStr);
				emitStr.AppendF(");\n");
				emitStr.AppendF("\tmData = val;\n");
				emitStr.AppendF("\tmPtr = Internal.UnsafeCastToPtr(mData);\n");
				emitStr.AppendF("\tmReadOnlyPtr = true;\n");
				emitStr.AppendF("}}\n");
			}

			Compiler.EmitTypeBody(typeof(Self), emitStr);
		}

		public T ClassInstance
		{
			get => (T)Internal.UnsafeCastToObject(Ptr);
		}

	    public void Create()
			=> mData = .();

	    public void Create<T1>(T1 t1) where T1 : var
			=> mData = .(t1);

	    public void Create<T1, T2>(T1 t1, T2 t2) where T1 : var where T2 : var
			=> mData = .(t1, t2);

	    public void Create<T1, T2, T3>(T1 t1, T2 t2, T3 t3) where T1 : var where T2 : var where T3 : var
			=> mData = .(t1, t2, t3);

	    public void Create<T1, T2, T3, T4>(T1 t1, T2 t2, T3 t3, T4 t4) where T1 : var where T2 : var where T3 : var where T4 : var
			=> mData = .(t1, t2, t3, t4);

	    public void CreateParams<T1>(params Span<T1> t1) where T1 : var
		{
			// This just doesn't work, so we emit instead.
			//InternalSet(new T(params t1));

			[Comptime]
			static void Emit()
			{
				if (typeof(T1).IsGenericParam)
					return;
				Compiler.MixinRoot(scope $"mData = .(params t1);");
			}

			Emit();
		} 

		public override Type Type => typeof(T);

		public override ToObjectResult ToObject(ITypedAllocator allocator, out Object obj)
		{
			obj = ClassInstance;
			return .Object;
		}

		public override void ToString(String strBuffer)
		{
			ClassInstance.ToString(strBuffer);
		}

		public override void OnAddedToLua(LuaTinkerState tinkerState)
		{
			tinkerState.RegisterAliveObject(ClassInstance);
		}

		public override void OnRemovedFromLua(LuaTinkerState tinkerState)
		{
			tinkerState.DeregisterAliveObject(ClassInstance);
		}
	}

	extension ClassTypeWrapper<T>
		where T : class, IDisposable
	{
		public ~this()
		{
			ClassInstance.Dispose();
		}
	}
}
