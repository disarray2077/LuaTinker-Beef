using System;
using System.Collections;
using System.Reflection;
using LuaTinker.Helpers;

using internal LuaTinker.Handlers;

namespace LuaTinker.Handlers
{
	static
	{
		public enum LuaParameterMode : int8
		{
			Value,
			Ref,
			Out
		}

		public enum LuaParameterRole : int8
		{
			Ordinary,
			This,
			Variadic
		}

		public struct LuaParameter
		{
			public Type DeclaredType;
			public Type DecodedType;
			public LuaParameterMode Mode;
			public int LuaStackIndex;
			public int DiagnosticIndex;
			public Type VariadicElementType;
			public LuaParameterRole Role;

			public bool IsVariadic
			{
				[Inline]
				get => Role == .Variadic;
			}
		}

		private static void AddLuaParameter(List<LuaParameter> parameters, Type declaredType, int stackIndex, int diagnosticIndex, LuaParameterRole role, bool decodeRef = true)
		{
			LuaParameter parameter = .();
			parameter.DeclaredType = declaredType;
			parameter.DecodedType = declaredType;
			parameter.Mode = .Value;
			parameter.LuaStackIndex = stackIndex;
			parameter.DiagnosticIndex = diagnosticIndex;
			parameter.Role = role;
			if (decodeRef && (let refType = declaredType as RefType))
			{
				switch (refType.RefKind)
				{
				case .Ref: parameter.Mode = .Ref;
				case .Out: parameter.Mode = .Out;
				default: Runtime.FatalError(scope $"Not implemented {refType.RefKind}!");
				}
				parameter.DecodedType = refType.UnderlyingType;
			}
			if (parameter.IsVariadic && (let specializedType = parameter.DecodedType as SpecializedGenericType))
			{
				parameter.VariadicElementType = specializedType.GetGenericArg(0);
				parameter.DecodedType = parameter.VariadicElementType;
			}
			parameters.Add(parameter);
		}

		// The same eager records are consumed by the selector and by invocation.
		internal static void NormalizeMethodParameters(MethodInfo method, List<LuaParameter> parameters)
		{
			if (!method.IsStatic)
				AddLuaParameter(parameters, method.DeclaringType, 1, 0, .This);
			for (int i = 0; i < method.ParamCount; i++)
				AddLuaParameter(parameters, method.GetParamType(i), i + (method.IsStatic ? 1 : 2), i + 1,
					method.GetParamFlags(i).HasFlag(.Params) ? .Variadic : .Ordinary);
		}

		internal static void NormalizeConstructorParameters(MethodInfo ctor, List<LuaParameter> parameters, int visibleStart)
		{
			for (int i = visibleStart; i < ctor.ParamCount; i++)
				AddLuaParameter(parameters, ctor.GetParamType(i), 2 + i - visibleStart, i - visibleStart + 1,
					ctor.GetParamFlags(i).HasFlag(.Params) ? .Variadic : .Ordinary, false);
		}

		private static void NormalizeBoundParameters(MethodInfo method, List<LuaParameter> parameters)
		{
			bool hasThisParameter = method.ParamCount > 0 && method.GetParamName(0) == "this";
			for (int i = 0; i < method.ParamCount; i++)
				AddLuaParameter(parameters, method.GetParamType(i), i + 1, i + (hasThisParameter ? 0 : 1),
					hasThisParameter && i == 0 ? .This : (method.GetParamFlags(i).HasFlag(.Params) ? .Variadic : .Ordinary));
		}

		[Comptime]
		internal static void NormalizeDirectConstructorParameters<Args>(List<LuaParameter> parameters)
		{
			// Direct constructor arguments are decoded using their declared types.
			let type = typeof(Args);
			if (type.IsTuple)
			{
				for (let field in type.GetFields(.DeclaredOnly))
					AddLuaParameter(parameters, field.FieldType, @field.Index + 2, @field.Index + 1, .Ordinary, false);
			}
			else if (type != typeof(void))
				AddLuaParameter(parameters, type, 2, 1, .Ordinary, false);
		}
	}
}
