using System;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		private struct NumericCandidate : this(Type Type, bool IsEnumLike);

		public static int32 SelectNumeric<Types>(Lua lua, int32 index, int32 argument)
			where Types : var
		{
			[Comptime]
			static void EmitCandidateData<Types>()
			{
				let candidateType = typeof(Types);
				if (candidateType.IsGenericParam)
				{
					Compiler.MixinRoot("return -1;");
					return;
				}
				if (!candidateType.IsTuple)
				{
					Compiler.MixinRoot(scope $"return IsNumericArgument(lua, index, typeof(comptype({candidateType.GetTypeId()}))) ? 0 : -1;");
					return;
				}

				let count = candidateType.FieldCount;
				String candidates = scope .();
				String names = scope .();
				int32 int32Index = -1;
				for (int i < count)
				{
					let type = candidateType.GetField(i).Get().FieldType;
					if (i > 0)
					{
						candidates.Append(", ");
						names.Append(", ");
					}
					if (type == typeof(int32))
						int32Index = (int32)i;
					let isEnumLike = type.IsEnum || type.IsTypedPrimitive;
					candidates.AppendF($".(typeof(comptype({type.GetTypeId()})), {isEnumLike ? "true" : "false"})");
					names.Append((scope $"{type}").Quote(.. scope .()));
				}
				Compiler.MixinRoot(scope $"""
					static NumericCandidate[{count}] candidates = .({candidates});
					bool[{count}] matchingTypes = .();
					let selected = SelectNumeric(lua, index, candidates, {int32Index}, matchingTypes, let ambiguous);
					if (ambiguous)
					{{
						static StringView[{count}] numericTypeNames = .({names});
						ThrowNumericAmbiguity(lua, argument, numericTypeNames, matchingTypes);
					}}
					return selected;
					""");
			}

			EmitCandidateData<Types>();
			// Generic analysis cannot see the return supplied by the mixin.
			Runtime.FatalError("Not reached");
		}

		// Returns the candidate index, or -1 for no match or ambiguity, without changing the stack.
		// On ambiguity, matchingTypes contains only the surviving candidates.
		private static int32 SelectNumeric(Lua lua, int32 index, Span<NumericCandidate> candidates, int32 int32Index, Span<bool> matchingTypes, out bool ambiguous)
		{
			ambiguous = false;
			if (lua.Type(index) != .Number && !IsArgumentHint(lua, index))
				return -1;

			// Plain integers prefer int32 over other primitives; enum-like types still compete.
			// Explicit hints select their requested type without this preference.
			let matchesInt32 = int32Index >= 0 && IsNumericArgument(lua, index, typeof(int32));
			let preferInt32 = matchesInt32 && IsPlainIntegerArgument(lua, index);
			int32 selected = -1;
			int32 matches = 0;
			int32 enumMatches = 0;
			// Retain matching candidates for ambiguity diagnostics as well as selection.
			for (int i < candidates.Length)
			{
				let candidate = candidates[i];
				let matched = i == int32Index ? matchesInt32 :
					(!preferInt32 || candidate.IsEnumLike) && IsNumericArgument(lua, index, candidate.Type);
				matchingTypes[i] = matched;
				if (!matched)
					continue;
				selected = (int32)i;
				matches++;
				if (candidate.IsEnumLike)
					enumMatches++;
			}
			// Among competing enum-like types, prefer those defining the unhinted value.
			// If none defines it, keep all range-compatible matches.
			if (enumMatches > 1 && !IsArgumentHint(lua, index))
			{
				let value = lua.ToInteger(index);
				bool hasDefinedEnum = false;
				for (int i < candidates.Length)
				{
					let candidate = candidates[i];
					if (matchingTypes[i] && candidate.IsEnumLike && Enum.IsDefined(candidate.Type, value))
					{
						hasDefinedEnum = true;
						break;
					}
				}
				if (hasDefinedEnum)
				{
					for (int i < candidates.Length)
					{
						let candidate = candidates[i];
						if (matchingTypes[i] && candidate.IsEnumLike && !Enum.IsDefined(candidate.Type, value))
						{
							matchingTypes[i] = false;
							matches--;
						}
					}
					// Filtering may remove the last recorded match; locate the sole survivor.
					if (matches == 1)
						for (int i < candidates.Length)
							if (matchingTypes[i])
							{
								selected = (int32)i;
								break;
							}
				}
			}
			ambiguous = matches > 1;
			return ambiguous ? -1 : selected;
		}

		[NoReturn]
		private static void ThrowNumericAmbiguity(Lua lua, int32 argument, Span<StringView> typeNames, Span<bool> matchingTypes)
		{
			let state = lua.TinkerState;
			state.SetLastError($"ambiguous numeric overload at argument {argument} (");
			let message = state.GetLastError();
			bool first = true;
			for (int i < typeNames.Length)
			{
				if (!matchingTypes[i])
					continue;
				if (!first)
					message.Append(" or ");
				message.Append('\'');
				message.Append(typeNames[i]);
				message.Append('\'');
				first = false;
			}
			message.Append(')');
			ThrowError(lua, state);
		}
	}
}
