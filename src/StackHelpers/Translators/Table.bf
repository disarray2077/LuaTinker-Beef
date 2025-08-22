using KeraLua;

using internal KeraLua;
using internal LuaTinker;

namespace LuaTinker.StackHelpers;

extension StackHelper
{
	/// Pushes a LuaTable's referenced table onto the stack.
	public static void Push(Lua lua, LuaTable val)
	{
		val.PushOntoStack();
	}

	/// Pops a Lua table from the stack and wraps it in a LuaTable object.
	public static T Pop<T>(Lua lua, int32 index)
		where T : struct, LuaTable where LuaTable : T
	{
		if (lua.IsNil(index))
		{
			return default;
		}

		if (!lua.IsTable(index))
		{
			let tinkerState = lua.TinkerState;
			tinkerState.SetLastError($"expected 'Table' but got '{lua.TypeName(index)}'");
			TryThrowError(lua, tinkerState);
			return default;
		}

		return LuaTable(lua, index);
	}
}