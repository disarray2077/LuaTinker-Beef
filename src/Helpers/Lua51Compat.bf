using System;
using System.Reflection;

namespace KeraLua;

extension Lua
{
	[Inline]
	public new LuaType RawGet(int32 index)
	{
		[Comptime]
		void Emit()
		{
			if (typeof(decltype(default(Lua).RawGet(default))) == typeof(LuaType))
			{
				Compiler.MixinRoot("return [NoExtension]RawGet(index);");
			}
			else
			{
				Compiler.MixinRoot(
					"""
					[NoExtension]RawGet(index);
					return Type(-1);
					""");
			}
		}

		Emit();
	}
}