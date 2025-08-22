using System;
using System.Collections;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;
using LuaTinker.Wrappers;

using internal KeraLua;

namespace LuaTinker.Wrappers
{
	public sealed class IndexerAggregatorWrapper : IndexerWrapperBase
	{
		struct Indexer : IDisposable
		{
			public Type KeyType;
			public IndexerWrapperBase Instance;

			public void Dispose()
			{
				delete Instance;
			}				
		}

		private append List<Indexer> mIndexers ~ for (let indexer in _) indexer.Dispose();

		public void AddIndexer(Type keyType, IndexerWrapperBase indexer)
		{
			mIndexers.Add(.() { KeyType = keyType, Instance = indexer });
		}

		private static Type GetTypeFromStack(Lua lua, int32 index)
		{
			var type = lua.Type(index);
			switch (type)
			{
				case LuaType.Number:
					if (lua.IsInteger(index))
						return typeof(int64);
					return typeof(double);
				case LuaType.String:
					return typeof(StringView);
				case LuaType.Boolean:
					return typeof(bool);
				case LuaType.UserData:
					return User2Type.GetObjectType(lua, index); 
				default:
					return null;
			}
		}

		private static bool AreTypesCompatible(Type keyType, Type indexerType)
		{
		    if (keyType.IsSubtypeOf(indexerType))
		        return true;

		    if (keyType.IsInteger && (indexerType.IsInteger || indexerType.IsFloatingPoint))
		        return true;

		    if (keyType.IsFloatingPoint && indexerType.IsFloatingPoint)
		        return true;

		    let isKeyStringLike = keyType == typeof(String) || keyType == typeof(StringView);
		    let isIndexerStringLike = indexerType == typeof(String) || indexerType == typeof(StringView);
		    if (isKeyStringLike && isIndexerStringLike)
		        return true;

		    return false;
		}

		public override void Get(Lua lua)
		{
			var keyType = GetTypeFromStack(lua, 2);

			IndexerWrapperBase foundIndexer = null;
			for (let indexer in mIndexers)
			{
				if (AreTypesCompatible(keyType, indexer.KeyType))
				{
					foundIndexer = indexer.Instance;
					break;
				}
			}

			if (foundIndexer == null)
			{
				lua.TinkerState.SetLastError("no indexer found for the given key type");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}

			foundIndexer.Get(lua);
		}

		public override void Set(Lua lua)
		{
			var keyType = GetTypeFromStack(lua, 2);

			IndexerWrapperBase foundIndexer = null;
			for (let indexer in mIndexers)
			{
				if (AreTypesCompatible(keyType, indexer.KeyType))
				{
					foundIndexer = indexer.Instance;
					break;
				}
			}

			if (foundIndexer == null)
			{
				lua.TinkerState.SetLastError("no indexer found for the given key type");
				StackHelper.ThrowError(lua, lua.TinkerState);
			}

			foundIndexer.Set(lua);
		}

		public override IndexerWrapperBase CreateNew()
		{
			Runtime.NotImplemented();
		}

		public override void OnRemovedFromLua(LuaTinkerState tinkerState)
		{
			for (let indexer in mIndexers)
				tinkerState.DeregisterAliveObject(indexer.Instance);
		}
	}
}