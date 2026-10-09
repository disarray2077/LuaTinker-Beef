using System;
using System.Collections;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;

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

		internal enum BranchSelection
		{
			None,
			Numeric,
			SingleInputSpan,
			InputSpan
		}

		private static LuaType BeefTypeToLuaType(Type type)
		{
			if (type == typeof(bool))
				return .Boolean;
			if (IsNumericType(type))
				return .Number;
			if (type == typeof(String) || type == typeof(StringView) || type == typeof(char8*))
				return .String;
			return .UserData;
		}

		private static void EmitNumericDispatch<T>(int positionIndex, List<Type> numericTypes, List<Trie<MatchKey>> numericBranches, List<Trie<MatchKey>> otherBranches, List<OverloadCandidate> candidates, List<LuaParameter> parameters, List<SelectorPosition> positions, CodeWriter writer, DispatchKind dispatchKind, BranchSelection otherSelection)
		{
			let stackIndex = positions[positionIndex].LuaStackIndex;
			let argumentPosition = positions[positionIndex].DiagnosticIndex;
			String types = scope .();
			for (let type in numericTypes)
			{
				if (!types.IsEmpty)
					types.Append(", ");
				types.AppendF($"comptype({type.GetTypeId()})");
			}
			let candidateTypes = numericTypes.Count == 1 ? types : scope $"({types})";
			if (numericTypes.Count > 1)
				writer.Line(scope $"let selectedNumericType{stackIndex} = StackHelper.SelectNumeric<{candidateTypes}>(lua, {stackIndex}, {argumentPosition});");
			CodeWriter.ConditionalChain numericChain = default;
			for (let type in numericTypes)
			{
				List<Trie<MatchKey>> typeBranches = scope .();
				for (let node in numericBranches)
					if (node.Value.MatchType == type)
						typeBranches.Add(node);
				let condition = numericTypes.Count == 1
					? scope $"StackHelper.SelectNumeric<{candidateTypes}>(lua, {stackIndex}, {argumentPosition}) == 0"
					: scope $"selectedNumericType{stackIndex} == {@type.Index}";
				delegate void(CodeWriter) emitBody = scope (body) =>
				{
					EmitTrieBranches<T>(positionIndex, typeBranches, candidates, parameters, positions, body, dispatchKind, .Numeric);
				};
				if (@type.Index == 0)
					numericChain = writer.If(condition, emitBody);
				else
					numericChain = numericChain.ElseIf(condition, emitBody);
			}
			if (!otherBranches.IsEmpty)
				numericChain.Else(scope (body) =>
				{
					EmitTrieBranches<T>(positionIndex, otherBranches, candidates, parameters, positions, body, dispatchKind, otherSelection);
				});
		}

		private static void EmitTrieBranches<T>(int positionIndex, List<Trie<MatchKey>> branches, List<OverloadCandidate> candidates, List<LuaParameter> parameters, List<SelectorPosition> positions, CodeWriter writer, DispatchKind dispatchKind, BranchSelection selection)
		{
			let stackIndex = positions[positionIndex].LuaStackIndex;
			CodeWriter.ConditionalChain lastBranch = default;
			for (let node in branches)
			{
				let param = node.Value;
				let type = param.MatchType;
				let flags = param.Flags;
				if (flags.HasFlag(.Params))
					Runtime.Assert(node.IsEnd);

				String condition = scope .();
				if (selection == .None || selection == .SingleInputSpan)
				{
					let luaType = BeefTypeToLuaType(type);
					if (type == typeof(Object))
					{
						if (selection == .SingleInputSpan)
							condition.AppendF($"lua.Type({stackIndex}) != .Table && ");
						condition.AppendF($"!StackHelper.IsArgumentHint(lua, {stackIndex})");
					}
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
					else
						condition.AppendF($"lua.Is{luaType}({stackIndex})");
					if (type.IsPointer && !flags.HasFlag(.This))
						condition.Insert(0, scope $"StackHelper.IsNullPointerArgument(lua, {stackIndex}, typeof(comptype({type.GetTypeId()}))) || ");
					if (selection == .SingleInputSpan && !flags.HasFlag(.This) && !flags.HasFlag(.Params) && GetSpanElement(type) != null)
						condition.Insert(0, scope $"(lua.Type({stackIndex}) == .Table && !StackHelper.IsArgumentHint(lua, {stackIndex})) || ");
				}

				writer.Line(scope $"// {type.GetFullName(.. scope .())} (Flags: {flags})");
				delegate void(CodeWriter) emitBody = scope (body) =>
				{
					body.Line(scope $"matchedOverloadArguments[{positionIndex}] = true;");
					if (flags.HasFlag(.This) && stackIndex == 1)
					{
						body.If(scope $"!User2Type.IsObjectTypeCompatible(lua, {stackIndex}, typeof(comptype({type.GetTypeId()}))) && StackHelper.EnsureValidMetaTable<comptype({type.GetTypeId()})>(lua, 1) == .OkUnregisteredType", scope (invalid) =>
						{
							let message = scope $"can't convert argument 0 to '{type}'";
							invalid.Line(scope $"lua.TinkerState.SetLastError({message.Quote(.. scope .())});");
							invalid.Line("StackHelper.ThrowError(lua, lua.TinkerState);");
						});
					}

					if (flags.HasFlag(.Params))
						EmitSelectedOverload<T>(candidates[node.CandidateIndex], parameters, body, dispatchKind == .Constructor);
					else if (!node.Children.IsEmpty)
					{
						let variadicChild = FindVariadicChild(node);
						let childChain = body.If(scope $"lua.GetTop() >= {stackIndex + 1}", scope (child) =>
						{
							IterateTrie<T>(positionIndex + 1, node, candidates, parameters, positions, child, dispatchKind);
						});
						if (node.IsEnd)
							childChain.Else(scope (terminal) =>
							{
								EmitSelectedOverload<T>(candidates[node.CandidateIndex], parameters, terminal, dispatchKind == .Constructor);
							});
						else if (variadicChild != null)
							childChain.Else(scope (terminal) =>
							{
								EmitSelectedOverload<T>(candidates[variadicChild.CandidateIndex], parameters, terminal, dispatchKind == .Constructor);
							});
					}
					else if (node.IsEnd)
					{
						body.If(scope $"lua.GetTop() < {stackIndex + 1}", scope (terminal) =>
						{
								EmitSelectedOverload<T>(candidates[node.CandidateIndex], parameters, terminal, dispatchKind == .Constructor);
						});
					}
				};

				if (condition.IsEmpty)
					emitBody(writer);
				else
					lastBranch = writer.If(condition, emitBody);
			}

			if (!branches.IsEmpty && dispatchKind == .InstanceMethod && stackIndex == 1)
			{
				lastBranch.Else("""
					lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
			}
		}

		private static void EmitInputSpanDispatch<T>(int positionIndex, List<Trie<MatchKey>> branches, List<Type> spanTypes, List<OverloadCandidate> candidates, List<LuaParameter> parameters, List<SelectorPosition> positions, CodeWriter writer, DispatchKind dispatchKind)
		{
			let stackIndex = positions[positionIndex].LuaStackIndex;
			String spanCandidates = scope .();
			for (let spanType in spanTypes)
			{
				if (@spanType.Index > 0)
					spanCandidates.Append(", ");
				spanCandidates.AppendF($"comptype({GetSpanElement(spanType).GetTypeId()})");
			}
			writer.Line(scope $"let selectedInputSpanType{stackIndex} = StackHelper.SelectInputSpan<({spanCandidates})>(lua, {stackIndex}, {positions[positionIndex].DiagnosticIndex});");
			CodeWriter.ConditionalChain chain = default;
			for (let spanType in spanTypes)
			{
				delegate void(CodeWriter) emitBody = scope (body) =>
				{
					List<Trie<MatchKey>> typeBranches = scope .();
					for (let branch in branches)
						if (branch.Value.MatchType == spanType && !branch.Value.Flags.HasFlag(.Params) && !branch.Value.Flags.HasFlag(.This))
							typeBranches.Add(branch);
					EmitTrieBranches<T>(positionIndex, typeBranches, candidates, parameters, positions, body, dispatchKind, .InputSpan);
				};
				let condition = scope $"selectedInputSpanType{stackIndex} == {@spanType.Index}";
				if (@spanType.Index == 0)
					chain = writer.If(condition, emitBody);
				else
					chain = chain.ElseIf(condition, emitBody);
			}
		}

		private static void IterateTrie<T>(int positionIndex, Trie<MatchKey> root, List<OverloadCandidate> candidates, List<LuaParameter> parameters, List<SelectorPosition> positions, CodeWriter writer, DispatchKind dispatchKind)
		{
			let stackIndex = positions[positionIndex].LuaStackIndex;
			let argumentPosition = positions[positionIndex].DiagnosticIndex;
			writer.Line(scope $"matchedOverloadArguments[{positionIndex}] = false;");
			List<Type> numericTypes = scope .();
			List<Type> pointerTypes = scope .();
			List<Type> inputSpanTypes = scope .();
			List<Trie<MatchKey>> numericBranches = scope .();
			List<Trie<MatchKey>> otherBranches = scope .();
			for (let node in root.OrderedChildren)
			{
				let param = node.Value;
				let type = param.MatchType;
				if (!param.Flags.HasFlag(.This) && !param.Flags.HasFlag(.Params))
					if (GetSpanElement(type) != null && !inputSpanTypes.Contains(type))
						inputSpanTypes.Add(type);
				if (!param.Flags.HasFlag(.This) && type.IsPointer && !pointerTypes.Contains(type))
					pointerTypes.Add(type);
				if (!param.Flags.HasFlag(.This) && IsNumericType(type))
				{
					numericBranches.Add(node);
					if (!numericTypes.Contains(type))
						numericTypes.Add(type);
				}
				else
					otherBranches.Add(node);
			}
			if (pointerTypes.Count > 1)
				writer.Line(scope $"StackHelper.EnsureUnambiguousNullPointer(lua, {stackIndex}, {argumentPosition});");
			delegate void(CodeWriter) emitOrdinaryBranches = scope (body) =>
			{
				let otherSelection = inputSpanTypes.Count == 1 ? BranchSelection.SingleInputSpan : BranchSelection.None;
				if (numericTypes.IsEmpty)
					EmitTrieBranches<T>(positionIndex, otherBranches, candidates, parameters, positions, body, dispatchKind, otherSelection);
				else
					EmitNumericDispatch<T>(positionIndex, numericTypes, numericBranches, otherBranches, candidates, parameters, positions, body, dispatchKind, otherSelection);
			};
			if (inputSpanTypes.Count <= 1)
				emitOrdinaryBranches(writer);
			else
				writer.If(scope $"lua.Type({stackIndex}) == .Table && !StackHelper.IsArgumentHint(lua, {stackIndex})", scope (body) =>
				{
					EmitInputSpanDispatch<T>(positionIndex, root.OrderedChildren, inputSpanTypes, candidates, parameters, positions, body, dispatchKind);
				}).Else(emitOrdinaryBranches);
			String expectedTypes = scope .();
			List<Type> expected = scope .();
			for (let child in root.OrderedChildren)
			{
				let type = child.Value.MatchType;
				if (expected.Contains(type))
					continue;
				expected.Add(type);
				if (!expectedTypes.IsEmpty)
					expectedTypes.Append(" or ");
				expectedTypes.AppendF($"'{type}'");
			}
			writer.If(scope $"!matchedOverloadArguments[{positionIndex}]",
				scope $"overloadFailure.Record({argumentPosition}, {stackIndex}, {expectedTypes.Quote(.. scope .())});");
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

		private static void EmitDispatchFailure(List<OverloadCandidate> candidates, List<LuaParameter> parameters, CodeWriter writer, DispatchKind dispatchKind)
		{
			let implicitArgumentCount = dispatchKind == .StaticMethod ? 0 : 1;
			List<int> fixedArgumentCounts = scope .();
			int variadicMinimum = -1;
			for (let candidate in candidates)
			{
				let argumentCount = candidate.ParameterCount - (dispatchKind == .InstanceMethod ? 1 : 0);
				let isVariadic = candidate.ParameterCount > 0 && parameters[candidate.ParameterStart + candidate.ParameterCount - 1].IsVariadic;
				if (isVariadic)
				{
					let minimum = argumentCount - 1;
					if (variadicMinimum < 0 || minimum < variadicMinimum)
						variadicMinimum = minimum;
				}
				else if (!fixedArgumentCounts.Contains(argumentCount))
					fixedArgumentCounts.Add(argumentCount);
			}
			fixedArgumentCounts.Sort();
			if (variadicMinimum >= 0)
				for (let count in fixedArgumentCounts)
					if (count >= variadicMinimum)
						@count.RemoveFast();

			String validArgumentCount = scope .();
			String expectedArgumentCounts = scope .();
			for (let count in fixedArgumentCounts)
			{
				if (@count.Index > 0)
				{
					validArgumentCount.Append(" || ");
					expectedArgumentCounts.Append(@count.Index == fixedArgumentCounts.Count - 1 && variadicMinimum < 0 ? " or " : ", ");
				}
				validArgumentCount.AppendF($"lua.GetTop() == {count + implicitArgumentCount}");
				expectedArgumentCounts.AppendF($"{count}");
			}
			if (variadicMinimum >= 0)
			{
				if (!validArgumentCount.IsEmpty)
				{
					validArgumentCount.Append(" || ");
					expectedArgumentCounts.Append(" or ");
				}
				validArgumentCount.AppendF($"lua.GetTop() >= {variadicMinimum + implicitArgumentCount}");
				expectedArgumentCounts.AppendF($"{variadicMinimum}+");
			}
			writer.If(validArgumentCount, "overloadFailure.Throw(lua);");
			let actualArgumentCount = implicitArgumentCount == 0 ? "lua.GetTop()" : "lua.GetTop() - 1";
			writer.Line(scope $"""
				lua.TinkerState.SetLastError($"expected '{expectedArgumentCounts}' arguments but got '{{{actualArgumentCount}}}'");
				StackHelper.ThrowError(lua, lua.TinkerState);
				""");
		}

		internal static void EmitOverloads<T>(List<MethodInfo> methods, CodeWriter writer, DispatchKind dispatchKind)
		{
			bool isConstructor = dispatchKind == .Constructor;
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
			writer.Line(scope $"""
				OverloadFailure overloadFailure = .();
				bool[{positions.Count}] matchedOverloadArguments = .();
				""");
			let topChain = writer.If(isConstructor ? "lua.GetTop() >= 2" : "lua.GetTop() >= 1", scope (body) =>
			{
				IterateTrie<T>(0, paramsTrie, candidates, parameters, positions, body, dispatchKind);
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
			else if (dispatchKind == .InstanceMethod)
			{
				topChain.Else("""
					lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
			}

			EmitDispatchFailure(candidates, parameters, writer, dispatchKind);
		}
	}
}
