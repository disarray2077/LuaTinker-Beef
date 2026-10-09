using System;
using LuaTinker;
using System.Collections;

using internal LuaTinker;

namespace KeraLua
{
	extension Lua
	{
		// Close Lua while its shared state is still alive for userdata finalizers.
		private LuaTinkerState mTinkerState ~ { Close(); DeleteAndNullify!(_); }
		public LuaTinkerState TinkerState
		{
			get
			{
				// NewThread can be called on a coroutine; follow its creator chain to the owning main state.
				let main = MainThread;
				if (main != this)
					return main.TinkerState;
				if (mTinkerState == null)
					mTinkerState = new .();
				return mTinkerState;
			}
		}

		private static int __counter = 0;

        /// Calls a function in protected mode.
        public new LuaStatus PCall(int32 arguments, int32 results, int32 errorFunctionIndex)
        {
			let tinkerState = TinkerState;
			let wasProtected = tinkerState.IsPCall;
			tinkerState.ClearError();
			tinkerState.IsPCall = true;
			defer { tinkerState.IsPCall = wasProtected; }

			// TODO: Periodic GC steps work around observed memory growth; the cause is unresolved.
			// Investigate Lua's accounting of Beef-owned wrapper memory before removing this workaround.
			if (__counter++ % 100 == 0)
				defer:: { GarbageCollector(.Step, 0); }

            return [NoExtension]PCall(arguments, results, errorFunctionIndex);
        }

		/// This function behaves exactly like lua_pcall, but allows the called function to yield.
        public new LuaStatus PCallK(int32 arguments,
            int32 results,
            int32 errorFunctionIndex,
            int32 context,
            LuaKFunction k)
        {
			let tinkerState = TinkerState;
			let wasProtected = tinkerState.IsPCall;
			tinkerState.ClearError();
			tinkerState.IsPCall = true;
			defer { tinkerState.IsPCall = wasProtected; }

			// TODO: Periodic GC steps work around observed memory growth; the cause is unresolved.
			// Investigate Lua's accounting of Beef-owned wrapper memory before removing this workaround.
			if (__counter++ % 100 == 0)
				defer:: { GarbageCollector(.Step, 0); }

            return [NoExtension]PCallK(arguments, results, errorFunctionIndex, context, k);
        }

        /// Starts and resumes a coroutine in the given thread L. To start a coroutine, you push onto the thread stack the main function plus any arguments; then you call lua_resume, with nargs being the number of arguments.This call returns when the coroutine suspends or finishes its execution. When it returns, * nresults is updated and the top of the stack contains the* nresults values passed to lua_yield or returned by the body function. lua_resume returns LUA_YIELD if the coroutine yields, LUA_OK if the coroutine finishes its execution without errors, or an error code in case of errors (see lua_pcall). In case of errors, the error object is on the top of the stack. To resume a coroutine, you clear its stack, push only the values to be passed as results from yield, and then call lua_resume. The parameter from represents the coroutine that is resuming L. If there is no such coroutine, this parameter can be NULL.
		public new LuaStatus Resume(Lua from, int32 arguments, out int32 results)
		{
			let tinkerState = TinkerState;
			let wasProtected = tinkerState.IsPCall;
			tinkerState.ClearError();
			tinkerState.IsPCall = true;
			defer { tinkerState.IsPCall = wasProtected; }

			// TODO: Periodic GC steps work around observed memory growth; the cause is unresolved.
			// Investigate Lua's accounting of Beef-owned wrapper memory before removing this workaround.
			if (__counter++ % 100 == 0)
				defer:: { GarbageCollector(.Step, 0); }

			return [NoExtension]Resume(from, arguments, out results);
		}

		/// Starts and resumes a coroutine in the given thread L. To start a coroutine, you push onto the thread stack the main function plus any arguments; then you call lua_resume, with nargs being the number of arguments.This call returns when the coroutine suspends or finishes its execution. When it returns, * nresults is updated and the top of the stack contains the* nresults values passed to lua_yield or returned by the body function. lua_resume returns LUA_YIELD if the coroutine yields, LUA_OK if the coroutine finishes its execution without errors, or an error code in case of errors (see lua_pcall). In case of errors, the error object is on the top of the stack. To resume a coroutine, you clear its stack, push only the values to be passed as results from yield, and then call lua_resume. The parameter from represents the coroutine that is resuming L. If there is no such coroutine, this parameter can be NULL.
		public new LuaStatus Resume(Lua from, int32 arguments)
		{
			int32 results;
			return Resume(from, arguments, out results);
		}

		/// Loads and runs the given file.
		public new bool DoFile(StringView file)
		{
		    bool hasError = LoadFile(file) != LuaStatus.OK || PCall(0, -1, 0) != LuaStatus.OK;
		    return hasError;
		}

		/// Loads and runs the given string.
		public new bool DoString(StringView chunk)
		{
		    bool hasError = LoadString(chunk) != LuaStatus.OK || PCall(0, -1, 0) != LuaStatus.OK;
		    return hasError;
		}

		/// Loads and runs the given string.
		/// @param name The chunk name used in error messages. 
		public bool DoString(StringView chunk, StringView name)
		{
		    bool hasError = LoadString(chunk, name) != LuaStatus.OK || PCall(0, -1, 0) != LuaStatus.OK;
		    return hasError;
		}

	}
}
