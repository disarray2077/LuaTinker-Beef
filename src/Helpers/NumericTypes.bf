using System;

namespace LuaTinker.Helpers
{
	static
	{
		[Inline]
		public static bool IsPrimitiveNumericType(Type type)
		    => !IsFunctionType(type) && (type.IsInteger || type.IsFloatingPoint);

		[Inline]
		public static bool IsTypedNumericType(Type type)
		    => (type.IsEnum && !type.IsUnion) ||
		       (type.IsTypedPrimitive && IsPrimitiveNumericType(type.UnderlyingType));

		[Inline]
		public static bool IsNumericType(Type type)
		    => IsPrimitiveNumericType(type) || IsTypedNumericType(type);

		public static bool CanRepresentInteger(Type type, int64 value)
		{
			var resolvedType = type;
			if (IsTypedNumericType(resolvedType))
				resolvedType = resolvedType.UnderlyingType;
			if (!resolvedType.IsInteger)
				return false;
			if (resolvedType.IsSigned)
			{
				if (resolvedType.Size >= sizeof(int64))
					return true;
				let maxValue = (1L << (resolvedType.Size * 8 - 1)) - 1;
				let minValue = -maxValue - 1;
				return value >= minValue && value <= maxValue;
			}
			if (value < 0)
				return false;
			if (resolvedType.Size >= sizeof(uint64))
				return true;
			let maxValue = (1UL << (resolvedType.Size * 8)) - 1;
			return (uint64)value <= maxValue;
		}

		public static bool CanRepresentFloating(Type type, double value)
		{
			let resolvedType = type.IsTypedPrimitive ? type.UnderlyingType : type;
			if (resolvedType == typeof(float))
				return value >= -float.MaxValue && value <= float.MaxValue;
			if (resolvedType == typeof(double))
				return value >= -double.MaxValue && value <= double.MaxValue;
			return false;
		}
	}
}
