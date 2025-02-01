using System;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;

namespace LuaTinker.Wrappers
{
	public sealed class IndexerWrapper<T, TKey> : IndexerWrapperBase
	{
		public override void Get(Lua lua)
		{
#unwarn
			let instance = User2Type.GetTypeDirect<ClassInstanceWrapper<T>>(lua, 1).ClassInstance;
	
			[Comptime]
			void Emit()
			{
				if (typeof(T).IsGenericParam)
					return;
	
				String code = scope .();
				code.AppendF($"""
					StackHelper.Push(lua, instance[StackHelper.Pop!<TKey>(lua, 2)]);
				""");
	
				Compiler.MixinRoot(code);
			}
	
			Emit();
	
		}
	
		public override void Set(Lua lua)
		{
#unwarn
			let instance = User2Type.GetTypeDirect<ClassInstanceWrapper<T>>(lua, 1).ClassInstance;
	
			[Comptime]
			void Emit()
			{
				if (typeof(T).IsGenericParam)
					return;
	
				String code = scope .();
				code.AppendF($"""
					instance[StackHelper.Pop!<TKey>(lua, 2)] = StackHelper.Pop!<GetIndexerValue<T, TKey>.Result>(lua, 3);
				""");
	
				Compiler.MixinRoot(code);
			}
	
			Emit();
		}
	}
}