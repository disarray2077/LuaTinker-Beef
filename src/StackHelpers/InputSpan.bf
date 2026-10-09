using System;
using KeraLua;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	public enum InputSpanFailure
	{
		case None;
		case UnsupportedOverloadElementType(Type elementType);
		case ArgumentHint;
		case NotTable(StringView actualTypeName);
		case InvalidIntegerKey(int64 key);
		case InvalidNumericKey(double key);
		case InvalidKey(StringView actualTypeName);
		case TooManyElements;
		case MissingElement(int32 sequenceIndex);
		case ArgumentHintElement(int32 sequenceIndex);
		case InvalidElement(int32 sequenceIndex, Type elementType, StringView actualTypeName);

		public void SetError(LuaTinkerState state)
		{
			switch (this)
			{
			case .UnsupportedOverloadElementType(let elementType):
				state.SetLastError($"unsupported Span overload element type '{elementType}'");
			case .ArgumentHint:
				state.SetLastError("argument hint cannot bind to a fixed input Span");
			case .NotTable(let actualTypeName):
				state.SetLastError($"expected a dense sequence table for Span but got '{actualTypeName}'");
			case .InvalidIntegerKey(let key):
				state.SetLastError($"invalid input Span key {key}: expected a positive 1-based integer key");
			case .InvalidNumericKey(let key):
				state.SetLastError($"invalid input Span key {key}: expected a positive 1-based integer key");
			case .InvalidKey(let actualTypeName):
				state.SetLastError($"invalid input Span key of type '{actualTypeName}': expected a positive 1-based integer key");
			case .TooManyElements:
				state.SetLastError("input Span length exceeds int32 range");
			case .MissingElement(let sequenceIndex):
				state.SetLastError($"input Span is sparse: missing element {sequenceIndex}");
			case .ArgumentHintElement(let sequenceIndex):
				state.SetLastError($"argument hint is not a Span element (sequence index {sequenceIndex})");
			case .InvalidElement(let sequenceIndex, let elementType, let actualTypeName):
				state.SetLastError($"invalid Span element at sequence index {sequenceIndex}: expected '{elementType}' but got '{actualTypeName}'");
			case .None:
				state.SetLastError("invalid input Span");
			}
		}
	}

	extension StackHelper
	{
		[Inline]
		public static Result<int32, InputSpanFailure> CheckInputSpan<T>(Lua lua, int32 index, LuaType? knownType = null) where T : var
			=> CheckInputSpan(lua, index, typeof(T), knownType);

		public static Result<int32, InputSpanFailure> CheckInputSpan(Lua lua, int32 index, Type elementType, LuaType? knownType = null, bool checkElements = false)
		{
			let originalTop = lua.GetTop();
			defer lua.SetTop(originalTop);
			let tableIndex = lua.AbsIndex(index);
			let tableType = knownType.HasValue ? knownType.Value : lua.Type(tableIndex);
			if (IsArgumentHint(lua, tableIndex, tableType))
				return .Err(.ArgumentHint);
			if (tableType != .Table)
				return .Err(.NotTable(lua.TypeName(tableType)));

			// Count raw entries and reject keys that cannot form a dense 1-based sequence.
			int64 keyCount = 0;
			int64 maxKey = 0;
			lua.PushNil();
			while (lua.Next(tableIndex))
			{
				let keyType = lua.Type(-2);
				let integerKey = keyType == .Number ? lua.ToIntegerX(-2) : null;
				if (!integerKey.HasValue)
					return .Err(keyType == .Number ? .InvalidNumericKey(lua.ToNumber(-2)) : .InvalidKey(lua.TypeName(keyType)));
				let key = integerKey.Value;
				if (key <= 0)
					return .Err(.InvalidIntegerKey(key));
				if (key > int32.MaxValue || keyCount >= int32.MaxValue)
					return .Err(.TooManyElements);
				keyCount++;
				maxKey = Math.Max(maxKey, key);
				lua.Pop(1);
			}
			if (keyCount != maxKey)
			{
				// Search only the entry count, so one very large sparse key cannot cause a long scan.
				for (int64 sequenceIndex = 1; sequenceIndex <= keyCount; sequenceIndex++)
				{
					let missing = lua.RawGetInteger(tableIndex, sequenceIndex) == .Nil;
					lua.Pop(1);
					if (missing)
						return .Err(.MissingElement((int32)sequenceIndex));
				}
			}
			for (int32 sequenceIndex = 1; sequenceIndex <= (int32)keyCount; sequenceIndex++)
			{
				let actualType = lua.RawGetInteger(tableIndex, sequenceIndex);
				if (IsArgumentHint(lua, -1, actualType))
					return .Err(.ArgumentHintElement(sequenceIndex));
				if (checkElements && (elementType == typeof(String) ? actualType != .String :
					actualType != .Number || !IsNumericArgument(lua, -1, elementType)))
					return .Err(.InvalidElement(sequenceIndex, elementType, lua.TypeName(actualType)));
				lua.Pop(1);
			}
			return .Ok((int32)keyCount);
		}

		public static bool IsPlainIntegerInputSpan(Lua lua, int32 index, int32 count)
		{
			if (count <= 0 || IsArgumentHint(lua, index) || lua.Type(index) != .Table)
				return false;
			let tableIndex = lua.AbsIndex(index);
			for (int32 sequenceIndex = 1; sequenceIndex <= count; sequenceIndex++)
			{
				lua.RawGetInteger(tableIndex, sequenceIndex);
				let plainInteger = IsPlainIntegerArgument(lua, -1);
				lua.Pop(1);
				if (!plainInteger)
					return false;
			}
			return true;
		}
	}
}
