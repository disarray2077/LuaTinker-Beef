using System;
using System.Diagnostics;
using System.Reflection;
using KeraLua;
using LuaTinker.StackHelpers;

namespace LuaTinker.Wrappers
{
	public sealed class ClassPropertyWrapper<T, Name> : VariableWrapperBase
		where T : var
		where Name : const String
	{
		[Comptime]
		private static Result<MethodInfo> GetAccessor(StringView methodName)
		{
			for (let method in typeof(T).GetMethods())
				if (method.Name == methodName && method.IsPublic && !method.HasCustomAttribute<UncheckedAttribute>())
					return .Ok(method);
			return .Err;
		}

		static this
		{
			[Comptime]
			void AssertValid()
			{
				if (typeof(T).IsGenericParam)
					return;
				let hasGetter = GetAccessor(scope $"get__{Name}") case .Ok;
				let hasSetter = GetAccessor(scope $"set__{Name}") case .Ok;
				if (!hasGetter && !hasSetter)
					Runtime.FatalError(scope $"Type \"{typeof(T)}\" has no property named \"{Name}\"");
			}

			AssertValid();
		}

		public override void Get(Lua lua)
		{
			[Comptime]
			void Emit()
			{
				if (typeof(T).IsGenericParam)
					return;
				let hasGetter = GetAccessor(scope $"get__{Name}") case .Ok(let methodInfo);
				if (!hasGetter)
				{
					Compiler.MixinRoot(
						"""
						lua.TinkerState.SetLastError("this property is write-only");
						StackHelper.ThrowError(lua, lua.TinkerState);
						""");
				}
				else
				{
					let receiver = typeof(T).IsValueType
						? "var instance = ref StackHelper.PopRef<T>(lua, 1);"
						: "let instance = StackHelper.Pop!<T>(lua, 1);";
					let byRef = (methodInfo.ReturnType is RefType) ? "ref " : "";
					Compiler.MixinRoot(
						scope $$"""
						if (!lua.IsUserData(1))
						{
							lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
							StackHelper.ThrowError(lua, lua.TinkerState);
						}
						
						{{receiver}}
						StackHelper.Push(lua, {{byRef}}instance.{{Name}});
						""");
				}
			}

			Emit();
		}

		public override void Set(Lua lua)
		{
			[Comptime]
			void Emit()
			{
				if (typeof(T).IsGenericParam)
					return;
				let hasSetter = GetAccessor(scope $"set__{Name}") case .Ok(let methodInfo);
				if (!hasSetter)
				{
					Compiler.MixinRoot(
						"""
						lua.TinkerState.SetLastError("this property is read-only");
						StackHelper.ThrowError(lua, lua.TinkerState);
						""");
				}
				else
				{
					let receiver = typeof(T).IsValueType
						? "var instance = ref StackHelper.PopRef<T>(lua, 1);"
						: "let instance = StackHelper.Pop!<T>(lua, 1);";
					let paramType = methodInfo.GetParamType(0);
					let value = (paramType is RefType)
						? scope $"ref StackHelper.PopRef<comptype({paramType.UnderlyingType.GetTypeId()})>(lua, 3)"
						: scope $"StackHelper.Pop!<comptype({paramType.GetTypeId()})>(lua, 3)";
					Compiler.MixinRoot(
						scope $$"""
						if (!lua.IsUserData(1))
						{
							lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
							StackHelper.ThrowError(lua, lua.TinkerState);
						}
						
						{{receiver}}
						instance.{{Name}} = {{value}};
						""");
				}
			}

			Emit();
		}
	}
}
