using System;
using System.Diagnostics;
using System.Collections;
using System.Reflection;
using KeraLua;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker
{
	public class LuaTinkerState
	{
		private class ClassRegistration
		{
			// This registration's stable address is its private registry key for the state's lifetime.
			public String Name ~ delete _;
			public this(StringView name) { Name = new .(name); }
		}

		private struct DelegateRegistration
		{
			public function Object(Lua, int32, ITypedAllocator) Factory;
			public int AllocationSize;
		}

		private Dictionary<TypeId, ClassRegistration> mClasses = new .() ~ DeleteDictionaryAndValues!(_);
		private Dictionary<TypeId, DelegateRegistration> mDelegates = new .() ~ delete _;
		private String mLastError = new .() ~ delete _;

		public bool IsPCall { get; internal set; }
		public bool HasError => !mLastError.IsEmpty;

#if BF_ENABLE_REALTIME_LEAK_CHECK
		// Keep Lua-owned Beef objects visible to realtime leak tracking.
		internal List<Object> mAliveObjects = new .() ~ delete _;
#endif

		public this()
		{
		}

		[Inline]
		internal void RegisterDelegate(Type type, function Object(Lua, int32, ITypedAllocator) factory, int allocationSize)
			=> mDelegates[type.TypeId] = .() { Factory = factory, AllocationSize = allocationSize };

		[Inline]
		internal bool IsDelegateRegistered(Type type) => mDelegates.ContainsKey(type.TypeId);

		[Inline]
		internal int GetDelegateAllocationSize(Type type)
			=> mDelegates.TryGetValue(type.TypeId, let registration) ? registration.AllocationSize : 0;

		internal Object CreateDelegate(Type type, Lua lua, int32 index, ITypedAllocator allocator)
		{
			if (mDelegates.TryGetValue(type.TypeId, let registration))
				return registration.Factory(lua, index, allocator);
			SetLastError($"can't convert argument {index} to '{type}' (delegate signature not registered.)");
			return null;
		}

		public void RegisterAliveObject(Object obj)
		{
#if BF_ENABLE_REALTIME_LEAK_CHECK
			mAliveObjects.Add(obj);
#endif
		}

		public void RegisterAliveObject(ILuaOwnedObject obj)
		{
			obj.OnAddedToLua(this);
#if BF_ENABLE_REALTIME_LEAK_CHECK
			mAliveObjects.Add(obj);
#endif
		}

		public void DeregisterAliveObject(Object obj)
		{
#if BF_ENABLE_REALTIME_LEAK_CHECK
			mAliveObjects.Remove(obj);
#endif
		}

		public void DeregisterAliveObject(ILuaOwnedObject obj)
		{
			obj.OnRemovedFromLua(this);
#if BF_ENABLE_REALTIME_LEAK_CHECK
			mAliveObjects.Remove(obj);
#endif
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
			return mClasses.ContainsKey(typeof(T).TypeId);
		}

		public StringView GetClassName<T>()
		{
			if (mClasses.TryGetValue(typeof(T).TypeId, let registration))
				return .(registration.Name);
			Runtime.FatalError("GetClassName() failed");
		}

		internal bool TryRegisterClass<T>(StringView name)
		{
			for (let registration in mClasses.Values)
			{
				if (registration.Name == name)
				{
					SetLastError($"can't register class '{name}' (name already registered.)");
					return false;
				}
			}
			if (IsClassRegistered<T>())
			{
				SetLastError($"can't register class '{name}' (type already registered.)");
				return false;
			}
			mClasses.Add(typeof(T).TypeId, new ClassRegistration(name));
			return true;
		}

		internal void StoreClassMetatable<T>(Lua lua)
		{
			let registration = mClasses[typeof(T).TypeId];
			lua.PushValue(-1);
			lua.RawSetByHashCode(LuaRegistry.Index, Internal.UnsafeCastToPtr(registration));
		}

		[Inline]
		internal LuaType PushClassMetatable<T>(Lua lua) => PushClassMetatable(lua, typeof(T));

		internal LuaType PushClassMetatable(Lua lua, Type type)
		{
			if (!mClasses.TryGetValue(type.TypeId, let registration))
			{
				lua.PushNil();
				return .Nil;
			}
			return lua.RawGetByHashCode(LuaRegistry.Index, Internal.UnsafeCastToPtr(registration));
		}

		[Inline]
		internal bool IsClassRegistered(Type type) => mClasses.ContainsKey(type.TypeId);
	}
}
