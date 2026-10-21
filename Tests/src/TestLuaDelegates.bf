using System;
using KeraLua;
using LuaTinker.StackHelpers;

using internal KeraLua;

namespace LuaTinker.Tests;

class TestLuaDelegates
{
	public static class Target
	{
		public static int32 Apply(delegate int32(int32) callback, int32 value) => callback(value);
		public static int32 Pair(delegate int32(int32) first, delegate int32(int32) second) => first(2) + second(3);
	}

	class EventSource
	{
		private Event<delegate int32(int32)> mHandlers ~ _.Dispose();
		public ref Event<delegate int32(int32)> Handlers => ref mHandlers;

		public void Add(delegate int32(int32) handler) => mHandlers.Add(handler);
		public int32 Fire(int32 value) => mHandlers.Invoke(value);
		public void Clear() => mHandlers.Dispose();
	}

	class StackOnlyAllocator : SingleAllocator
	{
		[AllowAppend]
		public this(int size) : base(size) {}
		protected override void* AllocLarge(int size, int align)
		{
			Test.FatalError("Delegate conversion exceeded caller-owned storage");
			return null;
		}
	}

	[Test]
	public static void TestArgumentsAndNestedCallbacks()
	{
		let lua = scope Lua(true);
		let tinker = scope LuaTinker(lua);
		tinker.RegisterDelegate<delegate int32(int32)>();
		tinker.AddMethod<function int32(delegate int32(int32), int32)>("Apply", (callback, value) => callback(value));
		if (lua.DoString("""
			assert(Apply(function(value) return value + 2 end, 5) == 7)
			assert(Apply(function(value)
			    local inner = Apply(function(other) return other * 2 end, value)
			    return inner + 1
			end, 3) == 7)
			assert(Apply(function(value)
			    assert(not pcall(function() Apply(function() return false end, value) end))
			    return value + 1
			end, 3) == 4)
			assert(not pcall(function() Apply(false, 1) end))
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
	}

	[Test]
	public static void TestSignatureShapes()
	{
		let lua = scope Lua(true);
		let tinker = scope LuaTinker(lua);
		tinker.RegisterDelegate<delegate void()>();
		tinker.RegisterDelegate<delegate (int32, bool)(String, int32)>();
		tinker.AddMethod<function void(delegate void())>("Notify", (callback) => callback());
		tinker.AddMethod<function (int32, bool)(delegate (int32, bool)(String, int32))>("Read", (callback) => callback("name", 3));
		if (lua.DoString("""
			local called = false
			Notify(function() called = true end)
			assert(called)
			local number, flag = Read(function(name, value)
			    assert(name == 'name')
			    return value + 4, true
			end)
			assert(number == 7 and flag)
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
	}

	[Test]
	public static void TestRegistrationAndReflectedDispatch()
	{
		let lua = scope Lua(true);
		let tinker = scope LuaTinker(lua);
		tinker.AutoTinkClass<Target>(.Shallow);
		if (lua.DoString("""
			api = Target
			assert(not pcall(function() api.Apply(function(value) return value end, 1) end))
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
		tinker.RegisterDelegate<delegate int32(int32)>();
		delegate int32(int32) borrowed = scope (value) => value + 5;
		tinker.SetValue("borrowed", borrowed);
		if (lua.DoString("""
			assert(api.Apply(function(value) return value + 1 end, 2) == 3)
			assert(api.Apply(borrowed, 2) == 7)
			assert(api.Pair(function(value) return value * 2 end,
			    function(value) return value + 3 end) == 10)
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));

		let otherLua = scope Lua(true);
		let otherTinker = scope LuaTinker(otherLua);
		otherTinker.AddMethod<function int32(delegate int32(int32), int32)>("Apply", (callback, value) => callback(value));
		if (otherLua.DoString("assert(not pcall(function() Apply(function(value) return value end, 1) end))"))
			Test.FatalError(otherLua.ToString(-1, .. scope .()));
	}

	[Test]
	public static void TestCallbackErrorsAndLifetime()
	{
		let lua = scope Lua(true);
		let tinker = scope LuaTinker(lua);
		tinker.RegisterDelegate<delegate int32(int32)>();
		tinker.AddMethod<function int32(delegate int32(int32), int32)>("Apply", (callback, value) => callback(value));
		if (lua.DoString("""
			local weak = setmetatable({}, {__mode = 'v'})
			local function run(mode)
			    local payload = {}
			    weak[1] = payload
			    local function callback(value)
			        local keepAlive = payload
			        if mode == 'error' then error('callback failed') end
			        if mode == 'empty' then error('') end
			        if mode == 'object' then error({}) end
			        if mode == 'invalid' then return false end
			        return value + 1
			    end
			    if mode == 'valid' then
			        assert(Apply(callback, 2) == 3)
			    else
			        assert(not pcall(function() Apply(callback, 2) end))
			    end
			end
			for _, mode in ipairs({'valid', 'error', 'empty', 'object', 'invalid'}) do
			    run(mode)
			    collectgarbage('collect')
			    assert(weak[1] == nil)
			end
			assert(Apply(function(value) return value end, 4) == 4)
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
		Test.Assert(lua.GetTop() == 0);
	}

	[Test]
	public static void TestPopAllocAndHostErrors()
	{
		let lua = scope Lua(true);
		let tinker = scope LuaTinker(lua);
		tinker.RegisterDelegate<delegate int32(int32)>();
		tinker.AddMethod<function int32(delegate int32(int32), int32)>("Apply", (callback, value) => callback(value));
		if (lua.DoString("return function(value) if value == 2 then return Apply(stored, 3) end return value + 1 end"))
			Test.FatalError(lua.ToString(-1, .. scope .()));
		{
			let allocator = scope StackOnlyAllocator(StackHelper.GetDelegateAllocationSize<delegate int32(int32)>(lua));
			let callback = StackHelper.PopAlloc!<delegate int32(int32)>(lua, -1, allocator);
			tinker.SetValue("stored", callback);
			Test.Assert(callback(2) == 4);
			Test.Assert(lua.GetTop() == 1);
			lua.PushNil();
			lua.SetGlobal("stored");
		}
		lua.Pop(1);
		delegate int32(ref int32) borrowed = scope (value) => ++value;
		StackHelper.Push(lua, borrowed);
		let restored = StackHelper.Pop!<delegate int32(ref int32)>(lua, -1);
		int32 value = 2;
		Test.Assert(restored(ref value) == 3);
		lua.Pop(1);
		if (lua.DoString("fail = true; return function(value) if fail then return false else return value + 1 end end"))
			Test.FatalError(lua.ToString(-1, .. scope .()));
		{
			let callback = StackHelper.Pop!<delegate int32(int32)>(lua, -1);
			callback(2);
			Test.Assert(lua.TinkerState.HasError);
			Test.Assert(lua.GetTop() == 1);
			lua.PushBoolean(false);
			lua.SetGlobal("fail");
			Test.Assert(callback(2) == 3);
			Test.Assert(!lua.TinkerState.HasError);
		}
		lua.Pop(1);
	}

	[Test]
	public static void TestRefEventSubscription()
	{
		let lua = scope Lua(true);
		let tinker = scope LuaTinker(lua);
		let source = scope EventSource();
		tinker.RegisterDelegate<delegate int32(int32)>(.Persistent);
		tinker.AutoTinkClass<EventSource>(.Shallow);
		tinker.AutoTinkClass<Event<delegate int32(int32)>>(.Shallow, name: "Handlers");
		tinker.SetValue("source", source);
		if (lua.DoString("""
			source.Handlers:Add(function(value) return value + 4 end)
			assert(source:Fire(3) == 7)
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
	}

	[Test]
	public static void TestPersistentEventCallbacks()
	{
		let lua = scope Lua(true);
		let tinker = scope LuaTinker(lua);
		let source = scope EventSource();
		tinker.RegisterDelegate<delegate int32(int32)>(.Persistent);
		tinker.AutoTinkClass<EventSource>(.Shallow);
		tinker.SetValue("source", source);
		if (lua.DoString("""
			weak = setmetatable({}, {__mode = 'v'})
			local payload = {offset = 5}
			weak[1] = payload
			source:Add(function(value) return value + payload.offset end)
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
		if (lua.DoString("collectgarbage('collect'); assert(weak[1] ~= nil)"))
			Test.FatalError(lua.ToString(-1, .. scope .()));
		Test.Assert(source.Fire(7) == 12);
		source.Clear();
		if (lua.DoString("collectgarbage('collect'); assert(weak[1] == nil)"))
			Test.FatalError(lua.ToString(-1, .. scope .()));
	}

	[Test]
	public static void TestPersistentCallbackRecovery()
	{
		let lua = scope Lua(true);
		let tinker = scope LuaTinker(lua);
		let source = scope EventSource();
		tinker.RegisterDelegate<delegate int32(int32)>(.Persistent);
		tinker.AutoTinkClass<EventSource>(.Shallow);
		tinker.SetValue("source", source);
		if (lua.DoString("""
			local fail = true
			source:Add(function(value)
			    if fail then
			        fail = false
			        error('callback failed', 0)
			    end
			    return value + 1
			end)
			source:Fire(2)
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
		Test.Assert(lua.TinkerState.HasError);
		Test.Assert(source.Fire(2) == 3);
		Test.Assert(!lua.TinkerState.HasError);
	}

	[Test]
	public static void TestPersistentCallbackSelfRemoval()
	{
		let lua = scope Lua(true);
		let tinker = scope LuaTinker(lua);
		let source = scope EventSource();
		tinker.RegisterDelegate<delegate int32(int32)>(.Persistent);
		tinker.AutoTinkClass<EventSource>(.Shallow);
		tinker.SetValue("source", source);
		if (lua.DoString("""
			source:Add(function(value)
			    source:Clear()
			    return value + 1
			end)
			assert(source:Fire(2) == 3)
			"""))
			Test.FatalError(lua.ToString(-1, .. scope .()));
	}
}
