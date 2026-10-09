using System;
using KeraLua;
using LuaTinker.Wrappers;

namespace LuaTinker.StackHelpers
{
	extension StackHelper
	{
		[Inline]
		private static bool IsPointerWrapperArgument(PointerWrapperBase wrapper, Type pointerType)
			=> wrapper != null && wrapper.CanPassByRef && pointerType.IsPointer &&
				(pointerType == typeof(void*) || wrapper.Type == pointerType.UnderlyingType);

		[Inline]
		public static bool IsPointerWrapperArgument(Lua lua, int32 index, Type pointerType)
			=> IsPointerWrapperArgument(User2Type.TryGetTypePtr<PointerWrapperBase>(lua, index), pointerType);

		public static bool IsPointerArgument(Lua lua, int32 index, Type pointerType, Span<Type> competingTypes = default)
		{
			if (IsNullPointerArgument(lua, index, pointerType))
				return true;
			let valueType = lua.Type(index);
			if (valueType == .Nil)
				return true;
			if (valueType == .String && pointerType == typeof(char8*))
				return true;
			let wrapper = User2Type.TryGetTypePtr<PointerWrapperBase>(lua, index);
			if (!IsPointerWrapperArgument(wrapper, pointerType))
				return false;
			if (pointerType == typeof(void*))
				for (let type in competingTypes)
					if (type != typeof(void*) && IsPointerWrapperArgument(wrapper, type))
						return false;
			return true;
		}
	}
}
