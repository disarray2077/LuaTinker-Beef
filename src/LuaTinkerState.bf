using System;
using System.Diagnostics;
using System.Collections;
using System.Reflection;
using KeraLua;

namespace LuaTinker
{
	public class LuaTinkerState
	{
		private int mRefCount = 0;
		private Dictionary<TypeId, String> mClassNames = new .() ~ DeleteDictionaryAndValues!(_);
		private Dictionary<String, Type> mClassTypes = new .() ~ DeleteDictionaryAndKeys!(_);

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

		public Result<Type> GetClassType(StringView name)
		{
			if (mClassTypes.TryGetValueAlt(name, let type))
				return .Ok(type);
			return .Err;
		}
		
		private static Dictionary<Lua, LuaTinkerState> Instances = new .() ~ DeleteDictionaryAndValues!(_);

		// Get the LuaTinkerState associated with this LuaState
		public static LuaTinkerState Find(Lua luaState)
		{
			return Instances.TryGetValue(luaState, .. let value);
		}

		public static LuaTinkerState GetOrAdd(Lua luaState)
		{
			if (Instances.TryAdd(luaState, let keyPtr, let valuePtr))
			{
				*valuePtr = new LuaTinkerState();
			}

			(*valuePtr).mRefCount++;
			return *valuePtr;
		}

		public static void Remove(Lua luaState)
		{
			if (Instances.GetAndRemove(luaState) case .Ok(let kvPair))
			{
				kvPair.value.mRefCount--;
				if (kvPair.value.mRefCount == 0)
					delete kvPair.value;
			}
		}
	}
}
