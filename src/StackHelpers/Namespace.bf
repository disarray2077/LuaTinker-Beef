using System;
using KeraLua;
using LuaTinker.Handlers;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		private static uint8 sNamespaceBindingsKey;

		/// Pushes the namespace metatable and its live field bindings.
		internal static void PushNamespaceBindings(Lua lua)
		{
			if (!lua.GetMetaTable(-1))
				lua.CreateTable(0, 3);
			lua.PushString("__index");
			lua.PushCClosure(=> NamespaceIndexGetHandler, 0);
			lua.RawSet(-3);
			lua.PushString("__newindex");
			lua.PushCClosure(=> NamespaceIndexSetHandler, 0);
			lua.RawSet(-3);
			if (lua.RawGetByHashCode(lua.AbsIndex(-1), &sNamespaceBindingsKey) == .Nil)
			{
				lua.Pop(1);
				lua.CreateTable(0, 4);
				lua.PushValue(-1);
				lua.RawSetByHashCode(lua.AbsIndex(-3), &sNamespaceBindingsKey);
			}
		}

		internal static LuaType GetNamespaceBinding(Lua lua)
		{
			lua.GetMetaTable(1);
			lua.RawGetByHashCode(lua.AbsIndex(-1), &sNamespaceBindingsKey);
			lua.PushValue(2);
			return lua.RawGet(-2);
		}
	}
}
