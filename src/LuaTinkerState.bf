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
		private String mLastError = new .() ~ delete _;
		public bool IsPCall { get; private set; }
		public bool HasError => !mLastError.IsEmpty;

		public this()
		{
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

		public Result<Type> GetClassType(StringView name)
		{
			if (mClassTypes.TryGetValueAlt(name, let type))
				return .Ok(type);
			return .Err;
		}
	}
}
