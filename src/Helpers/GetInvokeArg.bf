using System;
using System.Reflection;

using internal LuaTinker.Helpers;

namespace LuaTinker.Helpers
{
	static
	{
		internal struct GetInvokeArg<F, C>
		    where C : const int
		{
		    public typealias Type = comptype(GetInvokeArgType(typeof(F), C));
		}

		typealias InvokeArg<F, C> = GetInvokeArg<F, C>.Type;

		[Comptime]
		public static Type GetInvokeArgType<T>(int index)
		{
			return GetInvokeArgType(typeof(T), index);
		}

		[Comptime]
		public static Type GetInvokeArgType(Type type, int index)
		{
			let invokeMethodResult = type.GetMethod("Invoke");
			if (invokeMethodResult case .Err)
			{
				if ((type as SpecializedGenericType) == null)
					return typeof(void);
				else
					Runtime.FatalError(scope $"Type \"{type}\" isn't invokable");
			}

			let invokeMethod = invokeMethodResult.Get();
			Runtime.Assert(invokeMethod.ParamCount > index);

			return invokeMethod.GetParamType(index);
		}
	}
}
