using System;
using KeraLua;
using LuaTinker.Helpers;

using internal LuaTinker;

namespace LuaTinker;

extension LuaTinker
{
	/// Allows Lua functions to be passed as call-scoped delegates of this signature.
	public void RegisterDelegate<D>() where D : Delegate
	{
		LuaDelegateAdapter<D>.ValidateSignature();
		mTinkerState.RegisterDelegate(typeof(D), => LuaDelegateAdapter<D>.Create, LuaDelegateAdapter<D>.StorageSize);
	}
}
