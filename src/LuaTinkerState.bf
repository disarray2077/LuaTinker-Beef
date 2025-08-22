using System;
using System.Diagnostics;
using System.Collections;
using System.Reflection;
using KeraLua;
using LuaTinker.Wrappers;

namespace LuaTinker
{
	public class LuaTinkerState
	{
		private Dictionary<TypeId, String> mClassNames = new .() ~ DeleteDictionaryAndValues!(_);
		private String mLastError = new .() ~ delete _;

		public bool IsPCall { get; private set; }
		public bool HasError => !mLastError.IsEmpty;

		// This exists only to make GC happy.
		internal List<Object> mAliveObjects = new .() ~ delete _;

		public this()
		{
		}

		public void RegisterAliveObject(Object obj)
		{
			mAliveObjects.Add(obj);
		}

		public void RegisterAliveObject<T>(T obj)
			where T : class, ILuaOwnedObject
		{
			obj.OnAddedToLua(this);
			mAliveObjects.Add(obj);
		}

		public void DeregisterAliveObject(Object obj)
		{
			mAliveObjects.Remove(obj);
		}

		public void DeregisterAliveObject<T>(T obj)
			where T : class, ILuaOwnedObject
		{
			obj.OnRemovedFromLua(this);
			mAliveObjects.Remove(obj);
		}

		public void ClearError()
		{
			mLastError.Clear();
		}

		public void SetLastError(StringView errStr)
		{
			mLastError.Set(errStr);
		}

		public void SetLastError(StringView errStr, params Span<Object> args)
		{
			mLastError.Clear();
			mLastError.AppendF(errStr, params args);
		}

		public String GetLastError()
		{
			return mLastError;
		}

		public bool IsClassRegistered<T>()
		{
			return mClassNames.ContainsKey(typeof(T).TypeId);
		}

		public StringView GetClassName<T>()
		{
			if (mClassNames.TryGetValue(typeof(T).TypeId, let name))
				return .(name);
			Runtime.FatalError("GetClassName() failed");
		}

		public void SetClassName<T>(StringView name)
		{
			if (mClassNames.TryAdd(typeof(T).TypeId, let keyPtr, let valuePtr))
			{
				*valuePtr = new String(name);
			}
			else
			{
				let nameStr = *valuePtr;
				nameStr.Clear();
				nameStr.Set(name);
				nameStr.EnsureNullTerminator();
			}
		}
	}
}
