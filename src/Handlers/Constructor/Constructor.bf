using System;
using System.Collections;
using KeraLua;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;

using internal KeraLua;
using internal LuaTinker;
using internal LuaTinker.Handlers;

namespace LuaTinker.Handlers
{
	static
	{
		[Comptime]
		private static void EmitCreatorLayer<T, Args>()
			where T : var
		{
			if (typeof(T).IsGenericParam)
			{
				// Generic analysis still needs the original metatable-and-return tail.
				Compiler.MixinRoot("lua.TinkerState.PushClassMetatable<T>(lua);\nlua.SetMetaTable(-2);\nreturn 1;");
				return;
			}

			let code = scope String();
			let writer = scope CodeWriter(code);
			List<LuaParameter> parameters = scope .();
			NormalizeDirectConstructorParameters<Args>(parameters);
			EmitConstruction<T>(parameters, 0, parameters.Count, writer);
			writer.Finish();

			Compiler.MixinRoot(code);
		}

		public static int32 CreatorLayer<T, Args>(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
#unwarn
			let alloc = LuaUserdataAllocator(lua);

			EmitCreatorLayer<T, Args>();
		}
	}
}
