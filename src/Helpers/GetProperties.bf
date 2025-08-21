using System;
using System.Collections;
using System.Diagnostics;
using System.Reflection;

namespace LuaTinker.Helpers
{
	static
	{
		public enum PropertyLookupFlaps
		{
			None = 0,
			Indexers = 1,
			Properties = 2,
			Gets = 4,
			Sets = 8,

			All = Indexers | Properties | Gets | Sets,
			AllIndexers = Indexers | Gets | Sets,
			AllProperties = Properties | Gets | Sets,
		}

		public enum PropertyMethods
		{
			Undefined = 0,
			Get = 1,
			Set = 2,
			GetSet = Get | Set
		}
	
		public class PropertyBase
		{
			public bool IsStatic;
			public Type Type;
			public Type DeclaringType;
			public PropertyMethods Methods;
		}
	
		public class NormalProperty : PropertyBase
		{
		}
	
		public class IndexerProperty : PropertyBase
		{
			public List<(StringView name, Type type)> Parameters = new .() ~ delete _;
		}
	
		[Comptime]
		public static void GetTypeProperties(Type type, Dictionary<StringView, PropertyBase> properties, PropertyLookupFlaps lookupFlags = .All)
		{
			for (let methodInfo in type.GetMethods())
			{
				if (methodInfo.Name == "get__")
				{
					if (!lookupFlags.HasFlag(.Indexers) || !lookupFlags.HasFlag(.Gets))
						continue;
					let propType = (methodInfo.ReturnType as RefType)?.UnderlyingType ?? methodInfo.ReturnType;
					let propertyName = new $"indexer[{propType}]";
					if (properties.TryAdd(propertyName, let keyPtr, let valuePtr))
					{
						let indexerProp = new IndexerProperty();
						indexerProp.IsStatic = methodInfo.IsStatic;
						indexerProp.Type = propType;
						indexerProp.DeclaringType = methodInfo.DeclaringType;
						indexerProp.Methods = .Get;
						for (int i = 0; i < methodInfo.ParamCount; i++)
							indexerProp.Parameters.Add((methodInfo.GetParamName(i), methodInfo.GetParamType(i)));
						*valuePtr = indexerProp;
					}
					else
					{
						IndexerProperty indexerProp = (.)*valuePtr;
						Debug.Assert(indexerProp.IsStatic == methodInfo.IsStatic && indexerProp.Type == propType);
						if (!indexerProp.Methods.HasFlag(.Get))
							indexerProp.Methods |= .Get;
					}
				}
				else if(methodInfo.Name == "set__")
				{
					if (!lookupFlags.HasFlag(.Indexers) || !lookupFlags.HasFlag(.Sets))
						continue;
					let propertyName = new $"indexer[{methodInfo.GetParamType(0)}]";
					if (properties.TryAdd(propertyName, let keyPtr, let valuePtr))
					{
						let indexerProp = new IndexerProperty();
						indexerProp.IsStatic = methodInfo.IsStatic;
						indexerProp.Type = methodInfo.GetParamType(0);
						indexerProp.DeclaringType = methodInfo.DeclaringType;
						indexerProp.Methods = .Set;
						for (int i = 1; i < methodInfo.ParamCount; i++)
							indexerProp.Parameters.Add((methodInfo.GetParamName(i), methodInfo.GetParamType(i)));
						*valuePtr = indexerProp;
					}
					else
					{
						IndexerProperty indexerProp = (.)*valuePtr;
						Debug.Assert(indexerProp.IsStatic == methodInfo.IsStatic && indexerProp.Type == methodInfo.GetParamType(0));
						if (!indexerProp.Methods.HasFlag(.Set))
							indexerProp.Methods |= .Set;
					}
				}
				else if (methodInfo.Name.StartsWith("get__"))
				{
					if (!lookupFlags.HasFlag(.Properties) || !lookupFlags.HasFlag(.Gets))
						continue;
					let propertyName = methodInfo.Name..RemoveFromStart(5);
					if (properties.TryAdd(propertyName, let keyPtr, let valuePtr))
					{
						let prop = new NormalProperty();
						prop.IsStatic = methodInfo.IsStatic;
						prop.Type = methodInfo.ReturnType;
						prop.DeclaringType = methodInfo.DeclaringType;
						prop.Methods = .Get;
						*valuePtr = prop;
					}
					else
					{
						NormalProperty prop = (.)*valuePtr;
						Debug.Assert(prop.IsStatic == methodInfo.IsStatic && prop.Type == methodInfo.ReturnType);
						if (!prop.Methods.HasFlag(.Get))
							prop.Methods |= .Get;
					}
				}
				else if (methodInfo.Name.StartsWith("set__"))
				{
					if (!lookupFlags.HasFlag(.Properties) || !lookupFlags.HasFlag(.Sets))
						continue;
					let propertyName = methodInfo.Name..RemoveFromStart(5);
					if (properties.TryAdd(propertyName, let keyPtr, let valuePtr))
					{
						let prop = new NormalProperty();
						prop.IsStatic = methodInfo.IsStatic;
						prop.Type = methodInfo.GetParamType(0);
						prop.DeclaringType = methodInfo.DeclaringType;
						prop.Methods = .Set;
						*valuePtr = prop;
					}
					else
					{
						NormalProperty prop = (.)*valuePtr;
						Debug.Assert(prop.IsStatic == methodInfo.IsStatic && prop.Type == methodInfo.GetParamType(0));
						if (!prop.Methods.HasFlag(.Set))
							prop.Methods |= .Set;
					}
				}
			}
		}
	}
}