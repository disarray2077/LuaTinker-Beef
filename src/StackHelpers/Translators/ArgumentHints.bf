using System;
using KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		public static T PopHinted<T>(Lua lua, int32 index) where T : var, struct, INumeric
		{
			if (TryGetNumericArgumentValue(lua, index, typeof(T), let hintedValue))
				return (T)hintedValue;
			return Pop<T>(lua, index);
		}

		public static T PopHinted<T>(Lua lua, int32 index) where T : var, struct, IFloating
		{
			if (TryGetFloatingArgumentValue(lua, index, typeof(T), let hintedValue))
				return (T)hintedValue;
			return Pop<T>(lua, index);
		}
	}
}
