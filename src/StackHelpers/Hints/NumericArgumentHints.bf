using System;
using KeraLua;
using LuaTinker.Helpers;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		internal static void PushNumericArgumentHint(Lua lua, Type type, int64 value)
		{
			StackHelper.RegisterArgumentHintMetatable(lua);
			lua.CreateTable(3, 0);
			lua.PushInteger(3);
			lua.RawSetInteger(-2, 1);
			lua.PushInteger(type.GetTypeId());
			lua.RawSetInteger(-2, 2);
			lua.PushInteger(value);
			lua.RawSetInteger(-2, 3);
			StackHelper.SetArgumentHintMetatable(lua, type);
		}

		internal static void PushNumericArgumentHint(Lua lua, Type type, double value)
		{
			StackHelper.RegisterArgumentHintMetatable(lua);
			lua.CreateTable(3, 0);
			lua.PushInteger(3);
			lua.RawSetInteger(-2, 1);
			lua.PushInteger(type.GetTypeId());
			lua.RawSetInteger(-2, 2);
			lua.PushNumber(value);
			lua.RawSetInteger(-2, 3);
			StackHelper.SetArgumentHintMetatable(lua, type);
		}

		// Cast and enum registration paths validate the fields of recognized hints.
		private static bool HasNumericArgumentHintType(Lua lua, int32 index, Type expectedType)
		{
			if (!IsArgumentHint(lua, index))
				return false;
			let hintIndex = lua.AbsIndex(index);
			lua.RawGetInteger(hintIndex, 1);
			let tag = lua.ToInteger(-1);
			lua.Pop(1);
			if (tag != 3)
				return false;
			lua.RawGetInteger(hintIndex, 2);
			let typeId = lua.ToInteger(-1);
			lua.Pop(1);
			return typeId == expectedType.GetTypeId();
		}


		public static bool TryGetNumericArgumentValue(Lua lua, int32 index, Type expectedType, out int64 value)
		{
			value = 0;
			if (!HasNumericArgumentHintType(lua, index, expectedType))
				return false;
			let hintIndex = lua.AbsIndex(index);
			lua.RawGetInteger(hintIndex, 3);
			value = lua.ToInteger(-1);
			lua.Pop(1);
			return true;
		}

		public static bool TryGetFloatingArgumentValue(Lua lua, int32 index, Type expectedType, out double value)
		{
			value = 0;
			if (!HasNumericArgumentHintType(lua, index, expectedType))
				return false;
			let hintIndex = lua.AbsIndex(index);
			lua.RawGetInteger(hintIndex, 3);
			value = lua.ToNumberX(-1).GetValueOrDefault();
			lua.Pop(1);
			return true;
		}

		public static bool IsNumericArgument(Lua lua, int32 index, Type type)
		{
			if (IsArgumentHint(lua, index))
			{
				if (type.IsFloatingPoint)
					return TryGetFloatingArgumentValue(lua, index, type, let ignored);
				return TryGetNumericArgumentValue(lua, index, type, let ignored);
			}
			if (!lua.IsNumber(index) || lua.IsString(index))
				return false;
			var resolvedType = type;
			if (resolvedType.IsEnum || resolvedType.IsTypedPrimitive)
				resolvedType = resolvedType.UnderlyingType;
			if (resolvedType.IsInteger || resolvedType.IsChar)
			{
				if (let value = lua.ToIntegerX(index))
					return CanRepresentInteger(resolvedType, value);
				return false;
			}
			return resolvedType.IsFloatingPoint && CanRepresentFloating(resolvedType, lua.ToNumber(index));
		}

		[Inline]
		public static bool IsPlainIntegerArgument(Lua lua, int32 index)
			=> lua.IsInteger(index);
	}
}
