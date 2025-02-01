using System;
using System.Reflection;
using System.Collections;
using System.Diagnostics;

namespace LuaTinker.Helpers
{
	static
	{
		struct Yes;
		struct No;

		struct IsIndexable<T, TKey>
		{
			public typealias Result = comptype(_isIndexable(typeof(T), typeof(TKey)));
	
			[Comptime]
			private static Type _isIndexable(Type type, Type keyType)
			{
				if (type.IsGenericParam)
					return typeof(No);

				Dictionary<StringView, PropertyBase> indexers = scope .();
				GetTypeProperties(type, indexers, .AllIndexers);

				if (indexers.IsEmpty)
					return typeof(No);

				for (let info in indexers.Values)
				{
					let indexerInfo = (IndexerProperty)info;
					if (indexerInfo.Parameters.IsEmpty || indexerInfo.Parameters.Count > 1)
						continue;
					if (indexerInfo.Parameters[0].type == keyType)
						return typeof(Yes);
				}

				return typeof(No);
			}
		}

		struct GetIndexerValue<T, TKey>
		{
			public typealias Result = comptype(_getIndexerValue(typeof(T), typeof(TKey)));

			[Comptime]
			private static Type _getIndexerValue(Type type, Type keyType)
			{
				if (type.IsGenericParam)
					return typeof(var);
				
				Dictionary<StringView, PropertyBase> indexers = scope .();
				GetTypeProperties(type, indexers, .AllIndexers);

				if (indexers.IsEmpty)
					return typeof(var);

				for (let info in indexers.Values)
				{
					let indexerInfo = (IndexerProperty)info;
					if (indexerInfo.Parameters.IsEmpty || indexerInfo.Parameters.Count > 1)
						continue;
					if (indexerInfo.Parameters[0].type == keyType)
						return info.Type;
				}

				return typeof(var);
			}
		}
	
		struct GetGenericArg<T, C>
			where C : const int
		{
			public typealias Result = comptype(_getArg(typeof(T), C));
	
			[Comptime]
			private static Type _getArg(Type type, int argIdx)
			{
				if (let refType = type as SpecializedGenericType)
					return refType.GetGenericArg(argIdx);
				return typeof(int);
			}
		}
	}
}