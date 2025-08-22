namespace LuaTinker.Wrappers;

interface ILuaOwnedObject
{
	public void OnAddedToLua(LuaTinkerState tinkerState);
	public void OnRemovedFromLua(LuaTinkerState tinkerState);
}