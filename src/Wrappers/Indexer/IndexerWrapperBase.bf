using KeraLua;
using System;

namespace LuaTinker.Wrappers
{
	public abstract class IndexerWrapperBase : ILuaOwnedObject
	{
		public virtual Type KeyType => null;
		public abstract bool Get(Lua lua);
		public abstract bool Set(Lua lua);

		public abstract IndexerWrapperBase CreateNew();

		public virtual void OnAddedToLua(LuaTinkerState tinkerState) {}
		public virtual void OnRemovedFromLua(LuaTinkerState tinkerState) {}
	}
}
