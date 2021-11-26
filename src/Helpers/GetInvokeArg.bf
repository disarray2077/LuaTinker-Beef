using System;
using System.Reflection;

namespace LuaTinker.Helpers
{
	static
	{
		public struct GetInvokeArg<F, C>
		    where C : const int
		{
		    public typealias Type = comptype(getInvokeArgumentType(typeof(F), getConst()));

		    [Comptime]
			private static Type getInvokeArgumentType(Type type, int index)
			{
				let invokeMethodResult = type.GetMethod("Invoke");
				if (invokeMethodResult case .Err)
				{
					if ((type as SpecializedGenericType) == null)
						return typeof(void);
					else
						Runtime.FatalError("Type isn't invokable");
				}

				let invokeMethod = invokeMethodResult.Get();
				Compiler.Assert(invokeMethod.ParamCount > index);

				return invokeMethod.GetParamType(index);
			}

		    [Comptime]
		    private static int getConst()
		    {
		        return C;
		    }
		}
	}
}