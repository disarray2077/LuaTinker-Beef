using System;
using System.Reflection;

namespace LuaTinker.Helpers
{
	static
	{
		public struct GetTupleField<T, C>
		    where C : const int
		{
		    public typealias Type = comptype(getTupleFieldType(typeof(T), getConst()));

		    [Comptime]
			private static Type getTupleFieldType(Type type, int index)
			{
				if (!type.IsTuple)
					Runtime.FatalError("Type isn't tuple");
				Compiler.Assert(type.FieldCount > index);
				return type.GetField(index).Get().FieldType;
			}

		    [Comptime]
		    private static int getConst()
		    {
		        return C;
		    }
		}
	}
}
