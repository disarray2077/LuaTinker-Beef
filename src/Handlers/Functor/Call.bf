using System;
using System.Diagnostics;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Handlers
{
	static
	{
		[Comptime]
		private static void EmitCallHandler<F>()
			where F : var
		{
			let code = scope String();

			let invokeMethodResult = typeof(F).GetMethod("Invoke");
			if (invokeMethodResult case .Err)
				Runtime.FatalError(scope $"Type \"{typeof(F)}\" isn't invokable");

			let invokeMethod = invokeMethodResult.Get();
			let writer = scope CodeWriter(code);
			EmitBoundCall(invokeMethod, writer, false);
			writer.Finish();

			Compiler.MixinRoot(code);
		}

		public static int32 CallHandler<F>(lua_State L)
			where F : var, struct
		{
			let lua = Lua.FromIntPtr(L);
#unwarn
			let func = User2Type.GetLightUserDataValue<F>(lua, Lua.UpValueIndex(1));

			EmitCallHandler<F>();

			// This is necessary to avoid the "Method must return" error
			Runtime.FatalError("Not reached");
		}

		public static int32 FunctionPointerCallHandler<F>(lua_State L) where F : var, struct
		{
			let lua = Lua.FromIntPtr(L);
			let wrapper = User2Type.TryGetTypePtr<ValueTypeWrapper<F>>(lua, 1);
			if (wrapper == null)
			{
				lua.TinkerState.SetLastError("can't call function. (not a LuaTinker object.)");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}
#unwarn
			let func = *wrapper.ValuePointer;
			if (func == null)
			{
				lua.TinkerState.SetLastError("can't call null function pointer");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}
			lua.Remove(1);

			EmitCallHandler<F>();
			
			// This is necessary to avoid the "Method must return" error
			Runtime.FatalError("Not reached");
		}
	}
}
