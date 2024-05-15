using System;
using System.Collections;

namespace LuaTinker.Helpers;

public class Trie<T>
	where T : IHashable
{
    public Dictionary<T, Trie<T>> Children { get; } = new .() ~ DeleteDictionaryAndValues!(_);
    public bool IsEnd { get; private set; }
	public T Value { get; private set; }
	public void* Tag { get; private set; }

    public Trie<T> Insert(T value)
    {
        if (!Children.ContainsKey(value))
            Children[value] = new Trie<T>();
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