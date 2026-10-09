using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.Handlers;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpers
{
	internal struct NumericDispatch<T> where T : var, struct, INumeric
	{
		[Inline]
		public static void Push(Lua lua, T value) => lua.PushInteger((int64)value);

		public static T Pop(Lua lua, int32 index)
		{
			let res = lua.ToIntegerX(index);
			if (!res.HasValue)
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert '{lua.TypeName(index)}' to 'Number'");
				StackHelper.TryThrowError(lua, luaTinker);
				return default;
			}
			let value = res.GetValueOrDefault();
			if (!CanRepresentInteger(typeof(T), value))
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"number is out of range for the type '{typeof(T)}'");
				StackHelper.TryThrowError(lua, luaTinker);
				return default;
			}
			else
			{
				return (T)value;
			}
		}
	}

	extension StackHelper
	{
		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, INumeric
			=> NumericDispatch<T>.Push(lua, val);

		[Inline]
		public static void Push<T>(Lua lua, T? val) where T : var, struct, INumeric
		{
			if (!val.HasValue)
				lua.PushNil();
			else
				NumericDispatch<T>.Push(lua, val.Value);
		}

		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, INumeric
			=> NumericDispatch<T>.Pop(lua, index);

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
			let numericValue = value.GetValueOrDefault();
			if (!CanRepresentFloating(typeof(T), numericValue))
			{
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"number is out of range for the type '{typeof(T)}'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			return (T)numericValue;
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
