using System;
using System.Diagnostics;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;
using System.Collections;

using internal LuaTinker.Layers;

namespace LuaTinker.Layers
{
	static
	{
		static this
		{
			Debug.Assert(Enum.GetMaxValue<TypeInstance.ParamFlags>() == .Params);
		}

		public enum ParamFlags : int16
		{
			None = 0,
			Splat = 1,
			Implicit = 2,
			AppendIdx = 4,
			Params = 8,
			This = 16
		}

		internal struct MethodParam : this(Type type, ParamFlags flags), IHashable
		{
			public int GetHashCode()
			{
				let value1 = (int)(void*)Internal.UnsafeCastToPtr(type);
				let value2 = (int)flags;
				return unchecked((int)(value1 ^ (value2 >> 32) ^ value2));//HashCode.Generate(this);
			}
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
		private static void MakeParamsTrie(Trie<MethodParam> trie, List<MethodInfo> methods)
		{
			for (var method in ref methods)
			{
				Trie<MethodParam> node = trie;

				int paramCount = method.ParamCount;
				if (!method.IsStatic)
					paramCount += 1;
				Debug.WriteLine(method.ToString(.. scope .()));
				if (paramCount == 0)
				{
					Runtime.Assert(!node.[Friend]IsEnd);
					node.[Friend]Tag = &method;
					node.[Friend]IsEnd = true;
					continue;
				}

				for (int i < paramCount)
				{
					var i;
					if (!method.IsStatic)
						i -= 1;

					Type paramType = null;
					ParamFlags paramFlags = .None;
					if (i == -1)
					{
						paramType = method.DeclaringType;
						paramFlags = .This;
					}
					else
					{
						paramType = method.GetParamType(i);
						if (method.GetParamFlags(i) == .Params)
							paramFlags = .Params;
					}

					node = node.Insert(.(paramType, paramFlags));

					if (i == method.ParamCount - 1)
					{
						Runtime.Assert(!node.[Friend]IsEnd);
						node.[Friend]Tag = &method;
						node.[Friend]IsEnd = true;
					}
				}
			}
		}

		[Comptime]
		private static LuaType BeefTypeToLuaType(Type type)
		{
			if (type.[Friend]mTypeCode == .Boolean)
				return .Boolean;
			if (type.IsInteger || type.IsFloatingPoint)
				return .Number;
			if (type == typeof(String) || type == typeof(StringView) || type == typeof(char8*))
				return .String;
			return .UserData;
		}
		
		[Comptime]
		private static void IterateTrie<T, IsStatic>(int depth, int codeDepth, Trie<MethodParam> root, String code)
			where IsStatic : const bool
		{
			let depthCode = scope String('\t', codeDepth);

			for (let (param, node) in root.Children)
			{
				var type = param.type;
				let flags = param.flags;

				if (flags.HasFlag(.Params))
				{
					// Params should be always the last parameter.
					Runtime.Assert(node.IsEnd);

					if (let specializedType = type as SpecializedGenericType)
						type = specializedType.GetGenericArg(0);
					else
						Runtime.NotImplemented();
				}

				LuaType luaType = BeefTypeToLuaType(type);

				if (luaType == .UserData)
				{
					code.AppendF($"{depthCode}if (lua.IsUserData({depth}) && User2Type.GetObjectType(lua, {depth}).IsSubtypeOf(typeof(comptype({type.GetTypeId()})))) // {type.GetFullName(.. scope .())} (Flags: {flags})\n");
				}
				else if (luaType == .String)
				{
					if (flags.HasFlag(.This))
					{
						code.AppendF($"{depthCode}if (lua.IsUserData({depth}) && User2Type.GetObjectType(lua, {depth}).IsSubtypeOf(typeof(comptype({type.GetTypeId()})))) // {type.GetFullName(.. scope .())} (Flags: {flags})\n");
					}
					else
					{
						code.AppendF($"{depthCode}if (lua.IsString({depth}) || (lua.IsUserData({depth}) && User2Type.GetObjectType(lua, {depth}).IsSubtypeOf(typeof(comptype({type.GetTypeId()}))))) // {type.GetFullName(.. scope .())} (Flags: {flags})\n");
					}
				}
				else if (luaType == .Number)
				{
					code.AppendF($"{depthCode}if (lua.IsNumber({depth}) && !lua.IsString({depth})) // {type.GetFullName(.. scope .())} (Flags: {flags})\n");
				}
				else
				{
					code.AppendF($"{depthCode}if (lua.Is{luaType}({depth})) // {type.GetFullName(.. scope .())} (Flags: {flags})\n");
				}
				code.AppendF($"{depthCode}{{\n");

				if (!flags.HasFlag(.Params))
				{
					if (!node.Children.IsEmpty)
					{
						code.AppendF($"{depthCode}\tif (lua.GetTop() >= {depth + 1})\n");
						code.AppendF($"{depthCode}\t{{\n");
						IterateTrie<T, const IsStatic>(depth + 1, codeDepth + 2, node, code);
						code.AppendF($"{depthCode}\t}}\n");
					}
					else
					{
						code.AppendF($"{depthCode}\tif (lua.GetTop() < {depth + 1})\n");
					}
				}

				if (node.IsEnd)
				{
					if (!flags.HasFlag(.Params))
					{
						if (!node.Children.IsEmpty)
							code.AppendF($"{depthCode}\telse\n");
						code.AppendF($"{depthCode}\t{{\n");
					}

					ref MethodInfo invokeMethod = ref *(MethodInfo*)node.Tag;

					code.AppendF($"{depthCode}\t\t// {invokeMethod.ToString(.. scope .())}\n");
					MakeBeefCall<T>(invokeMethod, codeDepth + 2, code);

					if (!flags.HasFlag(.Params))
						code.AppendF($"{depthCode}\t}}\n");
				}

				code.AppendF($"{depthCode}}}\n");
			}

			if (!root.Children.IsEmpty)
			{
				if (!IsStatic && depth == 1)
				{
					code.AppendF(
						$"""
						{depthCode}else
						{depthCode}{{
						{depthCode}\tlua.PushString("no class at first argument. (forgot ':' expression ?)");
						{depthCode}\tlua.Error();
						{depthCode}}}\n
						""");
				}
			}
		}

		[Comptime]
		private static void EmitCallLayer<T, Name, IsStatic>()
			where Name : const String
			where IsStatic : const bool
		{
			if (typeof(T).IsGenericParam)
				return;

			let code = scope String();

			List<MethodInfo> methods = scope .();
			GetMethods<T, const Name, const IsStatic>(methods);

			Trie<MethodParam> paramsTrie = scope .();
			MakeParamsTrie(paramsTrie, methods);

			code.AppendF($"if (lua.GetTop() >= 1)\n");
			code.Append("{\n");
			IterateTrie<T, const IsStatic>(1, 1, paramsTrie, code);
			code.Append("}\n");

			if (paramsTrie.IsEnd)
			{
				code.Append("else\n");
				code.Append("{\n");

				ref MethodInfo invokeMethod = ref *(MethodInfo*)paramsTrie.Tag;

				code.AppendF($"\t// {invokeMethod.ToString(.. scope .())}\n");
				MakeBeefCall<T>(invokeMethod, 1, code);

				code.Append("}\n");
			}


			if (!IsStatic)
			{
				code.Append(
					"""
					else
					{
					\tlua.PushString("no class at first argument. (forgot ':' expression ?)");
					\tlua.Error();
					}\n
					""");
			}

			int nextEndDepth = 0;
			Trie<MethodParam> nextEnd = paramsTrie;
			while (!nextEnd.IsEnd)
			{
				nextEndDepth += 1;
				nextEnd = nextEnd.Children.Values.GetNext().Get();
			}

			code.AppendF(
				$"""
				lua.PushString($"expected '{nextEndDepth}' arguments but got '{{lua.GetTop()}}'");
				lua.Error();\n
				""");
			

			Compiler.MixinRoot(code);
		}

		[Comptime]
		public static void MakeBeefCall<T>(MethodInfo invokeMethod, int codeDepth, String code)
		{
			let depthCode = scope String('\t', codeDepth);

			var retType = invokeMethod.ReturnType;

			String methodParams = scope .();

			if (!invokeMethod.IsStatic)
				methodParams.AppendF($"T this");

			for (int i < invokeMethod.ParamCount)
			{
				if (!methodParams.IsEmpty)
					methodParams.Append(", ");

				if (invokeMethod.GetParamFlags(i).HasFlag(.Params))
					methodParams.AppendF("params ");

				let paramType = invokeMethod.GetParamType(i);

				if (var retParamType = paramType as RefType)
				{
					switch (retParamType.RefKind)
					{
					case .Ref:
						methodParams.Append("ref ");
					default:
						Runtime.FatalError(scope $"Not implemented {retParamType.RefKind}!");
					}
				}

				methodParams.AppendF($"comptype({paramType.GetTypeId()})");
			}

			code.AppendF($"{depthCode}function comptype({retType.GetTypeId()})({methodParams}) func = => T.{invokeMethod.Name};\n");

			var isParams = false;
			Type paramsType = null;
			if (invokeMethod.ParamCount != 0)
			{
				isParams = invokeMethod.GetParamFlags(invokeMethod.ParamCount - 1).HasFlag(.Params);

				let lastParameter = invokeMethod.GetParamType(invokeMethod.ParamCount - 1);
				if (isParams && (let specializedType = lastParameter as SpecializedGenericType))
					paramsType = specializedType.GetGenericArg(0);
			}

			if (isParams)
			{
				Debug.Assert(paramsType != null);

				let paramsTypeCode = scope String();
				paramsTypeCode.AppendF($"comptype({paramsType.GetTypeId()})");

				int paramOffset = 0;
				if (!invokeMethod.IsStatic)
					paramOffset = 1;

				code.AppendF(
					$"""
					{depthCode}int extraArgsCount = lua.GetTop() - {invokeMethod.ParamCount + paramOffset - 1};
					{depthCode}{paramsTypeCode}[] extraArgs = scope {paramsTypeCode}[extraArgsCount] (?);
					{depthCode}for (int32 i = 0; i < extraArgsCount; i++)
					{depthCode}\textraArgs[i] = StackHelper.Pop!::<{paramsTypeCode}>(lua, i + {invokeMethod.ParamCount + paramOffset});\n
					""");
			}
			
			if (retType != typeof(void))
				code.AppendF($"{depthCode}var ret = ");
			else
				code.Append(depthCode);
			
			var returnsRef = false;
			if (var retRefType = retType as RefType)
			{
				switch (retRefType.RefKind)
				{
				case .Ref:
					code.Append("ref ");
					returnsRef = true;
				default:
					Runtime.FatalError(scope $"Not implemented {retRefType.RefKind}!");
				}
			}

			int paramCount = invokeMethod.ParamCount;
			if (!invokeMethod.IsStatic)
				paramCount += 1;

			code.Append("func(");
			for (int i < paramCount)
			{
				var i;
				if (!invokeMethod.IsStatic)
					i -= 1;

				if (isParams && i == invokeMethod.ParamCount - 1)
				{
					code.Append("params extraArgs");
					break;
				}
				
				Type paramType = null;
				bool paramIsRef = false;
				if (i == -1)
				{
					paramType = invokeMethod.DeclaringType;
				}
				else
				{
					paramType = invokeMethod.GetParamType(i);
					if (var retParamType = paramType as RefType)
					{
						switch (retParamType.RefKind)
						{
						case .Ref:
							code.Append("ref ");
							paramIsRef = true;
						default:
							Runtime.FatalError(scope $"Not implemented {retParamType.RefKind}!");
						}
					}
				}

				code.Append("StackHelper.Pop");
				code.Append(paramIsRef ? "Ref" : "!");

				code.AppendF($"<comptype({paramType.GetTypeId()})>(lua, {i + (!invokeMethod.IsStatic ? 2 : 1)})");

				if (i != invokeMethod.ParamCount - 1)
					code.Append(", ");
			}
			code.Append(");\n");

			if (retType != typeof(void))
			{
				if (retType.IsTuple)
				{
					var fieldCount = retType.FieldCount;
					for (int i = 0; i < fieldCount; i++)
					{
						let fieldInfo = retType.GetField(i).Get();
						code.AppendF($"{depthCode}StackHelper.Push(lua, {(returnsRef ? "ref " : "")}ret.{fieldInfo.Name});\n");
					}
					// TODO: Remove the #unwarn when the compiler bug is solved.
					// TODO: Report this bug when the code is released in github.
#unwarn // COMPILER-BUG: Incorrect "params" warning
					code.AppendF($"{depthCode}return {fieldCount};\n");
				}
				else
				{
					code.AppendF(
						$"""
						{depthCode}StackHelper.Push(lua, {(returnsRef ? "ref " : "")}ret);
						{depthCode}return 1;\n
						""");
				}
			}
			else
			{
				code.AppendF($"{depthCode}return 0;\n");
			}
		}

		public static int32 CallLayer<T, Name, IsStatic>(lua_State L)
			where Name : const String
			where IsStatic : const bool
		{
#unwarn
			let lua = Lua.FromIntPtr(L);

			// TODO: BEEF BUG
			if (false)
			{
				function StringSplitEnumerator(String this, char8[]) func2 = => String.Split;
				char8[] x = default;
				func2(default, x);
	
				function StringStringSplitEnumerator(String this, StringView[]) func = => String.Split;
				StringView[] x2 = default;
				func(default, x2);
			}
			// TODO: BEEF BUG

			EmitCallLayer<T, const Name, const IsStatic>();

			// This is necessary to avoid the "Method must return" error
			Runtime.FatalError("Not reached");
		}
	}
}
