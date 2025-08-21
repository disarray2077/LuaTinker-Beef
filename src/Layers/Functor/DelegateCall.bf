using System;
using System.Diagnostics;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

namespace LuaTinker.Layers
{
	static
	{
		[Comptime]
		private static void EmitDelegateCallLayer<F>()
			where F : var
		{
			let code = scope String();

			//Debug.Break();

			let invokeMethodResult = typeof(F).GetMethod("Invoke");
			if (invokeMethodResult case .Err)
				Runtime.FatalError(scope $"Type \"{typeof(F)}\" isn't invokable");

			let invokeMethod = invokeMethodResult.Get();
			var retType = invokeMethod.ReturnType;

			var isParams = false;
			Type paramsType = null;
			if (invokeMethod.ParamCount == 0)
				code.Append("Debug.Assert(lua.GetTop() == 0);\n");
			else
			{
				bool isInstanceCall = invokeMethod.GetParamName(0) == "this";
				if (isInstanceCall)
				{
					// TODO: When error deferring is done, we will not need this here.
					code.Append(
						"""
						if (!lua.IsUserData(1))
						{
							lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
							StackHelper.ThrowError(lua, lua.TinkerState);
						}\n
						""");
				}

				isParams = invokeMethod.GetParamFlags(invokeMethod.ParamCount - 1).HasFlag(.Params);

				let lastParameter = invokeMethod.GetParamType(invokeMethod.ParamCount - 1);
				if (isParams && (let specializedType = lastParameter as SpecializedGenericType))
					paramsType = specializedType.GetGenericArg(0);

				code.AppendF(
					$"""
					if (lua.GetTop() {isParams ? "<" : "!="} {invokeMethod.ParamCount})
					{{
						lua.TinkerState.SetLastError($"expected '{invokeMethod.ParamCount - (isInstanceCall ? 1 : 0)}' arguments but got '{{lua.GetTop() - {isInstanceCall ? 1 : 0}}}'");
						StackHelper.ThrowError(lua, lua.TinkerState);
					}}\n
					""");
			}

			if (isParams)
			{
				Debug.Assert(paramsType != null);

				let paramsTypeCode = scope String();
				paramsTypeCode.AppendF($"comptype({paramsType.GetTypeId()})");

				code.AppendF(
					$"""
					int extraArgsCount = lua.GetTop() - {invokeMethod.ParamCount - 1};
					{paramsTypeCode}[] extraArgs = scope {paramsTypeCode}[extraArgsCount] (?);
					for (int32 i = 0; i < extraArgsCount; i++)
						extraArgs[i] = StackHelper.Pop!::<{paramsTypeCode}>(lua, i + {invokeMethod.ParamCount});\n
					""");
			}
			
			if (retType != typeof(void))
				code.Append("var ret = ");
			
			var returnsRef = false;
			if (var retRefType = retType as RefType)
			{
				switch (retRefType.RefKind)
				{
				case .Ref:
					code.Append("ref ");
					returnsRef = true;
				default:
					Runtime.FatalError("Not implemented!");
				}
			}

			code.Append("func(");
			for (int i < invokeMethod.ParamCount)
			{
				if (isParams && i == invokeMethod.ParamCount - 1)
				{
					code.Append("params extraArgs");
					break;
				}

				let paramType = invokeMethod.GetParamType(i);
				var paramIsRef = false;
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

				code.Append("StackHelper.Pop");
				code.Append(paramIsRef ? "Ref" : "!");
				code.AppendF($"<comptype({GetInvokeArgType<F>(i).GetTypeId()})>(lua, {i + 1})");

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
						code.AppendF($"StackHelper.Push(lua, {(returnsRef ? "ref " : "")}ret.{fieldInfo.Name});\n");
					}
					// TODO: Remove the #unwarn when the compiler bug is solved.
					// TODO: Report this bug when the code is released in github.
#unwarn // COMPILER-BUG: Incorrect "params" warning
					code.AppendF($"return {fieldCount};");
				}
				else
				{
					code.AppendF(
						$"""
						StackHelper.Push(lua, {(returnsRef ? "ref " : "")}ret);
						return 1;
						""");
				}
			}
			else
			{
				code.Append("return 0;");
			}

			Compiler.MixinRoot(code);
		}

		public static int32 DelegateCallLayer<F>(lua_State L)
			where F : var
		{
			let lua = Lua.FromIntPtr(L);
#unwarn
			let func = User2Type.GetTypePtr<ClassInstanceWrapper<F>>(lua, Lua.UpValueIndex(1)).ClassInstance;

			EmitDelegateCallLayer<F>();

			// This is necessary to avoid the "Method must return" error
			Runtime.FatalError("Not reached");
		}
	}
}
