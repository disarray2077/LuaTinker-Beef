using System;
using System.Diagnostics;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.Handlers;
using LuaTinker.Wrappers;

using internal KeraLua;
using internal LuaTinker.StackHelpers;

namespace LuaTinker.StackHelpers
{
	extension PopDispatch<T> where T : var where IsInputSpan<T>.Result : Yes
	{
		public new static mixin Pop(Lua lua, int32 index, LuaType? knownType)
		{
			T result = default;
			let valueType = knownType.HasValue ? knownType.Value : lua.Type(index);
			if (valueType == .UserData)
				result = StackHelper.Pop<T>(lua, index);
			else
			{
				switch (StackHelper.CheckInputSpan<FirstGenericArg<T>>(lua, index, valueType))
				{
				case .Err(let failure):
					// Friend keeps this injected mixin independent of the caller's internal imports.
					let state = lua.[Friend]TinkerState;
					failure.SetError(state);
					StackHelper.TryThrowError(lua, state);
				case .Ok(let count):
					FirstGenericArg<T>[] elements = scope:mixin FirstGenericArg<T>[count](?);
					let tableIndex = lua.AbsIndex(index);
					for (int32 sequenceIndex = 1; sequenceIndex <= count; sequenceIndex++)
					{
						lua.RawGetInteger(tableIndex, sequenceIndex);
						elements[sequenceIndex - 1] = StackHelper.Pop!:mixin<FirstGenericArg<T>>(lua, -1);
						lua.Pop(1);
					}
					if (typeof(FirstGenericArg<T>) == typeof(LuaTable))
					{
						static void DisposeInputSpanTables(Span<LuaTable> tables)
						{
							for (var table in tables)
								table.Dispose();
						}
						defer:mixin DisposeInputSpanTables(Span<LuaTable>((LuaTable*)elements.Ptr, count));
					}
					result = (T)Span<FirstGenericArg<T>>(elements);
				}
			}
			result
		}
	}
}
