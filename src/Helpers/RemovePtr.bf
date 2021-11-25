using System;
using System.Reflection;

namespace LuaTinker.Helpers
{
	static
	{
		public typealias RemovePtr<T> = comptype(RemovePtr(typeof(T)));

		[Comptime]
		public static Type RemovePtr(Type type)
		{
			if (type.IsPointer)
				return type.UnderlyingType;
			return type;
		}
	}
}
