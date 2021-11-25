using System;
using KeraLua;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;

namespace LuaTinker.Layers
{
	static
	{
		[Comptime]
		private static void EmitWrapperVar<T>(String code)
			where T : struct
		{
			code.Append("let wrapper = new:alloc ValuePointerWrapper<T>();\n");
		}

		[Comptime]
		private static void EmitWrapperVar<T>(String code)
			where T : class
		{
			code.Append("let wrapper = new:alloc ClassPointerWrapper<T>();\n");
		}

		[Comptime]
		private static void EmitCreatorLayer<T, Args>()
			where T : var
		{
			let type = typeof(Args);
			let code = scope String();

			// TODO: This commented code doesn't work as expected...
			//if (type.IsStruct || type.IsPrimitive || type.IsValueType)
			//	code.Append("let wrapper = new:alloc ValuePointerWrapper<T>();\n");
			//else
			//	code.Append("let wrapper = new:alloc ClassPointerWrapper<T>();\n");
			EmitWrapperVar<T>(code);

			code.Append("wrapper.Create(");

			if (type.IsTuple)
			{
				int fieldCount = type.FieldCount;
				for (int i = 0; i < fieldCount; i++)
				{
					code.AppendF($"StackHelper.Pop!<GetTupleField<Args, const {i}>.Type>(lua, {i + 2})");
	
					if (i != fieldCount - 1)
						code.Append(", ");
				}
			} else if (type != typeof(void))
			{
				code.Append("StackHelper.Pop!<Args>(lua, 2)");
			}

			code.Append(");\n");

			Compiler.Mixin(code);
		}

		public static int32 CreatorLayer<T>(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
#unwarn
			let alloc = LuaUserdataAllocator(lua);
			let tinkerState = LuaTinkerState.Find(lua);

			EmitCreatorLayer<T, void>();
			lua.GetGlobal(tinkerState.GetClassName<T>());
			lua.SetMetaTable(-2);

			return 1;
		}

		public static int32 CreatorLayer<T, Args>(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
#unwarn
			let alloc = LuaUserdataAllocator(lua);
			let tinkerState = LuaTinkerState.Find(lua);

			EmitCreatorLayer<T, Args>();
			lua.GetGlobal(tinkerState.GetClassName<T>());
			lua.SetMetaTable(-2);

			return 1;
		}
	}
}
