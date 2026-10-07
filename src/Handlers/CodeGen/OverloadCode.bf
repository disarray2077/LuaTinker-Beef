using System;
using System.Collections;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;

using internal LuaTinker.Handlers;

namespace LuaTinker.Handlers
{
	static
	{
		internal enum DispatchKind
		{
			Constructor,
			StaticMethod,
			InstanceMethod
		}

		private static LuaType BeefTypeToLuaType(Type type)
		{
			if (type == typeof(bool))
				return .Boolean;
			if (type.IsInteger || type.IsFloatingPoint || type.IsEnum || (type.IsTypedPrimitive && (type.UnderlyingType.IsInteger || type.IsFloatingPoint || type.IsEnum)))
				return .Number;
			if (type == typeof(String) || type == typeof(StringView) || type == typeof(char8*))
				return .String;
			return .UserData;
		}

		private static void IterateTrie<T>(int positionIndex, Trie<MatchKey> root, List<OverloadCandidate> candidates, List<LuaParameter> parameters, List<SelectorPosition> positions, CodeWriter writer, DispatchKind kind)
		{
			let stackIndex = positions[positionIndex].LuaStackIndex;
			CodeWriter.ConditionalChain lastBranch = default;
			for (let node in root.OrderedChildren)
			{
				let param = node.Value;
				let type = param.MatchType;
				let flags = param.Flags;
				if (flags.HasFlag(.Params))
					Runtime.Assert(node.IsEnd);

				LuaType luaType = BeefTypeToLuaType(type);
				String condition = scope .();
				if (type == typeof(Object))
					condition.Append("true");
				else if ((luaType == .UserData || luaType == .String) && flags.HasFlag(.This))
				{
					if (stackIndex == 1)
						condition.AppendF($"User2Type.IsLuaTinkerPointerUserdata(lua, {stackIndex})");
					else
						condition.AppendF($"User2Type.IsObjectTypeCompatible(lua, {stackIndex}, typeof(comptype({type.GetTypeId()})))");
				}
				else if (luaType == .UserData)
					condition.AppendF($"lua.IsNil({stackIndex}) || User2Type.IsObjectTypeCompatible(lua, {stackIndex}, typeof(comptype({type.GetTypeId()})))");
				else if (luaType == .String)
					condition.AppendF($"lua.IsString({stackIndex}) || lua.IsNil({stackIndex}) || User2Type.IsObjectTypeCompatible(lua, {stackIndex}, typeof(comptype({type.GetTypeId()})))");
				else if (luaType == .Number)
					condition.AppendF($"lua.IsNumber({stackIndex}) && !lua.IsString({stackIndex})");
				else
					condition.AppendF($"lua.Is{luaType}({stackIndex})");

				writer.Line(scope $"// {type.GetFullName(.. scope .())} (Flags: {flags})");
				lastBranch = writer.If(condition, scope (body) =>
				{
					if (flags.HasFlag(.This) && stackIndex == 1)
					{
						body.If(scope $"!User2Type.IsObjectTypeCompatible(lua, {stackIndex}, typeof(comptype({type.GetTypeId()}))) && StackHelper.EnsureValidMetaTable<comptype({type.GetTypeId()})>(lua, 1) == .OkUnregisteredType", scope (invalid) =>
						{
							invalid.Block("", scope $"""
								lua.TinkerState.SetLastError($"can't convert argument 0 to '{{StackHelper.GetBestLuaClassName<comptype({type.GetTypeId()})>(lua.TinkerState, .. scope .())}}'");
								""");
							invalid.Line("StackHelper.ThrowError(lua, lua.TinkerState);");
						});
					}

					if (flags.HasFlag(.Params))
						EmitSelectedOverload<T>(candidates[node.CandidateIndex], parameters, body, kind == .Constructor);
					else if (!node.Children.IsEmpty)
					{
						let variadicChild = FindVariadicChild(node);
						let childChain = body.If(scope $"lua.GetTop() >= {stackIndex + 1}", scope (child) =>
						{
							IterateTrie<T>(positionIndex + 1, node, candidates, parameters, positions, child, kind);
						});
						if (node.IsEnd)
							childChain.Else(scope (terminal) =>
							{
								EmitSelectedOverload<T>(candidates[node.CandidateIndex], parameters, terminal, kind == .Constructor);
							});
						else if (variadicChild != null)
							childChain.Else(scope (terminal) =>
							{
								EmitSelectedOverload<T>(candidates[variadicChild.CandidateIndex], parameters, terminal, kind == .Constructor);
							});
					}
					else if (node.IsEnd)
					{
						body.If(scope $"lua.GetTop() < {stackIndex + 1}", scope (terminal) =>
						{
								EmitSelectedOverload<T>(candidates[node.CandidateIndex], parameters, terminal, kind == .Constructor);
						});
					}
				});
			}

			if (!root.Children.IsEmpty && kind == .InstanceMethod && stackIndex == 1)
			{
				lastBranch.Else("""
					lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
			}
		}

		internal static void EmitSelectedOverload<T>(OverloadCandidate candidate, List<LuaParameter> parameters, CodeWriter writer, bool isConstructor)
		{
			let method = candidate.Method;
			writer.Line(scope $"""
				// {method}
				// [{typeof(T).TypeId}] {typeof(T)}
				// [{method.ReturnType.TypeId}] {method.ReturnType}
				""");
			for (int i < method.ParamCount)
				writer.Line(scope $"// [{method.GetParamType(i).TypeId}] {method.GetParamType(i)} (Flags: {method.GetParamFlags(i)})");

			if (isConstructor)
				EmitConstruction<T>(parameters, candidate.ParameterStart, candidate.ParameterCount, writer);
			else
				EmitTypedCall<T>(method, parameters, candidate.ParameterStart, candidate.ParameterCount, writer);
		}

		internal static void EmitOverloads<T>(List<MethodInfo> methods, CodeWriter writer, DispatchKind kind)
		{
			bool isConstructor = kind == .Constructor;
			List<LuaParameter> parameters = scope .();
			List<OverloadCandidate> candidates = scope .();
			for (let method in methods)
			{
				let start = parameters.Count;
				if (isConstructor)
				{
					let visibleStart = method.ParamCount > 0 && method.GetParamName(0) == "__appendIdx" ? 1 : 0;
					NormalizeConstructorParameters(method, parameters, visibleStart);
				}
				else
					NormalizeMethodParameters(method, parameters);
				candidates.Add(.(method, start, parameters.Count - start));
			}

			Trie<MatchKey> paramsTrie = scope .();
			List<SelectorPosition> positions = scope .();
			BuildOverloadTrie(paramsTrie, candidates, parameters, positions, isConstructor);
			let topChain = writer.If(isConstructor ? "lua.GetTop() >= 2" : "lua.GetTop() >= 1", scope (body) =>
			{
				IterateTrie<T>(0, paramsTrie, candidates, parameters, positions, body, kind);
			});

			let variadicChild = FindVariadicChild(paramsTrie);
			if (paramsTrie.IsEnd)
			{
				let candidate = candidates[paramsTrie.CandidateIndex];
				if (isConstructor)
				{
					// Handle the case for a constructor with no arguments (e.g., MyClass()).
					topChain.ElseIf("lua.GetTop() == 1", scope (body) =>
					{
						body.Line(scope $"// Default constructor for: {candidate.Method}");
						EmitConstruction<T>(parameters, candidate.ParameterStart, candidate.ParameterCount, body);
					});
				}
				else
					topChain.Else(scope (body) => EmitSelectedOverload<T>(candidate, parameters, body, false));
			}
			else if (variadicChild != null)
			{
				let candidate = candidates[variadicChild.CandidateIndex];
				if (isConstructor)
					topChain.ElseIf("lua.GetTop() == 1", scope (body) => EmitSelectedOverload<T>(candidate, parameters, body, true));
				else
					topChain.Else(scope (body) => EmitSelectedOverload<T>(candidate, parameters, body, false));
			}
			else if (kind == .InstanceMethod)
			{
				topChain.Else("""
					lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
			}

			if (isConstructor)
			{
				writer.Line(scope $"""
					lua.TinkerState.SetLastError($"invalid arguments for constructor '{typeof(T)}'");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
			}
			else
			{
				int nextEndDepth = 0;
				Trie<MatchKey> nextEnd = paramsTrie;
				while (!nextEnd.IsEnd)
				{
					nextEndDepth += 1;
					nextEnd = nextEnd.OrderedChildren[0];
				}
				writer.Line(scope $"""
					lua.TinkerState.SetLastError($"expected '{nextEndDepth}' arguments but got '{{lua.GetTop()}}'");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
			}
		}
	}
}
