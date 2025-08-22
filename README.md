# LuaTinker-Beef

A powerful, compile-time binding library for integrating **BeefLang** with **Lua**, inspired by [LuaTinker](https://github.com/zupet/LuaTinker) and [NLua](https://github.com/NLua/NLua).

LuaTinker-Beef allows you to seamlessly call Lua functions from Beef and expose Beef types, methods, and variables to your Lua scripts. Its core philosophy is to perform all binding work at **compile-time**, completely avoiding the overhead of runtime reflection.

## Key Features

-   **Compile-Time Generation**: No reflection means fast startup and minimal runtime overhead.
-   **Automatic & Manual Binding**: Quickly bind entire classes with `AutoTinkClass` or manually specify every function, property, and field for fine-grained control.
-   **Seamless Interop**: Call Lua functions from Beef and vice-versa with natural syntax.
    -   **Dynamic Overload Resolution**: Function overloads are also supported! LuaTinker will attempt to call the correct function overload at run-time based on the provided arguments.
-   **Rich Type Support**: Bind classes, structs, methods, properties, fields, enums, and indexers.
-   **Inheritance**: Correctly handles class and struct inheritance hierarchies.

## Important Notes

-   This library is under active development, and the API may change.
-   It is strongly recommended to use the latest **Beef nightly release** for the best compatibility.

## Dependencies

This library requires [KeraLua-Beef](https://github.com/disarray2077/KeraLua-Beef).
-   For Lua 5.1 or LuaJIT, use [KeraLua51-Beef](https://github.com/disarray2077/KeraLua51-Beef) instead.

## Quick Start

This example demonstrates binding Beef's `System.IO.File` and `System.String` classes to Lua, allowing a Lua script to read a file and format a string.

```cs
using System;
using System.IO;
using KeraLua;

void RunExample()
{
    let lua = scope Lua(true);
    lua.Encoding = System.Text.Encoding.UTF8;

    LuaTinker tinker = scope .(lua);

    // Automatically expose public members of these classes to Lua
    tinker.AutoTinkClass<System.IO.File>();
    tinker.AutoTinkClass<System.String, const "StringBuilder">(); // Rename String to StringBuilder in Lua

    // Create a temporary file for the example
    File.WriteAllText("test_tmp.txt", "All works!");
    defer File.Delete("test_tmp.txt");

    // Execute a Lua script that uses the bound Beef classes
    let result = lua.DoString(
        @"""
        -- Create a new String (exposed as StringBuilder) instance
        outString = StringBuilder()

        -- Call a static Beef method from Lua
        System.IO.File.ReadAllText("test_tmp.txt", outString, false)

        -- Use the instance to format a new string
        string = StringBuilder()
        string:AppendF("Test '{}'", outString)
        
        -- Print the result
        print(string) -- outputs: Test 'All works!'
        """
    );

    if (result)
    {
        Console.WriteLine($"Lua Error: {lua.ToString(-1, .. scope .())}");
    }
}
```

## Features in Detail

Here are examples of the core features, adapted from the project's test suite.

### 1. Automatic Class Binding (`AutoTinkClass`)

The easiest way to expose a Beef type to Lua. It automatically binds public constructors, methods, properties, and fields.

**Beef Code:**
```cs
let lua = scope Lua(true);
LuaTinker tinker = scope .(lua);

// Expose System.Console and String
tinker.AutoTinkClass<System.Console>();
tinker.AutoTinkClass<System.String>();
```

**Lua Script:**
```lua
-- Create an instance of the bound class
str = String()

-- Call instance methods
str:Append("Hello, ")
str:Append("Lua!")

-- Call a static method
System.Console.WriteLine(str) -- Outputs: Hello, Lua!
```

### 2. Manual Binding

For full control, you can bind classes and their members individually.

**Beef Code:**
```cs
public struct Vector2
{
    public float x, y;
    public this(float x, float y) { this.x = x; this.y = y; }
    public float GetMagnitude() => x * x + y * y;
}

// ...

let lua = scope Lua(true);
LuaTinker tinker = scope .(lua);

// Register the class itself
tinker.AddClass<Vector2>();
// Register a constructor: new(float, float)
tinker.AddClassCtor<Vector2, (float, float)>();
// Register a field
tinker.AddClassVar<Vector2, const "x">();
tinker.AddClassVar<Vector2, const "y">();
// Register a method
tinker.AddClassMethod<Vector2, function float(Vector2 this)>("GetMagnitude", => Vector2.GetMagnitude);
```

**Lua Script:**
```lua
-- Create an instance using the bound constructor
vec = Vector2(3, 4)

-- Access and modify member variables
print(vec.x) -- outputs: 3
vec.y = 5

-- Call a bound method
print(vec:GetMagnitude()) -- outputs: 34 (3*3 + 5*5)
```

### 3. Calling Lua Functions from Beef

You can execute global Lua functions directly from your Beef code and retrieve the results.

**Lua Script:**
```lua
var = 20

function TestRetPlus(a, b)
    return var + a + b
end
```

**Beef Code:**
```cs
let result = tinker.Call<int, ?>("TestRetPlus", (13, (char32)22));
if (result case .Ok(let val))
{
    // val will be 55 (20 + 13 + 22)
    Test.Assert(val == 55);
}
```

### 4. Accessing Lua Global Variables

Get and set global variables in the Lua state from Beef.

**Beef Code:**
```cs
let lua = scope Lua(true);
LuaTinker tinker = scope .(lua);

// Set global variables in Lua from Beef
tinker.SetValue("my_name", "LuaTinker-Beef");
tinker.SetValue("version", 1.0);

// Run Lua code that uses them
lua.DoString("print(my_name .. ' v' .. version)");

// Get a global variable from Lua
if (tinker.GetValue<StringView>("my_name") case .Ok(let name))
{
    Test.Assert(name == "LuaTinker-Beef");
}
```

### 5. Binding Inheritance

Expose class or struct inheritance hierarchies to Lua.

**Beef Code:**
```cs
class MyBase { public int a = 15; }
class MyTest : MyBase { public int b = 14; }

// ...

tinker.AddClass<MyBase>();
tinker.AddClassVar<MyBase, const "a">();

tinker.AddClass<MyTest>();
tinker.AddClassCtor<MyTest>();
tinker.AddClassParent<MyTest, MyBase>(); // Link child to parent
tinker.AddClassVar<MyTest, const "b">();
```

**Lua Script:**
```lua
test = MyTest()
print(test.a) -- outputs: 15 (from MyBase)
print(test.b) -- outputs: 14 (from MyTest)
```

### 6. Binding Indexers (for `List` and `Dictionary`)

Expose collection indexers, allowing `[]` access in Lua.

**Beef Code:**
```cs
List<float> testList = scope .() { 1.0f, 2.0f, 3.0f };
tinker.AddMethod<delegate List<float>()>("GetList", new () => testList);

tinker.AddClass<List<float>>("FloatList");
tinker.AddClassIndexer<List<float>, int>();
```

**Lua Script:**
```lua
list = GetList()
print(list[0]) -- outputs: 1.0
list[1] = 99.0 -- Modify the value in the Beef list
print(list[1]) -- outputs: 99.0
```

### 7. Working with Lua Tables

You can get a Lua table as a `LuaTable` object in Beef to inspect or modify its contents.

**Lua Script:**
```lua
player_data = {
    name = "Player One",
    score = 12345,
    is_active = true
}
```

**Beef Code:**
```cs
if (tinker.GetTable!("player_data") case .Ok(var table))
{
    // Read values from the table
    Test.Assert(table.GetValue<StringView>("name").Get() == "Player One");
    Test.Assert(table.GetValue<int>("score").Get() == 12345);

    // Write a new value to the table
    table.SetValue("score", 99999);
}
```

## Contributing

Contributions are highly encouraged! Feel free to open an issue to report a bug or suggest a feature, or submit a pull request with your improvements.

## License

This project is licensed under the ISC License - see the [LICENSE](LICENSE) file for details.