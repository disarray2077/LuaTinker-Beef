using KeraLua;

namespace LuaTinker.Wrappers
{
	public abstract class VariableWrapperBase : ILuaOwnedObject
	{
		public abstract void Get(Lua lua);
		public abstract void Set(Lua lua);

		public virtual void OnRemoveFromLua(LuaTinkerState tinkerState) {}
	}
}
