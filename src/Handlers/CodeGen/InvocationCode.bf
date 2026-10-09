using System;
using System.Collections;
using System.Diagnostics;
using System.Reflection;
using LuaTinker.Helpers;

using internal LuaTinker.Handlers;

namespace LuaTinker.Handlers
{
	static
	{
		[Inline]
		private static bool IsHintableType(Type type)
			=> IsNumericType(type) || type.IsPointer;

		// This is the sole decision site for converting one Lua argument into a Beef value.
		private static void EmitDecodedArgument(LuaParameter parameter, StringView stackIndex, bool variadicStorage, String code)
		{
			let typeCode = scope $"comptype({parameter.DecodedType.GetTypeId()})";
			if (parameter.Mode != .Value)
			{
				code.Append("ref ");
				code.AppendF($"StackHelper.PopRef<{typeCode}>(lua, {stackIndex})");
			}
			else if (IsHintableType(parameter.DecodedType))
			{
				code.AppendF($"StackHelper.PopHinted<{typeCode}>(lua, {stackIndex})");
			}
			else
			{
				code.AppendF($"StackHelper.Pop!{variadicStorage ? "::" : ""}<{typeCode}>(lua, {stackIndex})");
			}
		}

		private static void EmitVariadicStorage(LuaParameter parameter, bool construction, CodeWriter writer)
		{
			Debug.Assert(parameter.VariadicElementType != null);
			let element = parameter.VariadicElementType;
			let declarationCode = scope $"comptype({element.GetTypeId()})/*{element}*/";

			if (construction)
			{
				writer.Line(scope $"""
					let top = lua.GetTop();
					let extraArgsCount = top >= {parameter.LuaStackIndex} ? top - {parameter.LuaStackIndex} + 1 : 0;
					""");
			}
			else
				writer.Line(scope $"int extraArgsCount = lua.GetTop() - {parameter.LuaStackIndex - 1};");
			writer.Line(scope $"{declarationCode}[] extraArgs = scope {declarationCode}[extraArgsCount] (?);");
			let elementExpression = scope String();
			EmitDecodedArgument(parameter, scope $"i + {parameter.LuaStackIndex}", true, elementExpression);
			writer.ForStatement("for (int32 i = 0; i < extraArgsCount; i++)", scope $"extraArgs[i] = {elementExpression};");
		}

		private static void EmitCallableReturn(Type returnType, bool returnsRef, CodeWriter writer)
		{
			if (returnType == typeof(void))
			{
				writer.Line("return 0;");
				return;
			}
			if (returnType.IsTuple)
			{
				let fieldCount = returnType.FieldCount;
				for (let field in returnType.GetFields(.DeclaredOnly))
				{
					writer.Line(scope $"StackHelper.Push(lua, {(returnsRef ? "ref " : "")}ret.{field.Name});");
				}
				writer.Line(scope $"return {fieldCount};");
			}
			else
			{
				writer.Line(scope $"""
					StackHelper.Push(lua, {(returnsRef ? "ref " : "")}ret);
					return 1;
					""");
			}
		}

		internal static void EmitCallable(MethodInfo method, List<LuaParameter> parameters, int parameterStart, int parameterCount, bool annotateTypes, CodeWriter writer)
		{
			let returnType = method.ReturnType;
			if (parameterCount > 0 && parameters[parameterStart + parameterCount - 1].IsVariadic)
				EmitVariadicStorage(parameters[parameterStart + parameterCount - 1], false, writer);

			let invocation = scope String();
			if (returnType != typeof(void))
			{
				if (annotateTypes)
					invocation.AppendF($"var/*{returnType}*/ ret = ");
				else
					invocation.Append("var ret = ");
			}

			bool returnsRef = false;
			if (let returnRefType = returnType as RefType)
			{
				switch (returnRefType.RefKind)
				{
				case .Ref:
					invocation.Append("ref ");
					returnsRef = true;
				default:
					Runtime.FatalError(scope $"Not implemented {returnRefType.RefKind}!");
				}
			}
			invocation.Append("func(");
			for (let parameter in parameters.GetRange(parameterStart, parameterCount))
			{
				if (parameter.IsVariadic)
					invocation.Append("params extraArgs");
				else
					EmitDecodedArgument(parameter, scope $"{parameter.LuaStackIndex}", false, invocation);
				if (@parameter.Index != parameterCount - 1)
					invocation.Append(", ");
			}
			invocation.Append(");");
			writer.Line(invocation);
			EmitCallableReturn(returnType, returnsRef, writer);
		}

		private static void EmitTypedCall<T>(MethodInfo method, List<LuaParameter> parameters, int parameterStart, int parameterCount, CodeWriter writer)
		{
			let methodParams = scope String();
			for (let parameter in parameters.GetRange(parameterStart, parameterCount))
			{
				if (!methodParams.IsEmpty)
					methodParams.Append(", ");
				if (parameter.Role == .This)
				{
					methodParams.Append("T this");
					continue;
				}
				if (parameter.IsVariadic)
					methodParams.Append("params ");
				if (parameter.Mode == .Ref)
					methodParams.Append("ref ");
				methodParams.AppendF($"comptype({parameter.DeclaredType.GetTypeId()})/*{parameter.DeclaredType}*/");
			}
			writer.Line(scope $"function comptype({method.ReturnType.GetTypeId()})({methodParams}) func = => T.{method.Name};");
			EmitCallable(method, parameters, parameterStart, parameterCount, false, writer);
		}

		[Comptime]
		internal static void EmitBoundCall(MethodInfo method, CodeWriter writer, bool isDelegate)
		{
			List<LuaParameter> parameters = scope .();
			NormalizeBoundParameters(method, parameters);
			if (method.ParamCount == 0)
				writer.Line("Debug.Assert(lua.GetTop() == 0);");
			else
			{
				bool hasThisParameter = parameters[0].Role == .This;
				if (hasThisParameter)
				{
					writer.If("!lua.IsUserData(1)", scope $"""
						lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
						StackHelper.ThrowError(lua, lua.TinkerState);
						""");
				}
				bool variadic = parameters[parameters.Count - 1].IsVariadic;
				let requiredCount = method.ParamCount - (variadic ? 1 : 0);
				writer.If(scope $"lua.GetTop() {variadic ? "<" : "!="} {requiredCount}", scope $"""
					lua.TinkerState.SetLastError($"expected '{requiredCount - (hasThisParameter ? 1 : 0)}' arguments but got '{{lua.GetTop() - {hasThisParameter ? 1 : 0}}}'");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
			}
			EmitCallable(method, parameters, 0, parameters.Count, !isDelegate, writer);
		}


		internal static void EmitConstruction<T>(List<LuaParameter> parameters, int parameterStart, int parameterCount, CodeWriter writer)
		{
			let lastParameter = parameterStart + parameterCount - 1;
			bool variadic = parameterCount > 0 && parameters[lastParameter].IsVariadic;
			if (variadic)
				EmitVariadicStorage(parameters[lastParameter], true, writer);
			// Decode before allocation so failed arguments cannot finalize an uninitialized owned value.
			for (let parameter in parameters.GetRange(parameterStart, parameterCount))
			{
				if (parameter.IsVariadic)
					continue;
				let argument = scope String();
				argument.AppendF($"{(parameter.Mode == .Ref ? "ref var" : "let")} constructorArgument{@parameter.Index} = ");
				EmitDecodedArgument(parameter, scope $"{parameter.LuaStackIndex}", false, argument);
				argument.Append(";");
				writer.Line(argument);
			}
			bool isClass = typeof(T).IsObject;
			if (!isClass)
				writer.Line("let wrapper = new:alloc ValueTypeWrapper<T>();");
			let creation = scope String();
			if (isClass)
				creation.Append("let wrapper = new:alloc ClassTypeWrapper<T>(");
			else
				creation.Append("*wrapper.ValuePointer = .(");
			for (let parameter in parameters.GetRange(parameterStart, parameterCount))
			{
				if (variadic && @parameter.Index == parameterCount - 1)
					creation.Append("params extraArgs");
				else
					creation.AppendF($"{(parameter.Mode == .Ref ? "ref " : "")}constructorArgument{@parameter.Index}");
				if (@parameter.Index != parameterCount - 1)
					creation.Append(", ");
			}
			creation.Append(");");
			writer.Line(creation);
			writer.Line(scope $"""
				lua.TinkerState.RegisterAliveObject(wrapper);
				lua.TinkerState.PushClassMetatable<T>(lua);
				lua.SetMetaTable(-2);
				return 1;
				""");
		}
	}
}
