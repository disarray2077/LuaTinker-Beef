using System;
using System.Reflection;

namespace LuaTinker.Helpers
{
	static
	{
		public struct GetTupleField<T, C>
		    where C : const int
		{
		    public typealias Type = comptype(getTupleFieldType(typeof(T), C));

		    [Comptime]
			private static Type getTupleFieldType(Type type, int index)
			{
				if (type.IsGenericParam)
					return typeof(var);
				if (!type.IsTuple)
					Runtime.FatalError(scope $"Type \"{type}\" isn't tuple");
				Compiler.Assert(type.FieldCount > index);
				return type.GetField(index).Get().FieldType;
			}
		}
	}
}
