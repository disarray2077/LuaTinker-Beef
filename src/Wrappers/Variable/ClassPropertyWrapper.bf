using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.StackHelpers;

namespace LuaTinker.Wrappers
{
	public sealed class ClassPropertyWrapper<T, Name> : VariableWrapperBase
		where T : var
		where Name : const String
	{
		static this
		{
			[Comptime]
			void AssertValid()
			{
				if (typeof(T).IsGenericParam)
					return;
				let hasGetter = typeof(T).GetMethod(scope $"get__{Name}") case .Ok;
				let hasSetter = typeof(T).GetMethod(scope $"set__{Name}") case .Ok;
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
				let hasGetter = typeof(T).GetMethod(scope $"get__{Name}") case .Ok;
				if (!hasGetter)
				{
					Compiler.MixinRoot(
						"""
						lua.PushString("this property is write-only");
						lua.Error();
						""");
				}
				else
				{
					Compiler.MixinRoot(
						scope $$"""
						if (!lua.IsUserData(1))
						{
							lua.PushString("no class at first argument. (forgot ':' expression ?)");
							lua.Error();
						}
						
						let instance = StackHelper.Pop!<T>(lua, 1);
						StackHelper.Push(lua, instance.{{Name}});
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
				let hasSetter = typeof(T).GetMethod(scope $"set__{Name}") case .Ok(let methodInfo);
				if (!hasSetter)
				{
					Compiler.MixinRoot(
						"""
						lua.PushString("this property is read-only");
						lua.Error();
						""");
				}
				else
				{
					Compiler.MixinRoot(
						scope $$"""
						if (!lua.IsUserData(1))
						{
							lua.PushString("no class at first argument. (forgot ':' expression ?)");
							lua.Error();
						}
						
						let instance = StackHelper.Pop!<T>(lua, 1);
						instance.{{Name}} = StackHelper.Pop!<{{methodInfo.ReturnType.GetTypeId()}}>(lua, 3);
						""");
				}
			}

			Emit();
		}
	}
}
