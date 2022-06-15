using System;
using System.Reflection;

namespace LuaTinker.Helpers
{
	static
	{
		public struct GetInvokeArg<F, C>
		    where C : const int
		{
		    public typealias Type = comptype(getInvokeArgumentType(typeof(F), C));

		    [Comptime]
			private static Type getInvokeArgumentType(Type type, int index)
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
}
