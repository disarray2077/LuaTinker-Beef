using System;
using System.Diagnostics;
using System.Collections;
using System.Reflection;
using KeraLua;
using LuaTinker.Handlers;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;

using internal KeraLua;
using internal LuaTinker;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		public static void Push<T>(Lua lua, T? val) where T : var
		{
			if (!val.HasValue)
				lua.PushNil();
			else
				Push<T>(lua, val.Value);
		}

		private static void SetClassMetatable(Lua lua, Type declaredType)
		{
			let state = lua.TinkerState;
			if (lua.Type(-1) == .UserData && state.IsClassRegistered(declaredType))
			{
				state.PushClassMetatable(lua, declaredType);
				lua.SetMetaTable(-2);
			}
		}

		[Inline]
		public static void Push<T>(Lua lua, T val) where T : var
		{
			Type2User.Create(lua, val);
			SetClassMetatable(lua, typeof(RemovePtr<T>));
		}

		[Inline]
		public static void Push<T>(Lua lua, ref T val) where T : var
		{
			Type2User.Create<T>(lua, ref val);
			SetClassMetatable(lua, typeof(RemovePtr<T>));
		}

		public static void Push(Lua lua, Object val)
		{
			if (val == null)
			{
				lua.PushNil();
				return;
			}

			if (var s = val as String)
			{
				lua.PushString(s);
			}
			else if (var sv = val as StringView?)
			{
				lua.PushString(sv);
			}
			else if (var n = val as INumeric)
			{
				lua.PushInteger((int64)n);
			}
			else if (var f = val as IFloating)
			{
				lua.PushNumber((double)f);
			}
			else if (var b = val as bool?)
			{
				lua.PushBoolean(b);
			}
			else
			{
				Push<Object>(lua, val);
			}
		}
	}
}
