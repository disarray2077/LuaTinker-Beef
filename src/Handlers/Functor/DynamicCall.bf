using System;
using System.Diagnostics;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;
using System.Collections;

using internal LuaTinker.Handlers;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.Handlers
{
	static
	{
		static this
		{
			// TODO: Review code generation for TypeInstance.ParamFlags drift, then restore this assertion.
			//Debug.Assert(Enum.GetMaxValue<TypeInstance.ParamFlags>() == .Params);
		}


		[Comptime]
		private static void GetMethods<T, Name, IsStatic>(List<MethodInfo> methods)
			where Name : const String
			where IsStatic : const bool
		{
			let type = typeof(T);

			for (let method in type.GetMethods(.Public))
			{
				if (method.IsConstructor || method.IsDestructor || method.Name.Contains("$") || method.IsMixin || !method.IsPublic)
					continue;

				// Ignore generics
				if (method.GenericArgCount > 0)
					continue;

				// Ignore comptime/intrinsics.
				if (method.HasCustomAttribute<ComptimeAttribute>() || method.HasCustomAttribute<IntrinsicAttribute>())
					continue;

				// Ignore unchecked methods.
				if (method.HasCustomAttribute<UncheckedAttribute>())
					continue;

				// Ignore methods from base classes.
				if (method.DeclaringType != type)
					continue;

				// Ignore operators.
				if (method.Name.Length == 0)
					continue;

				// TODO: Support for properties...
				if (method.Name.StartsWith("get__") ||
					method.Name.StartsWith("set__"))
					continue;

				if (IsStatic != method.IsStatic)
					continue;

				if (method.Name == Name)
					methods.Add(method);
			}
		}
		

		[Comptime]
		private static void EmitDynamicCallHandler<T, Name, IsStatic>()
			where Name : const String
			where IsStatic : const bool
		{
			if (typeof(T).IsGenericParam)
			{
				Compiler.MixinRoot("return 1;");
				return;
			}

			let code = scope String();
			List<MethodInfo> methods = scope .();
			GetMethods<T, const Name, const IsStatic>(methods);
			if (methods.IsEmpty)
				Runtime.FatalError(scope $"No methods found matching \"{typeof(T)}.{Name}\"");

			let writer = scope CodeWriter(code);
			EmitOverloads<T>(methods, writer, IsStatic ? .StaticMethod : .InstanceMethod);
			writer.Finish();
			Compiler.MixinRoot(code);
		}


		public static int32 DynamicCallHandler<T, Name, IsStatic>(lua_State L)
			where Name : const String
			where IsStatic : const bool
		{
#unwarn
			let lua = Lua.FromIntPtr(L);

			EmitDynamicCallHandler<T, const Name, const IsStatic>();
		}
	}
}
