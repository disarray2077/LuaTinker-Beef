using System;
using System.Collections;
using System.Diagnostics;
using KeraLua;

namespace LuaTinker.BasicSample;

static class Program
{
	public static void Main(String[] args)
	{
		let lua = scope Lua(true);
		lua.Encoding = System.Text.Encoding.UTF8;
		let tinker = scope LuaTinker(lua);

		let registeredGlobals = scope List<String>();
		RegisterBindings(tinker, registeredGlobals);

		Console.WriteLine("Beef-Lua REPL (Powered by LuaTinker)");
		Console.WriteLine("Type Lua code, or :help for more information.");
		
		while (true)
		{
			Console.Write("> ");
			String input = scope .();
			if (!(Console.ReadLine(input) case .Ok))
				break;

			if (input.IsEmpty)
				continue;

			if (input.StartsWith(':'))
			{
				if (!HandleCommand(input, registeredGlobals))
					break; // Exit signal
			}
			else
			{
				ExecuteLua(lua, input);
			}
		}
	}

	static void RegisterBindings(LuaTinker tinker, List<String> names)
	{
		names.Add("System.Console (Static Class)");
		tinker.AutoTinkClass<System.Console>();

		names.Add("System.IO.File (Static Class)");
		tinker.AutoTinkClass<System.IO.File>();

		names.Add("String (Class)");
		tinker.AutoTinkClass<System.String>();

		names.Add("StringList (Class)");
		tinker.AutoTinkClass<List<String>, const "StringList">();

		names.Add("Random (Class)");
		tinker.AutoTinkClass<System.Random>();

		names.Add("Stopwatch (Class)");
		tinker.AutoTinkClass<System.Diagnostics.Stopwatch>();
		
		names.Add("FileStream (Class)");
		tinker.AddClass<System.IO.Stream>(); // TODO: AutoTinkClass
		tinker.AutoTinkClass<System.IO.BufferedStream>();
		tinker.AddClassParent<System.IO.BufferedStream, System.IO.Stream>();
		tinker.AutoTinkClass<System.IO.BufferedFileStream>();
		tinker.AddClassParent<System.IO.BufferedFileStream, System.IO.BufferedStream>();
		tinker.AutoTinkClass<System.IO.FileStream>();
		tinker.AddClassParent<System.IO.FileStream, System.IO.BufferedFileStream>();
		
		names.Add("StreamReader (Class)");
		tinker.AutoTinkClass<System.IO.StreamReader>();
	}

	static void ExecuteLua(Lua lua, String code)
	{
		var oldTop = lua.GetTop();
		let expressionCode = scope $"return {code};";

		// Attempt to run as an expression to get a return value.
		if (lua.LoadString(expressionCode) == .OK && lua.PCall(0, -1, 0) == .OK)
		{
			PrintStack(lua);
			lua.SetTop(0);
		}
		else
		{
			let lastError = lua.ToString(-1, .. scope .());
			lua.SetTop(oldTop);

			// Fallback to running as a statement.
			if (lua.DoString(code))
			{
				let error = lua.ToString(-1, .. scope .());
				Console.ForegroundColor = .Red;
				Console.WriteLine($"Error: {error.Contains("syntax error") ? lastError : error}");
				Console.ResetColor();
				lua.Pop(1);
			}
		}
	}

	static bool HandleCommand(String input, List<String> registeredGlobals)
	{
		var parts = input.Split(' ', .RemoveEmptyEntries);
		let command = scope String(parts.GetNext().GetValueOrDefault())..ToLower();

		switch (command)
		{
		case ":quit", ":exit":
			return false;

		case ":clear":
			Console.Clear();
			break;

		case ":help":
			Console.WriteLine("--- REPL Commands ---");
			Console.WriteLine("  :help      - Shows this help message.");
			Console.WriteLine("  :clear     - Clears the console screen.");
			Console.WriteLine("  :quit      - Exits the REPL.");

			Console.WriteLine("\n--- Mini-Tutorial: Using Beef Objects in Lua ---");
			Console.WriteLine("  -- Create an instance of a class by calling it like a function");
			Console.WriteLine("  rand = Random()");
			Console.WriteLine();
			Console.WriteLine("  -- Call instance methods with a colon ':'");
			Console.WriteLine("  print(rand:Next(1, 100))");
			Console.WriteLine();
			Console.WriteLine("  -- Call static methods with a dot '.' using the full namespace");
			Console.WriteLine("  System.Console.WriteLine(\"Hello from a static method!\")");
			Console.WriteLine();
			Console.WriteLine("  -- Access properties like table fields");
			Console.WriteLine("  sw = Stopwatch()");
			Console.WriteLine("  sw:Start()");
			Console.WriteLine("  -- ... do work ...");
			Console.WriteLine("  sw:Stop()");
			Console.WriteLine("  print(\"Elapsed ms: \" .. sw.ElapsedMilliseconds)");

			Console.WriteLine("\n--- Available Beef Globals ---");
			for (let name in registeredGlobals)
				Console.WriteLine($"  - {name}");
			break;

		default:
			Console.ForegroundColor = .Yellow;
			Console.WriteLine($"Unknown command: '{command}'.");
			Console.ResetColor();
			break;
		}
		return true;
	}

	static void PrintStack(Lua lua)
	{
		let top = lua.GetTop();
		if (top == 0)
			return;

		Console.ForegroundColor = .Cyan;
		for (int32 i = 1; i <= top; i++)
		{
			Console.Write(lua.ToString(i, .. scope .()));
			if (i < top) Console.Write("\t"); // Separate multiple return values
		}
		Console.WriteLine();
		Console.ResetColor();
	}
}