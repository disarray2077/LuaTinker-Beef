using System;
using LuaTinker;
using System.Collections;

namespace KeraLua
{
	extension Lua
	{
		internal LuaTinkerState TinkerState = new .() ~ DeleteAndNullify!(_);
		private static int __counter = 0;

        public new LuaStatus PCall(int32 arguments, int32 results, int32 errorFunctionIndex)
        {
			TinkerState.ClearError();
			TinkerState.[Friend]IsPCall = true;
			defer { TinkerState.[Friend]IsPCall = false; }

			// TODO: HACK?
			// Without this Lua's memory usage seems to grow quite a bit.
			// I suspect this happens because Lua isn't aware of how much memory is held by PointerWrappers.
			if (__counter++ % 100 == 0)
				defer:: { GarbageCollector(.Step, 0); }

            return [NoExtension]PCall(arguments, results, errorFunctionIndex);
        }

        public new LuaStatus PCallK(int32 arguments,
            int32 results,
            int32 errorFunctionIndex,
            int32 context,
            LuaKFunction k)
        {
			TinkerState.ClearError();
			TinkerState.[Friend]IsPCall = true;
			defer { TinkerState.[Friend]IsPCall = false; }

			// TODO: HACK?
			// Without this Lua's memory usage seems to grow quite a bit.
			// I suspect this happens because Lua isn't aware of how much memory is held by PointerWrappers.
			if (__counter++ % 100 == 0)
				defer:: { GarbageCollector(.Step, 0); }

            return [NoExtension]PCallK(arguments, results, errorFunctionIndex, context, k);
        }

		public new bool DoFile(StringView file)
		{
		    bool hasError = LoadFile(file) != LuaStatus.OK || PCall(0, -1, 0) != LuaStatus.OK;
		    return hasError;
		}

		public new bool DoString(StringView file)
		{
		    bool hasError = LoadString(file) != LuaStatus.OK || PCall(0, -1, 0) != LuaStatus.OK;
		    return hasError;
		}

		public bool DoString(StringView file, StringView name)
		{
		    bool hasError = LoadString(file, name) != LuaStatus.OK || PCall(0, -1, 0) != LuaStatus.OK;
		    return hasError;
		}

	}
}