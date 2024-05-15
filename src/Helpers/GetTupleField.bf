using System;
using System.Reflection;

using internal LuaTinker.Helpers;

namespace LuaTinker.Helpers
{
	static
	{
		internal struct GetTupleField<T, C>
		    where C : const int
		{
		    public typealias Type = comptype(GetTupleFieldType(typeof(T), C));
		}

		typealias TupleField<T, C> = GetTupleField<T, C>.Type;

		[Comptime]
		public static Type GetTupleFieldType<T>(int index)
		{
			return GetTupleFieldType(typeof(T), index);
		}
		
		[Comptime]
		public static Type GetTupleFieldType(Type type, int index)
		{
			if (type.IsGenericParam)
				return typeof(var);
			if (!type.IsTuple)
				Runtime.FatalError(scope $"Type \"{type}\" isn't tuple");
			Runtime.Assert(type.FieldCount > index);
			return type.GetField(index).Get().FieldType;
		}
	}
}
