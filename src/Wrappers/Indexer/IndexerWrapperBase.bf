using KeraLua;
using System;

namespace LuaTinker.Wrappers
{
	public abstract class IndexerWrapperBase : ILuaOwnedObject
	{
		public virtual Type KeyType => null;
		public abstract void Get(Lua lua);
		public abstract void Set(Lua lua);

		public abstract IndexerWrapperBase CreateNew();

		public virtual void OnAddedToLua(LuaTinkerState tinkerState) {}
		public virtual void OnRemovedFromLua(LuaTinkerState tinkerState) {}
	}
}
