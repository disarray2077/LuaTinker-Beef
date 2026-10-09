using System;
using KeraLua;
using LuaTinker.Wrappers;
using LuaTinker.Helpers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	// PopDispatch works around a limitation in Beef: conditional generic constraints work reliably for types, but not individual methods.
	// Placing Run on a generic type lets us use a conditional type extension to replace its implementation.
	struct PopDispatch<T> where T : var
	{
		public static mixin Run(Lua lua, int32 index, LuaType? knownType)
		{
			StackHelper.Pop<T>(lua, index)
		}
	}

	extension PopDispatch<T> where T : var where IsInputSpan<T>.Result : Yes
	{
		public new static mixin Run(Lua lua, int32 index, LuaType? knownType)
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

	extension StackHelper
	{
		public static mixin Pop<T>(Lua lua, int32 index)
			where T : var
		{
#unwarn
			PopDispatch<T>.Run!:mixin(lua, index, null)
		}

		public static mixin PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
			where T : Object where Object : T
		{
			_PopAlloc<T>(lua, index, alloc)
		}

		public static mixin Pop<T>(Lua lua, int32 index)
			where T : Object where Object : T
		{
			SingleAllocator alloc = scope:mixin .(88);
			_PopAlloc<T>(lua, index, alloc)
		}

		private static Object _PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
			where T : Object
		{
			if (!EnsureNotArgumentHint(lua, index))
				return default;
			if (lua.IsUserData(index))
			{
				let wrapper = User2Type.GetObject(lua, index) as PointerWrapperBase;
				if (wrapper == null)
					return default;
				switch (wrapper.ToObject(alloc, let obj))
				{
				case .Object, .NewObject:
					return obj;
				case .Error:
					let luaTinker = lua.TinkerState;
					luaTinker.SetLastError($"can't convert argument {index} to 'System.Object'");
					TryThrowError(lua, luaTinker);
					return default;
				}
			}
			else
			{
				switch (lua.Type(index))
				{
				case .Number:
					if (let i = lua.ToIntegerX(index))
						return new:alloc box i;
					else if (let n = lua.ToNumberX(index))
						return new:alloc box n;
					else
					{
						let luaTinker = lua.TinkerState;
						luaTinker.SetLastError($"can't convert argument {index} to 'System.Object'");
						TryThrowError(lua, luaTinker);
						return default;
					}
				case .Boolean:
					return new:alloc box Pop<bool>(lua, index);
				case .String:
					return new:alloc box Pop<StringView>(lua, index);
				case .Table:
					return new:alloc box Pop<LuaTable>(lua, index);
				case .Nil:
					return null;
				default:
					let luaTinker = lua.TinkerState;
					luaTinker.SetLastError($"can't convert argument {index} to 'System.Object'");
					TryThrowError(lua, luaTinker);
					return default;
				}
			}
		}

		public static mixin Pop<T>(Lua lua, int32 index)
			where T : String, class where String : T
		{
			SingleAllocator alloc = scope:mixin .(96);
			_PopAlloc<T>(lua, index, alloc)
		}

		private static String _PopAlloc<T>(Lua lua, int32 index, ITypedAllocator alloc)
			where T : String where String : T
		{
			let valueType = lua.Type(index);
			if (valueType == .UserData)
			{
				let wrapper = User2Type.GetObject(lua, index) as PointerWrapperBase;
				if (wrapper == null)
					return default;
				if (!wrapper.Type.IsValueType && (wrapper.ToObject(alloc, let obj) case .Object))
				{
					if (let str = obj as String)
						return str;
				}
				let luaTinker = lua.TinkerState;
				luaTinker.SetLastError($"can't convert argument {index} to 'String'");
				TryThrowError(lua, luaTinker);
				return default;
			}
			else
			{
				if (let strView = Pop<T>(lua, index))
				{
					let str = new:alloc String();
					// PCall borrows rooted Lua strings; numeric conversion produces an unrooted temporary.
					if (valueType == .String && lua.TinkerState.IsPCall)
						str.Reference(strView);
					else
						str.Append(strView);
					return str;
				}
				else
					return null;
			}
		}
	}
}
