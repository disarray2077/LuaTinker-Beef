using System;
using KeraLua;
using System.Diagnostics;
using LuaTinker.Wrappers;

namespace LuaTinker.StackHelpers
{
	public static class StackHelper
	{
		[Error("Base method called.")]
		public static void Push<T>(Lua lua, T val)
		{
			Runtime.NotImplemented();
		}

		[Error("Base method called.")]
		public static T Pop<T>(Lua lua, int32 index)
		{
			Runtime.NotImplemented();
		}

		public static void EnumStack(Lua lua, String outString)
		{
			int32 top = lua.GetTop();
			outString.AppendF("Type: {}\n", top);
			for (int32 i = 1; i <= lua.GetTop(); i++)
			{
				let type = lua.Type(i);
				switch(type)
				{
				case .Boolean:
					outString.AppendF("\t{}    {}\n", lua.TypeName(type), lua.ToBoolean(i) ? "true" : "false");

				case .LightUserData, .UserData:
					outString.AppendF("\t{}    {:X8}\n", lua.TypeName(type), lua.ToPointer(i));

				case .Number:
					outString.AppendF("\t{}    {}\n", lua.TypeName(type), lua.ToNumber(i));

				case .String:
					outString.AppendF("\t{}    {}\n", lua.TypeName(type), lua.ToString(i, .. scope .()));

				case .Table:
					{
						lua.PushString("__name");
						if (lua.RawGet(i) == .String)
						{
							String name = scope .();
							lua.ToString(-1, name);
							lua.Remove(-1);
							outString.AppendF("\t{}    {:X8} [{}]\n",
								lua.TypeName(type),
								lua.ToPointer(i),
								name);
						}
						else
						{
							lua.Remove(-1);
							outString.AppendF("\t{}    {:X8} \n",
								lua.TypeName(type),
								lua.ToPointer(i));
						}
					}

				case .Function:
					outString.AppendF("\t{}    {:X8}\n", lua.TypeName(type), lua.ToPointer(i));

				default:
					outString.AppendF("\t{}\n", lua.TypeName(type));
				}
			}
		}

		public static void DumpTable(Lua lua, int32 tableIndex, String outString, int32 depth = 0)
		{
		    if (depth > 32) // Prevent infinite recursion
		    {
		        outString.Append("...\n");
		        return;
		    }

		    String indent = scope .();
		    for (int32 i = 0; i < depth; i++)
		        indent.Append("  ");

		    // Ensure tableIndex is absolute
			var tableIndex;
		    if (tableIndex < 0)
		        tableIndex = lua.GetTop() + tableIndex + 1;

		    if (lua.Type(tableIndex) != .Table)
		    {
		        outString.AppendF("{}Not a table\n", indent);
		        return;
		    }

		    lua.PushNil(); // First key
		    while (lua.Next(tableIndex))
		    {
		        // Key is at -2, value at -1
		        outString.Append(indent);
		        
		        // Print key
		        switch (lua.Type(-2))
		        {
		        case .String:
		            outString.AppendF("[\"{}\"]: ", lua.ToString(-2, .. scope .()));
		        case .Number:
		            outString.AppendF("[{}]: ", lua.ToNumber(-2));
		        default:
		            outString.AppendF("[{}]: ", lua.TypeName(lua.Type(-2)));
		        }

		        // Print value
		        switch (lua.Type(-1))
		        {
		        case .Boolean:
		            outString.AppendF("{}\n", lua.ToBoolean(-1) ? "true" : "false");

		        case .LightUserData, .UserData:
		            outString.AppendF("{:X8}\n", lua.ToPointer(-1));

		        case .Number:
		            outString.AppendF("{}\n", lua.ToNumber(-1));

		        case .String:
		            outString.AppendF("\"{}\"\n", lua.ToString(-1, .. scope .()));

		        case .Table:
		            {
		                lua.PushString("__name");
		                if (lua.RawGet(-2) == .String)
		                {
		                    String name = scope .();
		                    lua.ToString(-1, name);
		                    lua.Pop(1);
		                    outString.AppendF("{:X8} [{}]\n", lua.ToPointer(-1), name);
		                }
		                else
		                {
		                    lua.Pop(1);
		                    outString.AppendF("Table {:X8}:\n", lua.ToPointer(-1));
		                    DumpTable(lua, -1, outString, depth + 1);
		                }
		            }

		        case .Function:
		            outString.AppendF("Function {:X8}\n", lua.ToPointer(-1));

		        default:
		            outString.AppendF("{}\n", lua.TypeName(lua.Type(-1)));
		        }

		        lua.Pop(1); // Remove value, keep key for next iteration
		    }
		}

