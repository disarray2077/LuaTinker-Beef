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
		public static void Push<T>(Lua lua, T? val) where T : var, struct, INumeric
		{
			if (!val.HasValue)
				lua.PushNil();
			else
				lua.PushInteger((int64)val);
		}

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
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"can't convert '{lua.TypeName(index)}' to 'Number'");
				lua.Error();
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
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				lua.PushString($"expected 'Boolean' but got '{lua.TypeName(index)}'");
				lua.Error();
			}
			return (T)lua.ToBoolean(index);
		}
	}
}
