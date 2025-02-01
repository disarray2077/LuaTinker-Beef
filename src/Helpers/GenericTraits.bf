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
			
			private enum IndexerMethods
			{
				Undefined = 0,
				Get = 1,
				Set = 2,
				GetSet = Get | Set
			}

			private class IndexerProperty
			{
				public Type Type;
				public IndexerMethods Methods;
				public List<(StringView name, Type type)> Parameters = new .() ~ delete _;
			}
			
			[Comptime]
			private static void _getIndexers(Type type, Dictionary<StringView, IndexerProperty> properties)
			{
				for (let methodInfo in type.GetMethods())
				{
					if (methodInfo.Name == "get__")
					{
						let propType = (methodInfo.ReturnType as RefType)?.UnderlyingType ?? methodInfo.ReturnType;
						let propertyName = ((int)propType.TypeId).ToString(.. scope .());
						if (properties.TryAdd(propertyName, let keyPtr, let valuePtr))
						{
							let indexerProp = new IndexerProperty();
							indexerProp.Type = propType;
							indexerProp.Methods = .Get;
							for (int i = 0; i < methodInfo.ParamCount; i++)
								indexerProp.Parameters.Add((methodInfo.GetParamName(i), methodInfo.GetParamType(i)));
							*valuePtr = indexerProp;
						}
						else
						{
							IndexerProperty indexerProp = (.)*valuePtr;
							Debug.Assert(indexerProp.Type == propType);
							if (!indexerProp.Methods.HasFlag(.Get))
								indexerProp.Methods |= .Get;
						}
					}
					else if(methodInfo.Name == "set__")
					{
						let propertyName = ((int)methodInfo.GetParamType(0).TypeId).ToString(.. scope .());
						if (properties.TryAdd(propertyName, let keyPtr, let valuePtr))
						{
							let indexerProp = new IndexerProperty();
							indexerProp.Type = methodInfo.GetParamType(0);
							indexerProp.Methods = .Set;
							for (int i = 1; i < methodInfo.ParamCount; i++)
								indexerProp.Parameters.Add((methodInfo.GetParamName(i), methodInfo.GetParamType(i)));
							*valuePtr = indexerProp;
						}
						else
						{
							IndexerProperty indexerProp = (.)*valuePtr;
							Debug.Assert(indexerProp.Type == methodInfo.GetParamType(0));
							if (!indexerProp.Methods.HasFlag(.Set))
								indexerProp.Methods |= .Set;
						}
					}
				}
			}
	
			[Comptime]
			private static Type _isIndexable(Type type, Type keyType)
			{
				if (type.IsGenericParam)
					return typeof(No);

				Dictionary<StringView, IndexerProperty> indexers = scope .();
				_getIndexers(type, indexers);

				if (indexers.IsEmpty)
					return typeof(No);

				for (let info in indexers.Values)
				{
					if (info.Parameters.IsEmpty || info.Parameters.Count > 1)
						continue;
					if (info.Parameters[0].type == keyType)
						return typeof(Yes);
				}

				return typeof(No);
			}
		}

		struct GetIndexerValue<T, TKey>
		{
			public typealias Result = comptype(_getIndexerValue(typeof(T), typeof(TKey)));
			
			private enum IndexerMethods
			{
				Undefined = 0,
				Get = 1,
				Set = 2,
				GetSet = Get | Set
			}

			private class IndexerProperty
			{
				public Type Type;
				public IndexerMethods Methods;
				public List<(StringView name, Type type)> Parameters = new .() ~ delete _;
			}
			
			[Comptime]
			private static void _getIndexers(Type type, Dictionary<StringView, IndexerProperty> properties)
			{
				for (let methodInfo in type.GetMethods())
				{
					if (methodInfo.Name == "get__")
					{
						let propType = (methodInfo.ReturnType as RefType)?.UnderlyingType ?? methodInfo.ReturnType;
						let propertyName = ((int)propType.TypeId).ToString(.. scope .());
						if (properties.TryAdd(propertyName, let keyPtr, let valuePtr))
						{
							let indexerProp = new IndexerProperty();
							indexerProp.Type = propType;
							indexerProp.Methods = .Get;
							for (int i = 0; i < methodInfo.ParamCount; i++)
								indexerProp.Parameters.Add((methodInfo.GetParamName(i), methodInfo.GetParamType(i)));
							*valuePtr = indexerProp;
						}
						else
						{
							IndexerProperty indexerProp = (.)*valuePtr;
							Debug.Assert(indexerProp.Type == propType);
							if (!indexerProp.Methods.HasFlag(.Get))
								indexerProp.Methods |= .Get;
						}
					}
					else if(methodInfo.Name == "set__")
					{
						let propertyName = ((int)methodInfo.GetParamType(0).TypeId).ToString(.. scope .());
						if (properties.TryAdd(propertyName, let keyPtr, let valuePtr))
						{
							let indexerProp = new IndexerProperty();
							indexerProp.Type = methodInfo.GetParamType(0);
							indexerProp.Methods = .Set;
							for (int i = 1; i < methodInfo.ParamCount; i++)
								indexerProp.Parameters.Add((methodInfo.GetParamName(i), methodInfo.GetParamType(i)));
							*valuePtr = indexerProp;
						}
						else
						{
							IndexerProperty indexerProp = (.)*valuePtr;
							Debug.Assert(indexerProp.Type == methodInfo.GetParamType(0));
							if (!indexerProp.Methods.HasFlag(.Set))
								indexerProp.Methods |= .Set;
						}
					}
				}
			}

			[Comptime]
			private static Type _getIndexerValue(Type type, Type keyType)
			{
				if (type.IsGenericParam)
					return typeof(var);

				Dictionary<StringView, IndexerProperty> indexers = scope .();
				_getIndexers(type, indexers);

				if (indexers.IsEmpty)
					return typeof(var);

				for (let info in indexers.Values)
				{
					if (info.Parameters.IsEmpty || info.Parameters.Count > 1)
						continue;
					if (info.Parameters[0].type == keyType)
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