		private static void GetBestLuaClassName<T>(LuaTinkerState tinkerState, String outString)
		{
			if (tinkerState.IsClassRegistered<T>())
			{
				outString.Append(tinkerState.GetClassName<T>());
				outString.Append(" (");
				typeof(T).GetFullName(outString);
				outString.Append(")");
			}
			else
			{
				typeof(T).GetFullName(outString);
			}
		}

		public enum EVTResult
		{
			Ok,
			OkNeedsConversion
		}

		public static bool CheckMetaTableValidity<T>(Lua lua, int32 index)
		{
			let tinkerState = LuaTinkerState.Find(lua);
			if (lua.GetMetaTable(index))
			{
				var validArgument = tinkerState != null && tinkerState.IsClassRegistered<T>();

				if (!validArgument)
				{
					lua.PushString("__name");
					validArgument = lua.RawGet(-2) != .String;
				}
				else if (validArgument)
				{
					lua.GetGlobal(tinkerState.GetClassName<T>());
					validArgument = lua.RawEqual(-1, -2);
				}

				lua.Pop(2);

				return validArgument;
			}

			return !tinkerState.IsClassRegistered<T>();
		}

		public enum EVMTResult
		{
			Ok,
			OkNoMetaTable,
			OkIsBase
		}

		public static EVMTResult EnsureValidMetaTable<T>(Lua lua, int32 index)
		{
			EVMTResult result = .Ok;
			let tinkerState = LuaTinkerState.Find(lua);

			if (lua.GetMetaTable(index))
			{
				var validArgument = tinkerState != null && tinkerState.IsClassRegistered<T>();

				if (!validArgument)
				{
					lua.PushString("__name");
					validArgument = lua.RawGet(-2) != .String;
				}
				else if (validArgument)
				{
					lua.GetGlobal(tinkerState.GetClassName<T>());
					validArgument = lua.RawEqual(-1, -2);

					if (!validArgument)
					{
						lua.PushValue(-2);

						int32 inheritanceDepth = 0;

						while (!validArgument)
						{
							lua.PushString("__parent");
							let parentType = lua.RawGet(-2);
							inheritanceDepth += 1;

							if (parentType == .Table)
							{
								lua.GetGlobal(tinkerState.GetClassName<T>());
								validArgument = lua.RawEqual(-1, -2);
								lua.Pop(1);
							}
							else if (parentType == .Nil)
								break;
						}

						lua.Pop(1 + inheritanceDepth);

						if (validArgument)
							result = .OkIsBase;
					}
				}

				if (!validArgument)
				{
					// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
					{
						// This scope is just to make sure that the string is freed before calling lua.Error
						lua.PushString($"can't convert argument {index} to '{GetBestLuaClassName<T>(tinkerState, .. scope .())}'");
					}
					lua.Error();
				}

				lua.Pop(2);
			}
			else if (tinkerState.IsClassRegistered<T>())
			{
				// TODO: Defer the error handling to the original caller (Example: CallLayer or GetValue)
				{
					// This scope is just to make sure that the string is freed before calling lua.Error
					lua.PushString($"can't convert argument {index} to '{GetBestLuaClassName<T>(tinkerState, .. scope .())}'");
				}
				lua.Error();
			}
			else
			{
				return .OkNoMetaTable;
			}

			return result;
		}
	}
}
