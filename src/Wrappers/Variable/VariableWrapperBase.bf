using KeraLua;

namespace LuaTinker.Wrappers
{
	abstract class VariableWrapperBase
	{
		public abstract void Get(Lua lua);
		public abstract void Set(Lua lua);
	}
}
