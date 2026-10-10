using System;
using System.Diagnostics;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;

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
	}
}
