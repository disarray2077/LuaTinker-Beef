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
		public static void MakeBeefCtorCall<T>(MethodInfo ctorMethod, int codeDepth, String code)
		{
			let depthCode = scope String('\t', codeDepth);

			if (typeof(T).IsObject)
				code.AppendF($"{depthCode}let wrapper = new:alloc ClassInstanceWrapper<T>();\n");
			else
				code.AppendF($"{depthCode}let wrapper = new:alloc ValuePointerWrapper<T>();\n");

			let isAppendCtor = ctorMethod.ParamCount > 0 && ctorMethod.GetParamName(0) == "__appendIdx";
			let startParamIndex = isAppendCtor ? 1 : 0;

			var isParams = false;
			Type paramsElementType = null;
			if (ctorMethod.ParamCount > startParamIndex)
			{
				let lastParamIndex = ctorMethod.ParamCount - 1;
				isParams = ctorMethod.GetParamFlags(lastParamIndex).HasFlag(.Params);

				if (isParams)
				{
					let lastParameterType = ctorMethod.GetParamType(lastParamIndex);
					if (let specializedType = lastParameterType as SpecializedGenericType)
						paramsElementType = specializedType.GetGenericArg(0);
				}
			}

			if (isParams)
			{
				Debug.Assert(paramsElementType != null);
				let paramsTypeCode = scope $"comptype({paramsElementType.GetTypeId()})";

				let numRegularLuaArgs = (ctorMethod.ParamCount - 1) - startParamIndex;
				
				let paramsStartStackIndex = 2 + numRegularLuaArgs;

				code.AppendF(
					$"""
					{depthCode}let top = lua.GetTop();
					{depthCode}let extraArgsCount = top >= {paramsStartStackIndex} ? top - {paramsStartStackIndex} + 1 : 0;
					{depthCode}{paramsTypeCode}[] extraArgs = scope {paramsTypeCode}[extraArgsCount] (?);
					{depthCode}for (int32 i = 0; i < extraArgsCount; i++)
					{depthCode}\textraArgs[i] = StackHelper.Pop!<{paramsTypeCode}>(lua, i + {paramsStartStackIndex});\n
					""");
			}

			if (isParams)
				code.AppendF($"{depthCode}wrapper.CreateParams<comptype({paramsElementType.GetTypeId()})>(");
			else
				code.AppendF($"{depthCode}wrapper.Create(");

			let nonParamsCount = isParams ? ctorMethod.ParamCount - 1 : ctorMethod.ParamCount;
			for (int i = startParamIndex; i < nonParamsCount; i++)
			{
				let paramType = ctorMethod.GetParamType(i);
				
				// Lua arguments start at index 2. We adjust for the skipped __appendIdx.
				let luaStackIndex = 2 + (i - startParamIndex);

				code.AppendF($"StackHelper.Pop!<comptype({paramType.GetTypeId()})>(lua, {luaStackIndex})");

				if (i < ctorMethod.ParamCount - 1)
					code.Append(", ");
			}

			if (isParams)
				code.Append("params extraArgs");

			code.Append(");\n");
			
			code.AppendF($"{depthCode}lua.TinkerState.RegisterAliveObject(wrapper);\n");
			code.AppendF($"{depthCode}lua.GetGlobal(lua.TinkerState.GetClassName<T>());\n");
			code.AppendF($"{depthCode}lua.SetMetaTable(-2);\n");

			code.AppendF($"{depthCode}return 1;\n");
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

			Trie<MethodParam> paramsTrie = scope .();
			for (var ctor in ref ctors)
			{
				Trie<MethodParam> node = paramsTrie;

				let isAppendCtor = ctor.ParamCount > 0 && ctor.GetParamName(0) == "__appendIdx";
				let startParamIndex = isAppendCtor ? 1 : 0;
				let effectiveParamCount = ctor.ParamCount - startParamIndex;

				if (effectiveParamCount == 0)
				{
					node.[Friend]Tag = &ctor;
					node.[Friend]IsEnd = true;
					continue;
				}

				for (int i = startParamIndex; i < ctor.ParamCount; i++)
				{
					let paramType = ctor.GetParamType(i);
					let paramFlags = ctor.GetParamFlags(i).HasFlag(.Params) ? ParamFlags.Params : ParamFlags.None;
					node = node.Insert(.(paramType, paramFlags));

					if (i == ctor.ParamCount - 1)
					{
						node.[Friend]Tag = &ctor;
						node.[Friend]IsEnd = true;
					}
				}
			}


			code.AppendF($"if (lua.GetTop() >= 2)\n");
			code.Append("{\n");
			// We pass 'IsStatic = true' to IterateTrie to prevent it from generating
			// the "forgot ':' expression?" error message.
			IterateTrie<T, const true>(2, 1, paramsTrie, code, scope => MakeBeefCtorCall<T>);
			code.Append("}\n");

			// Handle the case for a constructor with no arguments (e.g., MyClass())
			if (paramsTrie.IsEnd)
			{
				code.Append("else if (lua.GetTop() == 1)\n");
				code.Append("{\n");

				ref MethodInfo ctorMethod = ref *(MethodInfo*)paramsTrie.Tag;

				code.AppendF($"\t// Default constructor for: {ctorMethod}\n");
				MakeBeefCtorCall<T>(ctorMethod, 1, code);

				code.Append("}\n");
			}

			code.Append(
				scope $"""
				lua.TinkerState.SetLastError($"invalid arguments for constructor '{typeof(T)}'");
				StackHelper.ThrowError(lua, lua.TinkerState);
				""");

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
