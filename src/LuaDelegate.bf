using System;
using System.Reflection;
using KeraLua;
using LuaTinker.Helpers;
using LuaTinker.StackHelpers;

using internal KeraLua;
using internal LuaTinker;

namespace LuaTinker;

public enum DelegateLifetime
{
	/// Call-scoped delegates are released after the operation they were used for ends.
	CallScoped,

	/// Persistent delegates are owned by the receiving Beef code and must be deleted before Lua closes.
	/// If a persistent callback fails, its error is left in LuaTinkerState, and a default value is returned to Beef.
	Persistent
}

internal class LuaDelegateAdapter
{
	protected Lua mLua;
	private int32 mFunctionRef;
	private int mReferenceCount;

	public this(Lua lua, int32 index, bool persistent = false)
	{
		mLua = persistent ? lua.MainThread : lua;
		mReferenceCount = persistent ? 1 : 0;
		lua.PushValue(index);
		mFunctionRef = lua.Ref(LuaRegistry.Index);
	}

	public ~this()
	{
		Release();
	}

	internal void ReleaseReference()
	{
		if (--mReferenceCount == 0)
			delete this;
	}

	private void Release()
	{
		if (mFunctionRef >= 0)
		{
			mLua.Unref(LuaRegistry.Index, mFunctionRef);
			mFunctionRef = -1;
		}
	}

	[Comptime]
	private static int EmitArguments<Args>() where Args : var
	{
		let code = scope String();
		let type = typeof(Args);
		int count = 0;
		if (type.IsTuple)
		{
			for (let field in type.GetFields(.DeclaredOnly))
			{
				code.AppendF($"StackHelper.Push(mLua, args.{field.Name});\n");
				count++;
			}
		}
		else if (type != typeof(void))
		{
			code.Append("StackHelper.Push(mLua, args);\n");
			count = 1;
		}
		Compiler.MixinRoot(code);
		return count;
	}

	[Comptime]
	private static void EmitResult<R>() where R : var
	{
		let code = scope String();
		let type = typeof(R);
		if (type.IsTuple)
		{
			for (let field in type.GetFields(.DeclaredOnly))
				code.AppendF($"result.{field.Name} = StackHelper.Pop<comptype({field.FieldType.GetTypeId()})>(mLua, {@field.Index - type.FieldCount});\n");
		}
		else if (type != typeof(void))
			code.Append("result = StackHelper.Pop<R>(mLua, -1);\n");
		Compiler.MixinRoot(code);
	}

	internal R Call<R, Args>(Args args) where R : var where Args : var
	{
		R result = default;
		let lua = mLua;
		let persistent = mReferenceCount > 0;
		// An event handler may remove and delete itself while its Lua function is running.
		if (persistent)
			mReferenceCount++;
		let state = mLua.TinkerState;
		{
			let top = mLua.GetTop();
			defer mLua.SetTop(top);
			mLua.RawGetInteger(LuaRegistry.Index, mFunctionRef);
			let argumentCount = EmitArguments<Args>();
			let resultCount = GetResultCount<R>();
			if (mLua.PCall((.)argumentCount, resultCount, 0) != .OK)
			{
				let message = mLua.ToStringView(-1);
				state.SetLastError(message.IsEmpty ? "error in Lua callback" : message);
			}
			else
			{
				// A callback may have caught a binding error; successful execution supersedes that recorded error.
				state.ClearError();
				// Decode after the protected call without jumping past stack restoration on conversion errors.
				let wasProtected = state.IsPCall;
				state.IsPCall = false;
				defer { state.IsPCall = wasProtected; }
				EmitResult<R>();
			}
		}
		if (persistent)
			ReleaseReference();
		else if (state.HasError)
		{
			if (state.IsPCall)
				Release();
			StackHelper.TryThrowError(lua, state);
		}
		return result;
	}

	[Comptime]
	private static int32 GetResultCount<R>() where R : var
		=> typeof(R) == typeof(void) ? 0 : typeof(R).IsTuple ? typeof(R).FieldCount : 1;
}

