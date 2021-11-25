# LuaTinker-Beef

This is a library to bind BeefLang to Lua, inspired by [LuaTinker](https://github.com/zupet/LuaTinker).

## Notes

- This library is in no way in a final state and may change drastically in next updates, there are still many things to improve and contributions are very welcome.
- This library (currently) makes no use of Reflection, everything is generated in compile-time.
- I strongly recommend the use of the latest Beef nightly release when using this library.

## Dependencies

The only dependency of this library is [KeraLua-Beef](https://github.com/disarray2077/KeraLua-Beef)

## Example

The example below was extracted from the file `TestClassInterop.bf` and demonstrates the use of Beef's `System.IO.File` to read an file and `System.String` to format an string with the file content, all of this inside of Lua.

```cs
let lua = scope Lua(true);
lua.Encoding = System.Text.Encoding.UTF8;

LuaTinker tinker = scope .(lua);

tinker.AddNamespace("System.IO.File");
tinker.AddNamespaceMethod("System.IO.File", "ReadAllText", (function Result<void, FileError>(StringView, String, bool)) => File.ReadAllText);

tinker.AddClass<String>("StringBuilder");
tinker.AddClassCtor<String>();
tinker.AddClassMethod<String, function Result<void>(String this, StringView, params Object[])>("AppendF", => String.AppendF);
String StrImpl(String self) => self;
tinker.AddClassMethod<String, function String(String)>("str", => StrImpl); // This is necessary to convert from the class instance to a Lua string.

File.WriteAllText("test_tmp.txt", "All works!");
defer File.Delete("test_tmp.txt");

lua.DoString(
    @"""
    outString = StringBuilder()
    System.IO.File.ReadAllText("test_tmp.txt", outString, false)

    string = StringBuilder()
    string:AppendF("Test '{}'", outString)
    
    print(string:str()) -- outputs: Test 'All works!'
    """
);
```

For more examples I encourage you to look at the `LuaTinker.Tests` project.
