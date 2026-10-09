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
			int32 selected = -1;
			int32 matches = 0;
			InputSpanFailure firstFailure = .None;
			for (let elementType in elementTypes)
			{
				if (!CanSelectInputSpanElement(elementType))
				{
					if (firstFailure case .None)
						firstFailure = .UnsupportedOverloadElementType(elementType);
					continue;
				}
				int32 count;
				switch (CheckInputSpan(lua, index, elementType, checkElements: true))
				{
				case .Ok(let sequenceCount):
					count = sequenceCount;
				case .Err(let failure):
					if (firstFailure case .None)
						firstFailure = failure;
					continue;
				}
				// A nonempty plain-integer sequence prefers int32; empty tables have no preference.
				if (elementType == typeof(int32) && IsPlainIntegerInputSpan(lua, index, count))
					return (int32)@elementType.Index;
				selected = (int32)@elementType.Index;
				matches++;
			}
			if (matches > 1)
			{
				lua.TinkerState.SetLastError($"ambiguous span overload at argument {argument}");
				ThrowError(lua, lua.TinkerState);
			}
			if (matches == 0)
			{
				firstFailure.SetError(lua.TinkerState);
				TryThrowError(lua, lua.TinkerState);
			}
			return selected;
		}
	}
}
