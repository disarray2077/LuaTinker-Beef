using System;
using System.Reflection;
using System.Collections;
using System.Diagnostics;

namespace LuaTinker.Helpers
{
	static
	{
		typealias FirstGenericArg<T> = GetGenericArg<T, const 0>.Result;

		public static Type GetSpanElement(Type type)
		{
			if (let specialized = type as SpecializedGenericType)
				if (specialized.UnspecializedType == typeof(Span<>) && specialized.GenericParamCount == 1)
					return specialized.GetGenericArg(0);
			return null;
		}

		struct Yes;
		struct No;

		// Type has no public function-kind query; inspect its flag without relaxing corlib visibility.
		[Inline]
		public static bool IsFunctionType(Type type)
			=> !type.IsGenericParam && type.[Friend]mTypeFlags.HasFlag(.Function);

		struct IsFunction<T> where T : var
		{
			public typealias Result = comptype(IsFunctionType(typeof(T)) ? typeof(Yes) : typeof(No));
		}

		// Corlib exposes no public delegate-kind query; use its flag without changing visibility.
		[Inline]
		public static bool IsDelegateType(Type type)
			=> !type.IsGenericParam && type.[Friend]mTypeFlags.HasFlag(.Delegate);

		struct IsDelegate<T> where T : var
		{
			public typealias Result = comptype(IsDelegateType(typeof(T)) ? typeof(Yes) : typeof(No));
		}

		struct IsInputSpan<T> where T : var
		{
			public typealias Result = comptype(_isInputSpan(typeof(T)));

			[Comptime]
			private static Type _isInputSpan(Type type)
			{
				if (let specialized = type as SpecializedGenericType)
					return specialized.UnspecializedType == typeof(Span<>) ? typeof(Yes) : typeof(No);
				return typeof(No);
			}
		}

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
