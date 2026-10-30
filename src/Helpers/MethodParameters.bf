using System;
using System.Reflection;

namespace LuaTinker.Helpers;

static
{
	[Inline]
	internal static int GetFixedParameterCount(MethodInfo method) =>
		method.ParamCount - ((method.ParamCount > 0 && method.GetParamFlags(method.ParamCount - 1).HasFlag(.Params)) ? 1 : 0);

	internal static int GetRequiredParameterCount(MethodInfo method)
	{
		int count = GetFixedParameterCount(method);
		while (count > 0 && method.GetParamFlags(count - 1).HasFlag(.HasDefault))
			count--;
		return count;
	}
}
