using System;
using KeraLua;
using LuaTinker.Wrappers;
using LuaTinker.Helpers;

using internal KeraLua;

namespace LuaTinker.StackHelpers
{
	// PopDispatch works around a limitation in Beef: conditional generic constraints work reliably for types, but not individual methods.
	// Placing Run on a generic type lets us use a conditional type extension to replace its implementation.
	internal struct PopDispatch<T> where T : var
	{
		public static mixin Pop(Lua lua, int32 index, LuaType? knownType)
		{
			StackHelper.Pop<T>(lua, index)
		}
	}

	extension StackHelper
	{
		public static mixin Pop<T>(Lua lua, int32 index)
			where T : var
		{
			// Friend lets this public mixin use the internal dispatch type in the caller's scope.
#unwarn
			([Friend]PopDispatch<T>.Pop!:mixin(lua, index, null))
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
