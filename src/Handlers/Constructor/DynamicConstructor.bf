using System;
using KeraLua;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;
using System.Collections;
using System.Reflection;
using System.Diagnostics;

using internal KeraLua;
using internal LuaTinker.Handlers;

namespace LuaTinker.Handlers
{
	static
	{
		[Comptime]
		private static void GetConstructors<T>(List<MethodInfo> ctors)
		{
			let type = typeof(T);

			for (let ctor in type.GetMethods())
			{
				if (!ctor.IsConstructor || ctor.IsMixin || ctor.IsStatic || !ctor.IsPublic)
					continue;

				// Ignore generics
				if (ctor.GenericArgCount > 0)
					continue;

				// Ignore comptime/intrinsics.
				if (ctor.HasCustomAttribute<ComptimeAttribute>() || ctor.HasCustomAttribute<IntrinsicAttribute>())
					continue;

				// Ignore unchecked methods.
				if (ctor.HasCustomAttribute<UncheckedAttribute>())
					continue;

				// Ignore methods from base classes.
				if (ctor.DeclaringType != type)
					continue;
				
				// Ignore zero-gap append constructors
				if (ctor.AllowAppendKind == .ZeroGap)
					continue;

				ctors.Add(ctor);
			}
		}


		[Comptime]
		private static void EmitDynamicCreatorHandler<T>()
		{
			if (typeof(T).IsGenericParam)
			{
				Compiler.MixinRoot("return 1;");
				return;
			}

			let code = scope String();

			List<MethodInfo> ctors = scope .();
			GetConstructors<T>(ctors);

			if (ctors.IsEmpty)
			{
				Runtime.FatalError(scope $"No public constructors found for type \"{typeof(T)}\"");
			}

			let writer = scope CodeWriter(code);
			EmitOverloads<T>(ctors, writer, .Constructor);
			writer.Finish();

			Compiler.MixinRoot(code);
		}

		public static int32 DynamicCreatorHandler<T>(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
#unwarn
			let alloc = LuaUserdataAllocator(lua);

			EmitDynamicCreatorHandler<T>();
		}
	}
}