internal sealed class LuaDelegateAdapter<D> : LuaDelegateAdapter where D : Delegate
{
	public const int StorageSize = typeof(Self).InstanceSize + (Compiler.Options.AllocStackCount + 2) * sizeof(int) + typeof(Self).InstanceAlign - 1;

	private append DelegateHolder<D> mDelegate;

	public this(Lua lua, int32 index) : base(lua, index)
	{
		mDelegate.Bind<Self, const "Invoke">(this);
	}
	
	[Comptime]
	public static void ValidateSignature()
	{
		if (typeof(D).IsGenericParam)
			return;
		let invoke = typeof(D).GetMethod("Invoke").Get();
		if (invoke.ReturnType is RefType || GetSpanElement(invoke.ReturnType) != null)
			Runtime.FatalError("Lua delegate callbacks cannot return references or caller-scoped spans");
		for (int i < invoke.ParamCount)
			if (invoke.GetParamType(i) is RefType)
				Runtime.FatalError("Lua delegate callbacks cannot use ref/out parameters");
	}

	[OnCompile(.TypeInit), Comptime]
	static void Init()
	{
		if (typeof(D).IsGenericParam)
			return;
		let invoke = typeof(D).GetMethod("Invoke").Get();
		let declaration = scope String();
		let arguments = scope String();
		let types = scope String();
		for (int i < invoke.ParamCount)
		{
			let type = invoke.GetParamType(i);
			if (i > 0)
			{
				declaration.Append(", ");
				arguments.Append(", ");
				types.Append(", ");
			}
			declaration.AppendF($"comptype({type.GetTypeId()}) arg{i}");
			arguments.AppendF($"arg{i}");
			types.AppendF($"comptype({type.GetTypeId()})");
		}
		let argumentType = invoke.ParamCount == 0 ? "void" : invoke.ParamCount == 1 ? types : scope $"({types})";
		let argumentValue = invoke.ParamCount == 0 ? "default" : invoke.ParamCount == 1 ? arguments : scope $"({arguments})";
		let resultType = scope $"comptype({invoke.ReturnType.GetTypeId()})";
		Compiler.EmitTypeBody(typeof(Self), scope $"""
			public {resultType} Invoke({declaration})
			{{
				{(invoke.ReturnType == typeof(void) ? "" : "return ")}Call<{resultType}, {argumentType}>({argumentValue});
			}}
			""");
	}

	public static Object CreatePersistent(Lua lua, int32 index, ITypedAllocator allocator)
	{
		Object result = null;
		[Comptime]
		static void EmitFactory()
		{
			if (typeof(D).IsGenericParam)
				return;
			let invoke = typeof(D).GetMethod("Invoke").Get();
			let arguments = scope String();
			let types = scope String();
			for (int i < invoke.ParamCount)
			{
				if (i > 0)
				{
					arguments.Append(", ");
					types.Append(", ");
				}
				arguments.AppendF($"arg{i}");
				types.AppendF($"comptype({invoke.GetParamType(i).GetTypeId()})");
			}
			let argumentType = invoke.ParamCount == 0 ? "void" : invoke.ParamCount == 1 ? types : scope $"({types})";
			let argumentValue = invoke.ParamCount == 0 ? "default" : invoke.ParamCount == 1 ? arguments : scope $"({arguments})";
			Compiler.MixinRoot(scope $"""
				let adapter = new LuaDelegateAdapter(lua, index, true);
				comptype({typeof(D).GetTypeId()}) callback = new [=adapter] ({arguments}) =>
				{{
					{(invoke.ReturnType == typeof(void) ? "" : "return ")}adapter.Call<comptype({invoke.ReturnType.GetTypeId()}), {argumentType}>({argumentValue});
				}}
				~
				{{
					adapter.ReleaseReference();
				}};
				result = callback;
				""");
		}
		EmitFactory();
		return result;
	}

	public static Object Create(Lua lua, int32 index, ITypedAllocator allocator)
	{
		let adapter = new:allocator Self(lua, index);
		return adapter.mDelegate.Callback;
	}
}
