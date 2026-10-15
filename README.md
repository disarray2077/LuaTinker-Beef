<p align="center">
  <img src="docs/logo.svg" alt="LuaTinker-Beef" width="560">
</p>

[Beef](https://www.beeflang.org/) bindings for Lua, inspired by [LuaTinker](https://github.com/zupet/LuaTinker) and [NLua](https://github.com/NLua/NLua) but with heavy use of compile-time code generation. Expose Beef types and functions to Lua, and call Lua from Beef with almost no runtime reflection.

## Key Features

- Beef-Lua interaction made [simple](#quick-start).
- Compile-time [binding generation](#binding).
    - Binding can be [fully automatic or manual](#binding).
- Bidirectional [function calls](#function-calls) between `Beef` and `Lua`.
- Fully compatible with `Lua` coroutines and threads
- First-class support for key `Beef` language features:
    - [Overload resolution](#automatic-binding).
    - [Variadic arguments](#automatic-binding).
    - [Inheritance](#inheritance).
    - [Collection indexers](#indexers).
    - [Boxed value types](#boxed-values).
- Frictionless `Beef` interop:
    - Tables can be used as [Beef spans](#span-conversion).
    - Lua callbacks can be used as [Beef delegates](#lua-callbacks-as-beef-delegates).
    - Numeric and enum overloads can be easily [disambiguated](#numeric-and-enum-arguments).

> [!WARNING]
> LuaTinker-Beef is experimental and under active development. APIs and behavior may change.
> Use the latest Beef nightly release for compiler compatibility.

## Dependencies

### Library

- [KeraLua-Beef](https://github.com/disarray2077/KeraLua-Beef) for Lua 5.4.
- For Lua 5.1 or LuaJIT, use [KeraLua51-Beef](https://github.com/disarray2077/KeraLua51-Beef) instead.

### GameSample and Playground

GameSample and Playground use Beef's bundled SDL2 bindings for windows and input, [BeefGL](https://github.com/disarray2077/BeefGL) for rendering, and SDL2_mixer for audio. Playground also uses [StbImageBeef](https://github.com/StbBeef/StbImageBeef) and SDL2_image to load images.

The browser version of Playground is built with Emscripten through [scripts/build-wasm.ps1](scripts/build-wasm.ps1). Building its React interface also requires Node.js and npm. See [frontend development](Playground/web/README.md) for UI-only builds.

## Quick Start

Create a Lua state, register a Beef type, and exchange values with a script:

```cs
public static void Main()
{
    let lua = scope Lua(true);
    lua.Encoding = System.Text.Encoding.UTF8;
    let tinker = scope LuaTinker(lua);

    tinker.AutoTinkClass<System.String, const "StringBuilder">();
    tinker.SetValue("name", "Ada");
    tinker.SetValue("score", 10);

    if (tinker.Eval("""
        message = StringBuilder()
        message:Append("Hello, ")
        message:Append(name)
        print(message) -- Hello, Ada

        score = score + 5
        player = { name = name, score = score }

        function add(a, b)
            return a + b
        end
        """) case .Err(let error))
    {
        Console.WriteLine(error);
        return;
    }

    // Read a global, evaluate an expression, and call a Lua function.
    Console.WriteLine(tinker.GetValue<int>("score").Get());        // 15
    Console.WriteLine(tinker.Eval<int>("return score * 2").Get()); // 30
    Console.WriteLine(tinker.Call<int, ?>("add", (2, 3)).Get());   // 5

    // Read and modify a Lua table from Beef.
    if (tinker.GetTable!("player") case .Ok(var player))
    {
        Console.WriteLine(player.GetValue<StringView>("name").Get()); // Ada
        player.SetValue("score", 25);
    }

    Console.WriteLine(tinker.Eval<int>("return player.score").Get()); // 25
}
```

## Binding

### Automatic Binding

`AutoTinkClass` makes a Beef type's supported public members available in Lua. Here, registering `String` lets the script construct a Beef string, call its `Append` overloads, and print it through `Console`.

> [!NOTE]
> Parent hierarchies, enums, and constant fields still need explicit registration. However, this may change in the future.

```cs
tinker.AutoTinkClass<System.Console>();
tinker.AutoTinkClass<System.String, const "StringBuilder">();
```

```lua
local text = StringBuilder()
text:Append("Hello, ")
text:Append("LuaTinker", 0, 3) -- Uses the offset and length overload.
text:AppendF(" from {}!", "Beef")
System.Console.WriteLine(text) -- Hello, Lua from Beef!
```

### Manual Binding

`AddClass` registers a type, and you choose which members to expose. For `Vector2`, the bindings below give Lua a constructor, access to the coordinates, and a method to calculate the squared length.

```cs
public struct Vector2
{
    public float x, y;

    public this(float x, float y)
    {
        this.x = x;
        this.y = y;
    }

    public float LengthSquared() => x * x + y * y;
}

// Register the type, its constructor, fields, and a method.
tinker.AddClass<Vector2>();
tinker.AddClassCtor<Vector2, (float, float)>();
tinker.AddClassVar<Vector2, const "x">(); // The field itself is registered, not just its current value.
tinker.AddClassVar<Vector2, const "y">();
tinker.AddClassMethod<Vector2, function float(Vector2 this)>(
    "LengthSquared", => Vector2.LengthSquared);
```

```lua
local vec = Vector2(3, 4)
print(vec.x) -- 3
vec.y = 5
print(vec:LengthSquared()) -- 34
```

### Function Calls

`AddMethod` exposes the Beef addition function as Lua's `Add`. The script uses it to define `AddThenDouble`, which Beef then calls through `Call`. LuaTinker converts the arguments and results between Lua numbers and the `int32` type.

```cs
tinker.AddMethod<function int32(int32, int32)>(
    "Add", (left, right) => left + right);

if (tinker.Eval("""
    function AddThenDouble(a, b)
        return Add(a, b) * 2
    end

    print(Add(2, 3)) -- Lua calls Beef: 5.
    """) case .Err(let error))
{
    Console.WriteLine(error);
    return;
}

// Beef calls Lua, which calls Beef again.
if (tinker.Call<int32, ?>("AddThenDouble", (4, 6)) case .Ok(let result))
    Console.WriteLine(result); // 20
```

Lua can return several values from one call. A Beef tuple receives them together, with a type for each result:

```cs
let pair = tinker.Eval<(int, bool)>("return 7, true").Get();
Console.WriteLine(pair.0); // 7
Console.WriteLine(pair.1); // True
```

### Inheritance

Once `MyBase` and `MyTest` are registered, `AddClassParent` connects them in Lua. A `MyTest` instance can then access the inherited field `a` alongside its own field `b`.

```cs
class MyBase
{
    public int a = 15;
}

class MyTest : MyBase
{
    public int b = 14;
}

// Register both types and link the child to its parent.
tinker.AddClass<MyBase>();
tinker.AddClassVar<MyBase, const "a">();

tinker.AddClass<MyTest>();
tinker.AddClassCtor<MyTest>();
tinker.AddClassParent<MyTest, MyBase>();
tinker.AddClassVar<MyTest, const "b">();
```

```lua
local test = MyTest()
print(test.a) -- 15, inherited from MyBase.
print(test.b) -- 14
```

### Indexers

`AddClassIndexer` lets Lua read and write a Beef collection through `[]`. For this `System.Collections.List<float>`, `list[0]` reads the first element and assigning `list[1]` changes the original list's second element.

```cs
List<float> values = scope .() { 1.0f, 2.0f, 3.0f };
tinker.AddMethod<delegate List<float>()>("GetList", new () => values);

tinker.AddClass<List<float>>("FloatList");
tinker.AddClassIndexer<List<float>, int>();
```

```lua
local list = GetList()
print(list[0]) -- 1.0
list[1] = 99.0
print(list[1]) -- 99.0
```

### Boxed Values

A value type can cross into Lua while boxed in an `Object`. The same Beef function can receive an existing box or a value constructed in Lua, then unbox it to calculate the vector's squared length.

```cs
tinker.AddClass<Vector2>();
tinker.AddClassCtor<Vector2, (float, float)>();

Object boxedVector = scope box Vector2(3, 4);
tinker.SetValue("vector", boxedVector);

tinker.AddMethod<function float(Object)>(
    "LengthSquared", (value) => ((Vector2)value).LengthSquared());

tinker.Eval("""
    print(LengthSquared(vector)) -- 25
    print(LengthSquared(Vector2(5, 12))) -- 169
    """).Get();
```

### Span Conversion

Lua sequences can be passed to Beef functions taking `Span<T>`. The script below supplies three scores, which LuaTinker copies into a span for `Sum` to add together.

```cs
tinker.AddMethod<function int32(Span<int32>)>("Sum", (values) =>
{
    int32 total = 0;
    for (let value in values)
        total += value;
    return total;
});

tinker.Eval("""
    scores = {10, 20, 30}
    print(Sum(scores)) -- 60
    """).Get();
```

To work with the same sequence directly in Beef, use `GetSpan!`. Its copied storage lasts for the calling scope:

```cs
if (tinker.GetSpan!<int32>("scores") case .Ok(let scores))
{
    for (let score in scores)
        Console.WriteLine(score); // 10, then 20, then 30.
}
```

### Lua Callbacks as Beef Delegates

`RegisterDelegate` lets a Lua function fill a Beef delegate parameter for the duration of the call. Here, `Apply` calls the supplied Lua function with `21` and returns its result.

```cs
tinker.RegisterDelegate<delegate int32(int32)>();
tinker.AddMethod<function int32(delegate int32(int32), int32)>(
    "Apply", (callback, value) => callback(value));

tinker.Eval("""
    print(Apply(function(value)
        return value * 2
    end, 21)) -- 42
    """).Get();
```

### Numeric and Enum Arguments

Numeric casts let Lua choose the Beef parameter type when numeric and enum overloads compete. Here, `int32.cast(2)` selects the multiplier overload, while the typed `Difficulty` constants and casts select the difficulty overload.

```cs
public enum Difficulty
{
    Normal = 1,
    Hard = 2
}

public static class Rewards
{
    public static int32 Bonus(int64 dummy) => 0;
    public static int32 Bonus(int32 multiplier) => 10 * multiplier;
    public static int32 Bonus(Difficulty difficulty) =>
        difficulty == .Hard ? 50 : 10;
}

tinker.AddEnum<Difficulty>("Difficulty", true); // Register typed enum constants.
tinker.AddNamespace("Rewards");
tinker.AddNamespaceMethod<Rewards, const "Bonus">("Rewards");
```

```lua
print(Rewards.Bonus(int32.cast(2))) -- 20
print(Rewards.Bonus(Difficulty.Hard)) -- 50
print(Rewards.Bonus(Difficulty.cast(1))) -- 10
```

## Contributing

Contributions are welcome! Feel free to open an issue to report a bug or suggest a feature, or submit a pull request with your improvements.

## License

This project is licensed under the ISC License - see the [LICENSE](LICENSE) file for details.