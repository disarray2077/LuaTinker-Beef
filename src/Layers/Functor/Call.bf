using System;
using System.Diagnostics;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;

namespace LuaTinker.Layers
{
	static
	{
		[Comptime]
		private static void EmitCallLayer<F>()
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
			if (invokeMethod.ParamCount == 0)
				code.Append("Debug.Assert(lua.GetTop() == 0);\n");
			else
			{
				if (invokeMethod.GetParamName(0) == "this")
				{
					// TODO: When error deferring is done, we will not need this here.
					code.Append(
						"""
						if (!lua.IsUserData(1))
						{
							lua.PushString("no class at first argument. (forgot ':' expression ?)");
							lua.Error();
						}\n
						""");
				}

				// TODO: Proper way to check if parameter is "params"
				let lastParameter = invokeMethod.GetParamType(invokeMethod.ParamCount - 1);
				isParams = lastParameter.IsArray && lastParameter.IsObject;
				if (let specializedType = lastParameter as SpecializedGenericType)
					isParams |= specializedType.UnspecializedType == typeof(Span<>) && specializedType.GetGenericArg(0).IsObject;

				code.AppendF(
					$"""
					if (lua.GetTop() < {invokeMethod.ParamCount})
					{{
						lua.PushString($"expected '{invokeMethod.ParamCount}' arguments but got '{{lua.GetTop()}}'");
						lua.Error();
					}}\n
					""");
			}

			if (isParams)
			{
				code.AppendF(
					$"""
					int extraArgsCount = lua.GetTop() - {invokeMethod.ParamCount - 1};
					Object[] extraArgs = scope Object[extraArgsCount] (?);
					for (int32 i = 0; i < extraArgsCount; i++)
						extraArgs[i] = StackHelper.Pop!::<Object>(lua, i + {invokeMethod.ParamCount});\n
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
						Runtime.FatalError("Not implemented!");
					}
				}

				code.Append("StackHelper.Pop");
				code.Append(paramIsRef ? "Ref" : "!");
				code.AppendF($"<GetInvokeArg<F, const {i}>.Type>(lua, {i + 1})");

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
						code.AppendF($"StackHelper.Push(lua, {(returnsRef ? "ref " : "")}ret.{i});\n");
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

		public static int32 CallLayer<F>(lua_State L)
			where F : var
		{
			let lua = Lua.FromIntPtr(L);
#unwarn
			let func = ref User2Type.GetTypeDirect<F>(lua, Lua.UpValueIndex(1));

			EmitCallLayer<F>();

			// This is necessary to avoid the "Method must return" error
			Runtime.FatalError("Not reached");
		}
	}
}
