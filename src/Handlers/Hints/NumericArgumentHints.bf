using System;
using KeraLua;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;

using internal KeraLua;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.Handlers
{
	static
	{
		public static int32 NumericArgumentCastHandler<T>(lua_State L) where T : var
		{
			let lua = Lua.FromIntPtr(L);
			bool valid = lua.GetTop() == 1 && lua.IsNumber(1) && !lua.IsString(1);
			if (typeof(T).IsFloatingPoint)
			{
				double floatingValue = 0;
				if (valid)
				{
					let parsed = lua.ToNumberX(1);
					valid = parsed.HasValue;
					if (valid)
						floatingValue = parsed.GetValueOrDefault();
				}
				if (!valid || !CanRepresentFloating(typeof(T), floatingValue))
				{
					lua.TinkerState.SetLastError($"invalid floating-point cast to '{typeof(T)}'");
					StackHelper.ThrowError(lua, lua.TinkerState);
				}
				StackHelper.PushNumericArgumentHint(lua, typeof(T), floatingValue);
				return 1;
			}
			int64 value = 0;
			if (valid)
			{
				let parsed = lua.ToIntegerX(1);
				valid = parsed.HasValue;
				if (valid)
					value = parsed.GetValueOrDefault();
			}
			if (!valid || !CanRepresentInteger(typeof(T), value))
			{
				lua.TinkerState.SetLastError($"invalid integer cast to '{typeof(T)}'");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}
			StackHelper.PushNumericArgumentHint(lua, typeof(T), value);
			return 1;
		}

	}
}
