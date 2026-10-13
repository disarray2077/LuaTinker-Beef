using System;
using System.Collections;
using System.Diagnostics;
using System.Reflection;
using LuaTinker.Helpers;

using internal LuaTinker.Handlers;
using internal LuaTinker.Helpers;

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
			let mixinSuffix = variadicStorage ? ":invocation" : "";

			if (parameter.Mode != .Value)
			{
				code.Append(parameter.Mode == .Ref ? "ref " : "out ");
				code.AppendF($"StackHelper.PopRef<{typeCode}>(lua, {stackIndex})");
			}
			else if (IsHintableType(parameter.DecodedType))
			{
				code.AppendF($"StackHelper.PopHinted!{mixinSuffix}<{typeCode}>(lua, {stackIndex})");
			}
			else
			{
				code.AppendF($"StackHelper.Pop!{mixinSuffix}<{typeCode}>(lua, {stackIndex})");
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

		internal static void EmitCallable(MethodInfo method, Span<LuaParameter> parameters, bool annotateTypes, CodeWriter writer, StringView target = "func")
		{
			let variadic = !parameters.IsEmpty && parameters[^1].IsVariadic;
			delegate void(CodeWriter) emitBody = scope (body) =>
			{
				let returnType = method.ReturnType;
				if (variadic)
					EmitVariadicStorage(parameters[^1], false, body);

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
				invocation.AppendF($"{target}(");
				for (let parameter in parameters)
				{
					if (parameter.IsVariadic)
						invocation.Append("params extraArgs");
					else
						EmitDecodedArgument(parameter, scope $"{parameter.LuaStackIndex}", false, invocation);
					if (@parameter.Index != parameters.Length - 1)
						invocation.Append(", ");
				}
				invocation.Append(");");
				body.Line(invocation);
				EmitCallableReturn(returnType, returnsRef, body);
			};
			if (variadic)
				writer.Block("invocation:", emitBody);
			else
				emitBody(writer);
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
				let fixedCount = GetFixedParameterCount(method);
				let requiredCount = GetRequiredParameterCount(method);
				let expectedCount = scope String();
				for (int count = requiredCount; count <= fixedCount; count++)
				{
					if (!expectedCount.IsEmpty)
						expectedCount.Append(count == fixedCount ? " or " : ", ");
					expectedCount.AppendF($"{count - (hasThisParameter ? 1 : 0)}{(variadic && count == fixedCount ? "+" : "")}");
				}
				let invalidCount = variadic ? scope $"lua.GetTop() < {requiredCount}" : scope $"lua.GetTop() < {requiredCount} || lua.GetTop() > {fixedCount}";
				writer.If(invalidCount, scope $"""
					lua.TinkerState.SetLastError($"expected '{expectedCount}' arguments but got '{{lua.GetTop() - {hasThisParameter ? 1 : 0}}}'");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
				for (int count = requiredCount; count < fixedCount; count++)
					writer.If(scope $"lua.GetTop() == {count}", scope (body) => EmitCallable(method, parameters.GetRange(0, count), !isDelegate, body));
			}
			EmitCallable(method, parameters, !isDelegate, writer);
		}


		internal static void EmitConstruction<T>(Span<LuaParameter> parameters, CodeWriter writer)
		{
			bool variadic = !parameters.IsEmpty && parameters[^1].IsVariadic;
			delegate void(CodeWriter) emitBody = scope (body) =>
			{
				if (variadic)
					EmitVariadicStorage(parameters[^1], true, body);
				// Decode before allocation so failed arguments cannot finalize an uninitialized owned value.
				for (let parameter in parameters)
				{
					if (parameter.IsVariadic)
						continue;
					let argument = scope String();
					argument.AppendF($"{(parameter.Mode == .Ref ? "ref var" : "let")} constructorArgument{@parameter.Index} = ");
					EmitDecodedArgument(parameter, scope $"{parameter.LuaStackIndex}", false, argument);
					argument.Append(";");
					body.Line(argument);
				}
				bool isClass = typeof(T).IsObject;
				if (!isClass)
					body.Line("let wrapper = new:alloc ValueTypeWrapper<T>();");
				let creation = scope String();
				if (isClass)
					creation.Append("let wrapper = new:alloc ClassTypeWrapper<T>(");
				else
					creation.Append("*wrapper.ValuePointer = .(");
				for (let parameter in parameters)
				{
					if (variadic && @parameter.Index == parameters.Length - 1)
						creation.Append("params extraArgs");
					else
						creation.AppendF($"{(parameter.Mode == .Ref ? "ref " : "")}constructorArgument{@parameter.Index}");
					if (@parameter.Index != parameters.Length - 1)
						creation.Append(", ");
				}
				creation.Append(");");
				body.Line(creation);
				body.Line(scope $"""
					lua.TinkerState.RegisterAliveObject(wrapper);
					lua.TinkerState.PushClassMetatable<T>(lua);
					lua.SetMetaTable(-2);
					return 1;
					""");
			};
			if (variadic)
				writer.Block("invocation:", emitBody);
			else
				emitBody(writer);
		}
	}
}
