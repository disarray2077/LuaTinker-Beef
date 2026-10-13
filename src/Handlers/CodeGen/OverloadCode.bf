using System;
using System.Collections;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;

using internal LuaTinker.Handlers;
using internal LuaTinker.Helpers;

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
			Committed,
			Numeric,
			SingleInputSpan,
			InputSpan
		}

		internal struct ArgumentCountRange : this(int Minimum, int Maximum);

		internal class DispatchContext
		{
			// These lists are borrowed and must remain unchanged during traversal.
			public readonly List<OverloadCandidate> Candidates;
			public readonly List<LuaParameter> Parameters;
			public readonly List<SelectorPosition> Positions;
			public readonly DispatchKind DispatchKind;

			public this(List<OverloadCandidate> candidates, List<LuaParameter> parameters, List<SelectorPosition> positions, DispatchKind dispatchKind)
			{
				Candidates = candidates;
				Parameters = parameters;
				Positions = positions;
				DispatchKind = dispatchKind;
			}
		}

		internal struct BranchContext : this(DispatchContext Dispatch, int PositionIndex, ArgumentCountRange ArgumentCounts, bool CanFallback)
		{
			[Inline]
			public int StackIndex => Dispatch.Positions[PositionIndex].LuaStackIndex;

			[Inline]
			public int DiagnosticIndex => Dispatch.Positions[PositionIndex].DiagnosticIndex;

			[Inline]
			public static Self ForRoot(DispatchContext dispatch, ArgumentCountRange counts)
				=> .(dispatch, 0, counts, false);

			[Inline]
			public Self ForChild(ArgumentCountRange counts, bool canFallback)
				=> .(Dispatch, PositionIndex + 1, counts, canFallback);
		}

		private static void EmitArityBranch(ArgumentCountRange argumentCounts, int requiredCount, CodeWriter writer,
			delegate void(CodeWriter, ArgumentCountRange) emitPresent, delegate void(CodeWriter, ArgumentCountRange) emitMissing = null)
		{
			if (argumentCounts.Minimum >= requiredCount)
				emitPresent(writer, argumentCounts);
			else if (argumentCounts.Maximum < requiredCount)
			{
				if (emitMissing != null)
					emitMissing(writer, argumentCounts);
			}
			else
			{
				let chain = writer.If(scope $"argumentCount >= {requiredCount}", scope (body) =>
				{
					emitPresent(body, .(requiredCount, argumentCounts.Maximum));
				});
				if (emitMissing != null)
					chain.Else(scope (body) => emitMissing(body, .(argumentCounts.Minimum, requiredCount - 1)));
			}
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

		private static void EmitNumericDispatch<T>(BranchContext context, List<Type> numericTypes, List<Trie<MatchKey>> numericBranches, List<Trie<MatchKey>> otherBranches, CodeWriter writer, BranchSelection otherSelection)
		{
			let stackIndex = context.StackIndex;
			let argumentPosition = context.DiagnosticIndex;
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
					EmitTrieBranches<T>(context, typeBranches, body, .Numeric);
				};
				if (@type.Index == 0)
					numericChain = writer.If(condition, emitBody);
				else
					numericChain = numericChain.ElseIf(condition, emitBody);
			}
			if (!otherBranches.IsEmpty)
				numericChain.Else(scope (body) =>
				{
					EmitTrieBranches<T>(context, otherBranches, body, otherSelection);
				});
		}

		private static void EmitReceiverValidation(Type type, CodeWriter writer)
		{
			writer.If(scope $"!User2Type.IsObjectTypeCompatible(lua, 1, typeof(comptype({type.GetTypeId()}))) && StackHelper.EnsureValidMetaTable<comptype({type.GetTypeId()})>(lua, 1) == .OkUnregisteredType", scope (invalid) =>
			{
				let message = scope $"can't convert argument 0 to '{type}'";
				invalid.Line(scope $"lua.TinkerState.SetLastError({message.Quote(.. scope .())});");
				invalid.Line("StackHelper.ThrowError(lua, lua.TinkerState);");
			});
		}

		private static void EmitTrieBranches<T>(BranchContext context, List<Trie<MatchKey>> branches, CodeWriter writer, BranchSelection selection)
		{
			let dispatch = context.Dispatch;
			let isConstructor = dispatch.DispatchKind == .Constructor;
			let stackIndex = context.StackIndex;

			List<Type> pointerTypes = scope .();
			for (let branch in branches)
				if (!branch.Value.Flags.HasFlag(.This) && branch.Value.MatchType.IsPointer && !(branch.Value.MatchType is RefType) && !pointerTypes.Contains(branch.Value.MatchType))
					pointerTypes.Add(branch.Value.MatchType);
			let hasVoidPointerFallback = pointerTypes.Count > 1 && pointerTypes.Contains(typeof(void*));
			if (hasVoidPointerFallback)
			{
				String types = scope .();
				for (let type in pointerTypes)
				{
					if (!types.IsEmpty)
						types.Append(", ");
					types.AppendF($"typeof(comptype({type.GetTypeId()}))");
				}
				writer.Line(scope $"static Type[{pointerTypes.Count}] pointerTypes{stackIndex} = .({types});");
			}

			CodeWriter.ConditionalChain lastBranch = default;
			for (let node in branches)
			{
				let param = node.Value;
				let type = param.MatchType;
				let flags = param.Flags;
				if (flags.HasFlag(.Params))
					Runtime.Assert(node.IsEnd);

				String condition = scope .();
				if (selection == .None || selection == .SingleInputSpan || selection == .Committed)
				{
					let luaType = BeefTypeToLuaType(type);
					if (type.IsPointer && !(type is RefType) && !flags.HasFlag(.This))
					{
						let competingTypes = hasVoidPointerFallback && type == typeof(void*) ? scope $", pointerTypes{stackIndex}" : "";
						condition.AppendF($"StackHelper.IsPointerArgument(lua, {stackIndex}, typeof(comptype({type.GetTypeId()})){competingTypes})");
					}
					else if (IsDelegateType(type) && !flags.HasFlag(.This))
						condition.AppendF($"StackHelper.IsDelegateArgument(lua, {stackIndex}, typeof(comptype({type.GetTypeId()})))");
					else if (type == typeof(Object))
					{
						if (selection == .SingleInputSpan)
							condition.AppendF($"lua.Type({stackIndex}) != .Table && ");
						condition.AppendF($"!StackHelper.IsArgumentHint(lua, {stackIndex})");
					}
					else if (IsNumericType(type) && !flags.HasFlag(.This))
						condition.AppendF($"StackHelper.SelectNumeric<comptype({type.GetTypeId()})>(lua, {stackIndex}, {context.DiagnosticIndex}) == 0");
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
					if ((selection == .SingleInputSpan || selection == .Committed) && !flags.HasFlag(.This) && !flags.HasFlag(.Params) && GetSpanElement(type) != null)
						condition.Insert(0, scope $"(lua.Type({stackIndex}) == .Table && !StackHelper.IsArgumentHint(lua, {stackIndex})) || ");
				}

				writer.Line(scope $"// {type.GetFullName(.. scope .())} (Flags: {flags})");
				delegate void(CodeWriter) emitBody = scope (body) =>
				{
					if (selection != .Committed)
						body.Line(scope $"matchedOverloadArguments[{context.PositionIndex}] = true;");
					let childCanFallback = context.CanFallback || @node.Index < branches.Count - 1;
					if (flags.HasFlag(.This) && stackIndex == 1)
						EmitReceiverValidation(type, body);

					if (flags.HasFlag(.Params))
						EmitSelectedOverload<T>(dispatch.Candidates[node.CandidateIndex], dispatch.Parameters, body, isConstructor);
					else if (!node.Children.IsEmpty)
					{
						let variadicChild = FindVariadicChild(node);
						delegate void(CodeWriter, ArgumentCountRange) emitMissing = null;
						if (node.IsEnd)
							emitMissing = scope (terminal, counts) => EmitSelectedOverload<T>(dispatch.Candidates[node.CandidateIndex], dispatch.Parameters, terminal, isConstructor);
						else if (variadicChild != null)
							emitMissing = scope (terminal, counts) => EmitSelectedOverload<T>(dispatch.Candidates[variadicChild.CandidateIndex], dispatch.Parameters, terminal, isConstructor);
						else if (!childCanFallback)
							emitMissing = scope (terminal, counts) => terminal.Line("overloadFailure.Throw(lua);");
						EmitArityBranch(context.ArgumentCounts, stackIndex + 1, body, scope (child, counts) =>
						{
							IterateTrie<T>(context.ForChild(counts, childCanFallback), node, child);
						}, emitMissing);
					}
					else if (node.IsEnd)
					{
						if (selection == .Committed)
						{
							if (context.ArgumentCounts.Minimum > stackIndex)
								body.Line("overloadFailure.Throw(lua);");
							else
							{
								if (context.ArgumentCounts.Maximum > stackIndex)
									body.If(scope $"argumentCount != {stackIndex}", "overloadFailure.Throw(lua);");
								EmitSelectedOverload<T>(dispatch.Candidates[node.CandidateIndex], dispatch.Parameters, body, isConstructor);
							}
						}
						else if (context.ArgumentCounts.Minimum <= stackIndex)
						{
							if (context.ArgumentCounts.Maximum == stackIndex)
								EmitSelectedOverload<T>(dispatch.Candidates[node.CandidateIndex], dispatch.Parameters, body, isConstructor);
							else
								body.If(scope $"argumentCount == {stackIndex}", scope (terminal) =>
								{
									EmitSelectedOverload<T>(dispatch.Candidates[node.CandidateIndex], dispatch.Parameters, terminal, isConstructor);
								});
						}
					}
				};

				if (condition.IsEmpty)
					emitBody(writer);
				else if (selection == .Committed)
				{
					writer.If(scope $"!({condition})", scope (invalid) =>
					{
						if (flags.HasFlag(.This) && stackIndex == 1)
							invalid.Line("""
								lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
								StackHelper.ThrowError(lua, lua.TinkerState);
								""");
						else
						{
							let expectedType = scope $"'{type}'";
							invalid.Line(scope $"overloadFailure.Record({context.DiagnosticIndex}, {stackIndex}, {expectedType.Quote(.. scope .())});");
							invalid.Line("overloadFailure.Throw(lua);");
						}
					});
					emitBody(writer);
				}
				else
					lastBranch = writer.If(condition, emitBody);
			}

			if (selection != .Committed && !branches.IsEmpty && dispatch.DispatchKind == .InstanceMethod && stackIndex == 1)
			{
				lastBranch.Else("""
					lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
			}
		}

		private static void EmitInputSpanDispatch<T>(BranchContext context, List<Trie<MatchKey>> branches, List<Type> spanTypes, CodeWriter writer)
		{
			let stackIndex = context.StackIndex;
			String spanCandidates = scope .();
			for (let spanType in spanTypes)
			{
				if (@spanType.Index > 0)
					spanCandidates.Append(", ");
				spanCandidates.AppendF($"comptype({GetSpanElement(spanType).GetTypeId()})");
			}
			writer.Line(scope $"let selectedInputSpanType{stackIndex} = StackHelper.SelectInputSpan<({spanCandidates})>(lua, {stackIndex}, {context.DiagnosticIndex});");
			CodeWriter.ConditionalChain chain = default;
			for (let spanType in spanTypes)
			{
				delegate void(CodeWriter) emitBody = scope (body) =>
				{
					List<Trie<MatchKey>> typeBranches = scope .();
					for (let branch in branches)
						if (branch.Value.MatchType == spanType && !branch.Value.Flags.HasFlag(.Params) && !branch.Value.Flags.HasFlag(.This))
							typeBranches.Add(branch);
					EmitTrieBranches<T>(context, typeBranches, body, .InputSpan);
				};
				let condition = scope $"selectedInputSpanType{stackIndex} == {@spanType.Index}";
				if (@spanType.Index == 0)
					chain = writer.If(condition, emitBody);
				else
					chain = chain.ElseIf(condition, emitBody);
			}
		}

		private static void IterateTrie<T>(BranchContext context, Trie<MatchKey> root, CodeWriter writer)
		{
			let stackIndex = context.StackIndex;
			let argumentPosition = context.DiagnosticIndex;
			if (!context.CanFallback && root.OrderedChildren.Count == 1)
			{
				EmitTrieBranches<T>(context, root.OrderedChildren, writer, .Committed);
				return;
			}
			writer.Line(scope $"matchedOverloadArguments[{context.PositionIndex}] = false;");
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
				if (!param.Flags.HasFlag(.This) && type.IsPointer && !(type is RefType) && !pointerTypes.Contains(type))
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
					EmitTrieBranches<T>(context, otherBranches, body, otherSelection);
				else
					EmitNumericDispatch<T>(context, numericTypes, numericBranches, otherBranches, body, otherSelection);
			};
			if (inputSpanTypes.Count <= 1)
				emitOrdinaryBranches(writer);
			else
				writer.If(scope $"lua.Type({stackIndex}) == .Table && !StackHelper.IsArgumentHint(lua, {stackIndex})", scope (body) =>
				{
					EmitInputSpanDispatch<T>(context, root.OrderedChildren, inputSpanTypes, body);
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
			writer.If(scope $"!matchedOverloadArguments[{context.PositionIndex}]",
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
				EmitConstruction<T>(parameters.GetRange(candidate.ParameterStart, candidate.ParameterCount), writer);
			else
			{
				let target = method.IsStatic ? scope $"T.{method.Name}" : scope $"StackHelper.Pop!<T>(lua, 1).{method.Name}";
				let thisCount = method.IsStatic ? 0 : 1;
				EmitCallable(method, parameters.GetRange(candidate.ParameterStart + thisCount, candidate.ParameterCount - thisCount), false, writer, target);
			}
		}

		private static ArgumentCountRange EmitArityCheck(List<OverloadCandidate> candidates, List<LuaParameter> parameters, CodeWriter writer, DispatchKind dispatchKind)
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

			let minimum = fixedArgumentCounts.IsEmpty ? variadicMinimum :
				variadicMinimum < 0 ? fixedArgumentCounts[0] : Math.Min(fixedArgumentCounts[0], variadicMinimum);
			ArgumentCountRange argumentCounts = .(minimum + implicitArgumentCount,
				variadicMinimum >= 0 ? int.MaxValue : fixedArgumentCounts[^1] + implicitArgumentCount);

			if (variadicMinimum >= 0 && implicitArgumentCount == 0)
			{
				// Fixed arities can fill the gap below the variadic range.
				int firstVariadicCount = variadicMinimum;
				for (let count in fixedArgumentCounts.Reversed)
				{
					if (count != firstVariadicCount - 1)
						break;
					firstVariadicCount--;
				}
				if (firstVariadicCount == 0)
					return argumentCounts;
			}

			String invalidArgumentCount = scope .();
			String expectedArgumentCounts = scope .();
			for (let count in fixedArgumentCounts)
			{
				if (@count.Index > 0)
				{
					invalidArgumentCount.Append(" && ");
					expectedArgumentCounts.Append(@count.Index == fixedArgumentCounts.Count - 1 && variadicMinimum < 0 ? " or " : ", ");
				}
				invalidArgumentCount.AppendF($"argumentCount != {count + implicitArgumentCount}");
				expectedArgumentCounts.AppendF($"{count}");
			}
			if (variadicMinimum >= 0)
			{
				if (!invalidArgumentCount.IsEmpty)
				{
					invalidArgumentCount.Append(" && ");
					expectedArgumentCounts.Append(" or ");
				}
				invalidArgumentCount.AppendF($"argumentCount < {variadicMinimum + implicitArgumentCount}");
				expectedArgumentCounts.AppendF($"{variadicMinimum}+");
			}
			writer.If(invalidArgumentCount, scope (body) =>
			{
				if (dispatchKind == .InstanceMethod)
					body.If("argumentCount == 0 || !User2Type.IsLuaTinkerPointerUserdata(lua, 1)", """
						lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
						StackHelper.ThrowError(lua, lua.TinkerState);
						""");
				let actualArgumentCount = implicitArgumentCount == 0 ? "argumentCount" : "argumentCount - 1";
				body.Line(scope $"""
					lua.TinkerState.SetLastError($"expected '{expectedArgumentCounts}' arguments but got '{{{actualArgumentCount}}}'");
					StackHelper.ThrowError(lua, lua.TinkerState);
					""");
			});
			return argumentCounts;
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

			// Insert full signatures first so an exact arity wins over an omitted-default variant.
			let fullCandidateCount = candidates.Count;
			for (int i < fullCandidateCount)
			{
				let candidate = candidates[i];
				let method = candidate.Method;
				let hiddenCount = method.ParamCount - candidate.ParameterCount;
				let requiredCount = GetRequiredParameterCount(method) - hiddenCount;
				let fixedCount = GetFixedParameterCount(method) - hiddenCount;
				for (int count = fixedCount - 1; count >= requiredCount; count--)
					candidates.Add(.(method, candidate.ParameterStart, count, true));
			}

			Trie<MatchKey> paramsTrie = scope .();
			List<SelectorPosition> positions = scope .();
			BuildOverloadTrie(paramsTrie, candidates, parameters, positions, isConstructor);
			writer.Line("let argumentCount = lua.GetTop();");
			let argumentCounts = EmitArityCheck(candidates, parameters, writer, dispatchKind);

			let parameterlessNode = dispatchKind == .InstanceMethod && paramsTrie.OrderedChildren.Count == 1
				? paramsTrie.OrderedChildren[0] : paramsTrie;
			if (parameterlessNode.IsEnd && parameterlessNode.Children.IsEmpty)
			{
				if (dispatchKind == .InstanceMethod)
				{
					writer.If("!User2Type.IsLuaTinkerPointerUserdata(lua, 1)", """
						lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
						StackHelper.ThrowError(lua, lua.TinkerState);
						""");
					EmitReceiverValidation(parameterlessNode.Value.MatchType, writer);
				}
				EmitSelectedOverload<T>(candidates[parameterlessNode.CandidateIndex], parameters, writer, isConstructor);
				return;
			}

			writer.Line("OverloadFailure overloadFailure = .();");
			let requiresMatchTracking = RequiresMatchTracking(paramsTrie);
			if (requiresMatchTracking)
				writer.Line(scope $"bool[{positions.Count}] matchedOverloadArguments = .();");

			let dispatch = scope DispatchContext(candidates, parameters, positions, dispatchKind);
			delegate void(CodeWriter, ArgumentCountRange) emitEmpty = null;
			let variadicChild = FindVariadicChild(paramsTrie);
			let emptyNode = paramsTrie.IsEnd ? paramsTrie : variadicChild;
			if (emptyNode != null)
				emitEmpty = scope (body, counts) => EmitSelectedOverload<T>(candidates[emptyNode.CandidateIndex], parameters, body, isConstructor);
			EmitArityBranch(argumentCounts, isConstructor ? 2 : 1, writer, scope (body, counts) =>
			{
				IterateTrie<T>(BranchContext.ForRoot(dispatch, counts), paramsTrie, body);
			}, emitEmpty);

			if (requiresMatchTracking)
				writer.Line("overloadFailure.Throw(lua);");
		}
	}
}
