using KeraLua;

namespace LuaTinker.Wrappers
{
	public abstract class VariableWrapperBase
	{
		public abstract void Get(Lua lua);
		public abstract void Set(Lua lua);
	}
}
