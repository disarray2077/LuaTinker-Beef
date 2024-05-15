using System;
using KeraLua;

namespace LuaTinker.Sample;

static class Program
{
	struct X
	{
		int a;
	}

	public static void Main(String[] args)
	{
		let lua = scope Lua(true);
		lua.Encoding = System.Text.Encoding.UTF8;

		LuaTinker tinker = scope .(lua);
		tinker.AutoTinkClass<System.String>();
		tinker.AutoTinkClass<System.Collections.List<String>, const "List">();
		tinker.AutoTinkClass<System.Console>();
		//tinker.AutoTinkClass<Lua>();

		//tinker.AddClass<LuaTinker>();
		//tinker.AddClassMethod<LuaTinker, function void(LuaTinker this, String, function void())>("AddMethod", => LuaTinker.AddMethod<function void()>);
		//tinker.SetValue("tinker", tinker);

		tinker.SetValue("tinker", ref tinker);
		tinker.AddNamespaceMethod<delegate LuaTinker()>("System", "Hi", new () => tinker);

		tinker.AddMethod<function X?(Object)>("test", (test) => null);

		if (lua.DoString(
			@"""
			print(tinker)
			print(System.Hi())

			str = String()
			print(test(str))
			str:Append("1")
			str:Append("2", "2.1")
			str:Append("3")
			System.Console.WriteLine("Output: {}", str)

			list = List()
			list:Add(str)
			print(str)
			s = list:PopBack()
			print(s)
			
			"""
			))
		{
			Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		Console.Read();
	}
}