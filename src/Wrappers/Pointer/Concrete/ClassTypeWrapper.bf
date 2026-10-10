using System;
using System.Collections;
using System.Reflection;

namespace LuaTinker.Wrappers
{
	/// Owns a class appended to its Lua userdata allocation.
	public sealed class ClassTypeWrapper<T> : PointerWrapperBase
		where T : var, class
	{
		private T mData;

		// Concrete constructors let Beef calculate the class's append-storage size before allocation.
		[OnCompile(.TypeInit), Comptime]
		static void Init()
		{
			if (typeof(T).IsGenericParam || typeof(T).IsAbstract)
				return;

			let constructors = scope String();
			let signatures = scope HashSet<String>();
			defer { for (let signature in signatures) delete signature; }

			for (let method in typeof(T).GetMethods(.Public | .DeclaredOnly))
			{
				if (!method.IsConstructor || method.IsStatic || method.GenericArgCount != 0)
					continue;

				let signature = scope String();
				let declaration = scope String();
				let arguments = scope String();
				for (int i < method.ParamCount)
				{
					let flags = method.GetParamFlags(i);
					if (flags.HasFlag(.Implicit))
						continue;
					let type = method.GetParamType(i);
					signature.AppendF($"{type.GetTypeId()}:{flags.HasFlag(.Params)};");
					if (!declaration.IsEmpty)
					{
						declaration.Append(", ");
						arguments.Append(", ");
					}
					if (flags.HasFlag(.Params))
					{
						declaration.Append("params ");
						arguments.Append("params ");
					}
					if (let refType = type as RefType)
					{
						switch (refType.RefKind)
						{
						case .Ref:
							declaration.Append("ref ");
							arguments.Append("ref ");
						case .Out:
							declaration.Append("out ");
							arguments.Append("out ");
						case .In:
							declaration.Append("in ");
						case .Mut:
							declaration.Append("mut ");
							arguments.Append("ref ");
						}
					}
					declaration.AppendF($"comptype({type.GetTypeId()}) arg{i}");
					arguments.AppendF($"arg{i}");
				}
				if (signatures.Contains(signature))
					continue;
				signatures.Add(new String(signature));

				// The wrapper appends the class even when its constructor has no append storage.
				constructors.Append("[System.AllowAppend]\n");
				if (method.CheckedKind == .Checked)
					constructors.Append("[System.Checked]\n");
				else if (method.CheckedKind == .Unchecked)
					constructors.Append("[System.Unchecked]\n");
				constructors.Append("public this(");
				constructors.Append(declaration);
				constructors.Append(")\n{\nlet instance = append T(");
				constructors.Append(arguments);
				constructors.Append(");\nmData = instance;\nmPtr = Internal.UnsafeCastToPtr(instance);\nmReadOnlyPtr = true;\n}\n");
			}

			constructors.Append("public ~this()\n{\n");
			if (typeof(T).ImplementsInterface(typeof(IDisposable)))
				constructors.Append("mData.Dispose();\n");
			constructors.Append("delete:append mData;\n}\n");

			Compiler.EmitTypeBody(typeof(Self), constructors);
		}

		[Inline]
		public T ClassInstance => mData;
		[Inline]
		public override Type Type => typeof(T);

		public override bool TryTakeOwnership(LuaTinkerState tinkerState) => true;

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

}
