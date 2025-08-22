using System;
using System.Collections;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;

namespace LuaTinker.Wrappers
{
	public sealed class IndexerWrapper<T, TKey> : IndexerWrapperBase
	{
		static this
		{
			[Comptime]
			void AssertValid()
			{
				if (typeof(T).IsGenericParam)
					return;
				if (typeof(GetIndexerValue<T, TKey>.Result) == typeof(var))
					Runtime.FatalError(scope $"Type \"{typeof(T)}\" has no indexer with key of type \"{typeof(TKey)}\"");
			}

			AssertValid();
		}

		public override Type KeyType => typeof(TKey);

		public override bool Get(Lua lua)
		{
			[Comptime]
			void Emit()
			{
				if (typeof(T).IsGenericParam)
					return;
				
				Dictionary<StringView, PropertyBase> indexers = scope .();
				GetTypeProperties(typeof(T), indexers, .Indexers | .Gets);

				bool hasGetter = false;
				for (let info in indexers.Values)
				{
					let indexerInfo = (IndexerProperty)info;
					if (indexerInfo.Parameters.IsEmpty || indexerInfo.Parameters.Count > 1)
						continue;
					if (indexerInfo.Parameters[0].type == typeof(TKey))
					{
						hasGetter = true;
						break;
					}
				}

				if (!hasGetter)
				{
					Compiler.MixinRoot(
						"""
						lua.TinkerState.SetLastError("this indexer is write-only");
						StackHelper.ThrowError(lua, lua.TinkerState);
						""");
				}
				else
				{
					Compiler.MixinRoot(scope
						$$"""
						if (!lua.IsUserData(1))
						{
							lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
							StackHelper.ThrowError(lua, lua.TinkerState);
						}

						let instance = User2Type.GetTypeDirect<ClassInstanceWrapper<T>>(lua, 1).ClassInstance;
						StackHelper.Push(lua, instance[StackHelper.Pop!<TKey>(lua, 2)]);
						""");
				}
			}
	
			Emit();
			return true;
	
		}
	
		public override bool Set(Lua lua)
		{
			[Comptime]
			void Emit()
			{
				if (typeof(T).IsGenericParam)
					return;
				
				Dictionary<StringView, PropertyBase> indexers = scope .();
				GetTypeProperties(typeof(T), indexers, .Indexers | .Sets);

				bool hasSetter = false;
				for (let info in indexers.Values)
				{
					let indexerInfo = (IndexerProperty)info;
					if (indexerInfo.Parameters.IsEmpty || indexerInfo.Parameters.Count > 1)
						continue;
					if (indexerInfo.Parameters[0].type == typeof(TKey))
					{
						hasSetter = true;
						break;
					}
				}

				if (!hasSetter)
				{
					Compiler.MixinRoot(
						"""
						lua.TinkerState.SetLastError("this indexer is read-only");
						StackHelper.ThrowError(lua, lua.TinkerState);
						""");
				}
				else
				{
					Compiler.MixinRoot(scope
						$$"""
						if (!lua.IsUserData(1))
						{
							lua.TinkerState.SetLastError("no class at first argument. (forgot ':' expression ?)");
							StackHelper.ThrowError(lua, lua.TinkerState);
						}
						
						let instance = User2Type.GetTypeDirect<ClassInstanceWrapper<T>>(lua, 1).ClassInstance;
						instance[StackHelper.Pop!<TKey>(lua, 2)] = StackHelper.Pop!<GetIndexerValue<T, TKey>.Result>(lua, 3);
						""");
				}
			}
	
			Emit();
			return true;
		}

		public override IndexerWrapperBase CreateNew()
		{
			return new IndexerWrapper<T, TKey>();
		}
	}
}