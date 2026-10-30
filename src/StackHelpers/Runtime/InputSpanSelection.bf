using System;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		[Inline]
		public static bool CanSelectInputSpanElement(Type type)
			=> type == typeof(String) || IsNumericType(type);

		public static int32 SelectInputSpan<Types>(Lua lua, int32 index, int32 argument) where Types : var
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
				Runtime.Assert(candidateType.IsTuple);
				String elementTypes = scope .();
				for (let field in candidateType.GetFields(.DeclaredOnly))
				{
					if (@field.Index > 0)
						elementTypes.Append(", ");
					elementTypes.AppendF($"typeof(comptype({field.FieldType.GetTypeId()}))");
				}
				Compiler.MixinRoot(scope $"""
					static Type[{candidateType.FieldCount}] elementTypes = .({elementTypes});
					return SelectInputSpan(lua, index, elementTypes, argument);
					""");
			}

			EmitCandidateData<Types>();
			// Generic analysis cannot see the return supplied by the mixin.
			Runtime.FatalError("Not reached");
		}

		public static int32 SelectInputSpan(Lua lua, int32 index, Span<Type> elementTypes, int32 argument)
		{
			let matchingTypes = scope bool[elementTypes.Length];
			int32 matches = 0;
			int32 int32Index = -1;
			InputSpanFailure failure = .None;
			for (let elementType in elementTypes)
			{
				if (!CanSelectInputSpanElement(elementType))
				{
					failure = .UnsupportedOverloadElementType(elementType);
					continue;
				}
				matchingTypes[@elementType.Index] = true;
				if (elementType == typeof(int32) && int32Index < 0)
					int32Index = (int32)@elementType.Index;
				matches++;
			}
			if (matches == 0)
			{
				failure.SetError(lua.TinkerState);
				TryThrowError(lua, lua.TinkerState);
				return -1;
			}
			int32 count;
			switch (CheckInputSpanSequence(lua, index))
			{
			case .Ok(let sequenceCount):
				count = sequenceCount;
			case .Err(let sequenceFailure):
				sequenceFailure.SetError(lua.TinkerState);
				TryThrowError(lua, lua.TinkerState);
				return -1;
			}
			let tableIndex = lua.AbsIndex(index);
			// A nonempty plain-integer sequence prefers int32; empty tables have no preference.
			bool preferInt32 = count > 0 && int32Index >= 0;
			for (int32 sequenceIndex = 1; sequenceIndex <= count && matches > 0; sequenceIndex++)
			{
				let actualType = lua.RawGetInteger(tableIndex, sequenceIndex);
				let isHint = IsArgumentHint(lua, -1, actualType);
				if (preferInt32 && !IsPlainIntegerArgument(lua, -1))
					preferInt32 = false;
				for (let elementType in elementTypes)
				{
					if (!matchingTypes[@elementType.Index])
						continue;
					if (isHint || (elementType == typeof(String) ? actualType != .String :
						actualType != .Number || !IsNumericArgument(lua, -1, elementType)))
					{
						matchingTypes[@elementType.Index] = false;
						matches--;
						failure = isHint ? .ArgumentHintElement(sequenceIndex) :
							.InvalidElement(sequenceIndex, elementType, lua.TypeName(actualType));
					}
				}
				lua.Pop(1);
			}
			if (preferInt32 && matchingTypes[int32Index])
				return int32Index;
			if (matches > 1)
			{
				lua.TinkerState.SetLastError($"ambiguous span overload at argument {argument}");
				ThrowError(lua, lua.TinkerState);
			}
			if (matches == 0)
			{
				failure.SetError(lua.TinkerState);
				TryThrowError(lua, lua.TinkerState);
			}
			for (let elementType in elementTypes)
				if (matchingTypes[@elementType.Index])
					return (int32)@elementType.Index;
			return -1;
		}
	}
}
