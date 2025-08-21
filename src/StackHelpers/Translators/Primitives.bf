using System;
using System.Diagnostics;
using KeraLua;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, INumeric
		{
			lua.PushInteger((int64)val);
		}

		[Inline]
		public static void Push<T>(Lua lua, T? val) where T : var, struct, INumeric
		{
			if (!val.HasValue)
				lua.PushNil();
			else
				lua.PushInteger((int64)val);
		}

		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, INumeric
		{
			let res = lua.ToIntegerX(index);
			if (!res.HasValue)
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert '{lua.TypeName(index)}' to 'Number'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			let value = res.GetValueOrDefault();
			if (value > (int64)(T)value)
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"number is out of range for the type '{typeof(T)}'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			else
			{
				return (T)value;
			}
		}

		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, IFloating
		{
			lua.PushNumber((double)val);
		}

		[Inline]
		public static void Push<T>(Lua lua, T? val) where T : var, struct, IFloating
		{
			if (!val.HasValue)
				lua.PushNil();
			else
				lua.PushNumber((double)val);
		}

		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, IFloating
		{
			let value = lua.ToNumberX(index);
			if (!value.HasValue)
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert '{lua.TypeName(index)}' to 'Number'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			return (T)value.GetValueOrDefault();
		}

		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, ICharacter
		{
			lua.PushInteger((int64)val);
		}

		[Inline]
		public static void Push<T>(Lua lua, T? val) where T : var, struct, ICharacter
		{
			if (!val.HasValue)
				lua.PushNil();
			else
				lua.PushInteger((int64)val);
		}

		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, ICharacter
		{
			let value = lua.ToIntegerX(index);
			if (!value.HasValue)
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert '{lua.TypeName(index)}' to 'Number'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			return (T)value.GetValueOrDefault();
		}

		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, Boolean
		{
			lua.PushBoolean((bool)val);
		}

		[Inline]
		public static void Push<T>(Lua lua, T? val) where T : var, struct, Boolean
		{
			if (!val.HasValue)
				lua.PushNil();
			else
				lua.PushBoolean((bool)val);
		}

		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, Boolean
		{
			if (!lua.IsBoolean(index))
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"expected 'Boolean' but got '{lua.TypeName(index)}'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			return (T)lua.ToBoolean(index);
		}
	}
}
