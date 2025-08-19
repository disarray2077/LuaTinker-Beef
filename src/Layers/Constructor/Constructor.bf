using System;
using KeraLua;
using LuaTinker.Wrappers;
using LuaTinker.StackHelpers;
using LuaTinker.Helpers;

using internal KeraLua;

namespace LuaTinker.Layers
{
	static
	{
		[Comptime]
		private static void EmitCreatorLayer<T, Args>()
			where T : var
		{
			if (typeof(T).IsGenericParam)
				return;

			let type = typeof(Args);
			let code = scope String();

			if (typeof(T).IsObject)
				code.Append("let wrapper = new:alloc ClassInstanceWrapper<T>();\n");
			else
				code.Append("let wrapper = new:alloc ValuePointerWrapper<T>();\n");

			code.Append("wrapper.Create(");

			if (type.IsTuple)
			{
				int fieldCount = type.FieldCount;
				for (int i = 0; i < fieldCount; i++)
				{
					code.AppendF($"StackHelper.Pop!<comptype({GetTupleFieldType<Args>(i).GetTypeId()})>(lua, {i + 2})");
	
					if (i != fieldCount - 1)
						code.Append(", ");
				}
			} else if (type != typeof(void))
			{
				code.Append("StackHelper.Pop!<Args>(lua, 2)");
			}

			code.Append(");\n");

			Compiler.MixinRoot(code);
		}

		public static int32 CreatorLayer<T, Args>(lua_State L)
		{
			let lua = Lua.FromIntPtr(L);
#unwarn
			let alloc = LuaUserdataAllocator(lua);
			let tinkerState = lua.TinkerState;

			EmitCreatorLayer<T, Args>();
			lua.GetGlobal(tinkerState.GetClassName<T>());
			lua.SetMetaTable(-2);

			return 1;
		}
	}
}
