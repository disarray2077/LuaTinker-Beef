using System;
using System.Diagnostics;
using KeraLua;

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
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, INumeric
		{
			let value = lua.ToIntegerX(index);
			if (!value.HasValue)
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"can't convert '{lua.TypeName(index)}' to 'Number'");
				lua.Error();
			}
			return (T)value.GetValueOrDefault();
		}

		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, IFloating
		{
			lua.PushNumber((double)val);
		}

		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, IFloating
		{
			let value = lua.ToNumberX(index);
			if (!value.HasValue)
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"can't convert '{lua.TypeName(index)}' to 'Number'");
				lua.Error();
			}
			return (T)value.GetValueOrDefault();
		}

		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, Char8
			=> PushChar<T>(val);

		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, Char16
			=> PushChar<T>(val);

		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, Char32
			=> PushChar<T>(val);

		// TODO: Refactor this when (or if) ICharacter is implemented.
		private static void PushChar<T>(Lua lua, T val) where T : var
		{
			lua.PushInteger((int64)val);
		}

		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, Char8
			=> PopChar<T>(lua, index);

		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, Char16
			=> PopChar<T>(lua, index);

		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, Char32
			=> PopChar<T>(lua, index);

		// TODO: Refactor this when (or if) ICharacter is implemented.
		private static T PopChar<T>(Lua lua, int32 index)
			where T : var
		{
			let value = lua.ToIntegerX(index);
			if (!value.HasValue)
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"can't convert '{lua.TypeName(index)}' to 'Number'");
				lua.Error();
			}
			return (T)value.GetValueOrDefault();
		}

		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var, struct, Boolean
		{
			lua.PushBoolean((bool)val);
		}

		[Inline]
		public static T Pop<T>(Lua lua, int32 index) where T : var, struct, Boolean
		{
			if (!lua.IsBoolean(index))
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"expected 'Boolean' but got '{lua.TypeName(index)}'");
				lua.Error();
			}
			return (T)lua.ToBoolean(index);
		}
	}
}
