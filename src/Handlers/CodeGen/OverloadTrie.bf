using System;
using System.Collections;
using System.Reflection;

using internal LuaTinker.Handlers;

namespace LuaTinker.Handlers
{
	static
	{
		internal enum MatchFlags : int16
		{
			None = 0,
			Params = 8,
			This = 16
		}

		internal struct MatchKey : this(Type MatchType, MatchFlags Flags), IHashable
		{
			public int GetHashCode()
			{
				let value1 = (int)(void*)Internal.UnsafeCastToPtr(MatchType);
				let value2 = (int)Flags;
				return value1 ^ value2;
			}
		}
		
		internal class Trie<T>
			where T : IHashable
		{
		    public Dictionary<T, Trie<T>> Children { get; } = new .() ~ DeleteDictionaryAndValues!(_);
			// Emission follows candidate discovery order, independently of dictionary hashes.
			public List<Trie<T>> OrderedChildren { get; } = new .() ~ delete _;
		    public bool IsEnd { get; internal set; }
			public T Value { get; private set; }
			public int CandidateIndex { get; internal set; }

		    public Trie<T> Insert(T value)
		    {
		        if (!Children.ContainsKey(value))
				{
		            Children[value] = new Trie<T>();
					OrderedChildren.Add(Children[value]);
				}
				let c = Children[value];
				c.Value = value;
				return c;
		    }

			public Trie<T> Get(T value)
			{
				if (Children.TryGetValue(value, let node))
					return node;
				return null;
			}
		}

		internal struct SelectorPosition : this(int LuaStackIndex);

		internal struct OverloadCandidate : this(MethodInfo Method, int ParameterStart, int ParameterCount);

		private static Trie<MatchKey> FindVariadicChild(Trie<MatchKey> node)
		{
			for (let child in node.OrderedChildren)
				if (child.Value.Flags.HasFlag(.Params))
					return child;
			return null;
		}

		private static void BuildOverloadTrie(Trie<MatchKey> trie, List<OverloadCandidate> candidates, List<LuaParameter> parameters, List<SelectorPosition> positions, bool isConstructor)
		{
			for (int candidateIndex < candidates.Count)
			{
				let candidate = candidates[candidateIndex];

				// Every candidate at a given depth consumes the same Lua stack slot.
				for (int i = positions.Count; i < candidate.ParameterCount; i++)
				{
					let parameter = parameters[candidate.ParameterStart + i];
					positions.Add(.(parameter.LuaStackIndex));
				}

				Trie<MatchKey> node = trie;
				if (candidate.ParameterCount == 0)
				{
					if (!isConstructor)
						Runtime.Assert(!node.IsEnd);
					node.CandidateIndex = candidateIndex;
					node.IsEnd = true;
					continue;
				}

				for (int i < candidate.ParameterCount)
				{
					let parameter = parameters[candidate.ParameterStart + i];
					MatchFlags flags = parameter.Role == .This ? .This : (parameter.IsVariadic ? .Params : .None);
					if (parameter.IsVariadic && parameter.VariadicElementType == null)
						Runtime.NotImplemented();
					let matchType = parameter.IsVariadic ? parameter.VariadicElementType : parameter.DeclaredType;
					node = node.Insert(.(matchType, flags));
					if (i == candidate.ParameterCount - 1)
					{
						if (!isConstructor)
							Runtime.Assert(!node.IsEnd);
						node.CandidateIndex = candidateIndex;
						node.IsEnd = true;
					}
				}
			}

			if (positions.IsEmpty)
			{
				positions.Add(.(isConstructor ? 2 : 1));
			}
		}
	}
}
