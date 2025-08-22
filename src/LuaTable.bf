using System;
using System.Collections;
using KeraLua;
using LuaTinker.StackHelpers;
using System.Diagnostics;

using internal LuaTinker;
using internal KeraLua;

namespace LuaTinker
{
	/// Represents a reference to a Lua table, allowing interaction with it from Beef code.
	/// @remarks This structure must be disposed.
	public struct LuaTable : IDisposable, IEnumerable<(Object key, Object value)>
	{
		private Lua mLua;
		private int32 mTableRef;

		/// Internal constructor. Use LuaTinker.GetValue<LuaTable> to get an instance.
		internal this(Lua lua, int32 tableStackIndex)
		{
			mLua = lua;

			let absoluteIndex = lua.AbsIndex(tableStackIndex);
			lua.PushValue(absoluteIndex);
			mTableRef = lua.Ref(LuaRegistry.Index);
		}

		/// Releases the Lua reference to the table.
		public void Dispose() mut
		{
			if (mLua != null && mTableRef > 0)
			{
				mLua.Unref(LuaRegistry.Index, mTableRef);
				mTableRef = -1;
				mLua = null;
			}
		}

		/// Pushes the referenced table onto the Lua stack.
		internal void PushOntoStack()
		{
			Debug.Assert(mLua != null, "Attempted to use a disposed LuaTable.");
			mLua.RawGetInteger(LuaRegistry.Index, mTableRef);
		}

		/// Gets a value from the table by a string key.
		/// @return the value or an error.
		public Result<T, StringView> GetValue<T>(StringView key) where T : var
		{
			if (mLua == null) return .Err("LuaTable is disposed.");

			PushOntoStack();
			mLua.PushString(key);
			mLua.GetTable(-2);
			defer mLua.Pop(2);

			if (mLua.IsNil(-1))
				return .Err(scope $"Key '{key}' not found or value is nil.");

			let val = StackHelper.Pop<T>(mLua, -1);
			
			if (mLua.TinkerState.HasError)
				return .Err(mLua.TinkerState.GetLastError());

			return .Ok(val);
		}

		[Error("Use the \"GetString\" mixin instead, or get a StringView if you don't need a String instance")]
		public Result<T, StringView> GetValue<T>(StringView name) where T : String where String : T
		{
			Runtime.NotImplemented();
		}

		/// Gets a disposable `LuaTable` from the table by a string key.
		/// This mixin will automatically dispose the LuaTable.
		/// @return the value or an error.
		public mixin GetTable(StringView name)
		{
			let res = GetValue<LuaTable>(name);
			if (res case .Ok(var ref val))
			{
				defer:mixin val.Dispose();
			}
			res
		}

		/// Gets a value from the table by an integer key.
		/// @return the value or an error.
		public Result<T, StringView> GetValue<T>(int64 key) where T : var
		{
			if (mLua == null) return .Err("LuaTable is disposed.");
			
			PushOntoStack();
			mLua.PushInteger(key);
			mLua.GetTable(-2);
			defer mLua.Pop(2);
			
			let tinkerState = mLua.TinkerState;
			if (mLua.IsNil(-1))
			{
				tinkerState.SetLastError($"Key '{key}' not found or value is nil.");
				return .Err(tinkerState.GetLastError());
			}
			
			let val = StackHelper.Pop<T>(mLua, -1);

			if (tinkerState.HasError)
				return .Err(tinkerState.GetLastError());

			return .Ok(val);
		}

		[Error("Use the \"GetString\" mixin instead, or get a StringView if you don't need a String instance")]
		public Result<T, StringView> GetValue<T>(int64 key) where T : String where String : T
		{
			Runtime.NotImplemented();
		}

		/// Gets a disposable `LuaTable` from the table by an integer key.
		/// This mixin will automatically dispose the LuaTable.
		/// @return the value or an error.
		public mixin GetTable(int64 key)
		{
			let res = GetValue<LuaTable>(key);
			if (res case .Ok(var ref val))
			{
				defer:mixin val.Dispose();
			}
			res
		}

		/// Gets a value from the table as a `String`, allocating it on the caller's stack if necessary.
		/// @param key The string key of the value to retrieve.
		/// @return A `Result<String, StringView>` containing the `String` instance or an error.
		public mixin GetString(StringView key)
		{
			Result<String, StringView> result;
			if (mLua == null)
			{
				result = .Err("LuaTable is disposed.");
			}
			else
			{
				PushOntoStack();
				mLua.PushString(key);
				mLua.GetTable(-2);
				defer mLua.Pop(2);
				
				let tinkerState = mLua.[Friend]TinkerState;
				if (mLua.IsNil(-1))
				{
					tinkerState.SetLastError($"Key '{key}' not found or value is nil.");
					result = .Err(tinkerState.GetLastError());
				}
				else
				{
					result = .Ok(StackHelper.Pop!:mixin<String>(mLua, -1));

					if (tinkerState.HasError)
						result = .Err(tinkerState.GetLastError());
				}
			}
			result
		}

