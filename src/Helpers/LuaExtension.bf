using System;
using LuaTinker;
using System.Collections;

namespace KeraLua
{
	extension Lua
	{
		internal readonly LuaTinkerState TinkerState = new .() ~ delete _;

        public new LuaStatus PCall(int32 arguments, int32 results, int32 errorFunctionIndex)
        {
			TinkerState.ClearError();
			TinkerState.[Friend]IsPCall = true;
			defer { TinkerState.[Friend]IsPCall = false; }

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