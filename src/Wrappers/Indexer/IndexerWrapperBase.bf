using KeraLua;
using System;

namespace LuaTinker.Wrappers
{
	public abstract class IndexerWrapperBase
	{
		public virtual Type KeyType => null;
		public abstract void Get(Lua lua);
		public abstract void Set(Lua lua);

		public abstract IndexerWrapperBase CreateNew();
	}
}