		/// Gets a value from the table as a `String`, allocating it on the caller's stack.
		/// This is a mixin and must be called with `let myString = table.GetString(123).Get();`.
		/// @param key The integer key of the value to retrieve.
		/// @return A `Result<String, StringView>` containing the new `String` instance or an error.
		public mixin GetString(int64 key)
		{
			Result<String, StringView> result;
			if (mLua == null)
			{
				result = .Err("LuaTable is disposed.");
			}
			else
			{
				PushOntoStack();
				mLua.PushInteger(key);
				mLua.GetTable(-2);
				defer mLua.Pop(2);
				
				let tinkerState = mLua.[Friend]TinkerState;
				if (mLua.IsNil(-1))
				{
					tinkerState.SetLastError($"Key '{key}' not found or value is nil.");
					result = .Err(tinkerState.GetLastError());
				}
				else
				{
					result = .Ok(StackHelper.Pop!:mixin<String>(mLua, -1));

					if (tinkerState.HasError)
						result = .Err(tinkerState.GetLastError());
				}
			}
			result
		}

		/// Sets a value in the table with a string key.
		public void SetValue<T>(StringView key, T value) where T : var
		{
			if (mLua == null) return;

			PushOntoStack();
			mLua.PushString(key);
			StackHelper.Push(mLua, value);
			mLua.SetTable(-3);
			mLua.Pop(1);
		}

		/// Sets a value in the table with an integer key.
		public void SetValue<T>(int64 key, T value) where T : var
		{
			if (mLua == null) return;

			PushOntoStack();
			mLua.PushInteger(key);
			StackHelper.Push(mLua, value);
			mLua.SetTable(-3);
			mLua.Pop(1);
		}

		/// Returns an enumerator that iterates through the key-value pairs of the Lua table.
		/// @remarks This enumerator allocates resources and must be disposed. Any objects it returns will become invalid once it has been disposed.
		public Enumerator GetEnumerator()
		{
			return Enumerator(this);
		}

		/// An enumerator for iterating over the key-value pairs of a LuaTable.
		public struct Enumerator : IEnumerator<(Object key, Object value)>, IResettable
		{
			private Lua mLua;
			private int mTableRef;
			private bool mIsFirst;
			private BumpAllocator mAllocator;
			private (Object key, Object value) mCurrent;

			public this(LuaTable table)
			{
				mLua = table.mLua;
				mTableRef = table.mTableRef;
				mIsFirst = true;
				mAllocator = new .();
				mCurrent = (null, null);
			}

			public void Dispose() mut
			{
				Reset();
				delete mAllocator;
			}

			public bool MoveNext() mut
			{
				if (mLua == null || mTableRef <= 0)
				{
					return false;
				}

				mLua.RawGetInteger(LuaRegistry.Index, mTableRef); // stack: ..., table

				if (mIsFirst)
				{
					mLua.PushNil();
					mIsFirst = false;
				}
				else
				{
					if (var disposable = mCurrent.key as IDisposable)
						disposable.Dispose();
					if (var disposable = mCurrent.value as IDisposable)
						disposable.Dispose();

					// Pop the previous table, key and value to clean up the stack
					mLua.Pop(3);

					// Push the key from the previous iteration
					StackHelper.Push(mLua, mCurrent.key);
				}
				
				if (mLua.Next(-2))
				{
					// lua_next pops the key, pushes new key and value
					mCurrent.value = StackHelper.PopAlloc!<Object>(mLua, -1, mAllocator);
					mCurrent.key = StackHelper.PopAlloc!<Object>(mLua, -2, mAllocator);
					return true;
				}
				else
				{
					// No more items, lua_next returned 0
					// Pop the table to clean up the stack
					mLua.Pop(1);
					mCurrent = (null, null);
					return false;
				}
			}

			public (Object key, Object value) Current
			{
				get { return mCurrent; }
			}

			public void Reset() mut
			{
				if (!mIsFirst)
				{
					if (var disposable = mCurrent.key as IDisposable)
						disposable.Dispose();
					if (var disposable = mCurrent.value as IDisposable)
						disposable.Dispose();
					mLua.SetTop(0);
				}
				mIsFirst = true;
				mCurrent = (null, null);
			}

			public Result<(Object key, Object value)> GetNext() mut
			{
				if (!MoveNext())
					return .Err;
				return .Ok(Current);
			}
		}
	}
}