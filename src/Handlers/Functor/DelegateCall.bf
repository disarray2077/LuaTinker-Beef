using System;
using System.Diagnostics;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.Handlers
{
	static
	{
		[Comptime]
		private static void EmitDelegateCallHandler<F>()
			where F : var
		{
			let code = scope String();

			let invokeMethodResult = typeof(F).GetMethod("Invoke");
			if (invokeMethodResult case .Err)
				Runtime.FatalError(scope $"Type \"{typeof(F)}\" isn't invokable");

			let invokeMethod = invokeMethodResult.Get();
			let writer = scope CodeWriter(code);
			EmitBoundCall(invokeMethod, writer, true);
			writer.Finish();

			Compiler.MixinRoot(code);
		}

		public static int32 DelegateCallHandler<F>(lua_State L)
			where F : var
		{
			let lua = Lua.FromIntPtr(L);
			// AddMethod/AddNamespaceMethod allocate ClassInstanceWrapper<F> for this closure upvalue.
			let wrapper = User2Type.TryGetTrustedTypePtr<ClassInstanceWrapper<F>>(lua, Lua.UpValueIndex(1));
			if (wrapper == null)
			{
				lua.TinkerState.SetLastError("can't call function. (not a LuaTinker object.)");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}
#unwarn
			let func = wrapper.ClassInstance;

			EmitDelegateCallHandler<F>();

			// This is necessary to avoid the "Method must return" error
			Runtime.FatalError("Not reached");
		}
	}
}
