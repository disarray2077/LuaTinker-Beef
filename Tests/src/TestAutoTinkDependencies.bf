using KeraLua;
using System;
using System.Collections;
using LuaTinker.Helpers;

public enum GlobalAutoChoice { Value = 9 }

namespace LuaTinker.Tests
{
	class TestAutoTinkDependencies
	{
		public enum Choice { One = 1 }
		public enum NestedChoice { Two = 2 }
		public enum ExcludedChoice { Three = 3 }
		public struct NativeHandle;
		public class GenericEnumDependencies
		{
			public Result<void> First;
			public Result<int32> Second;
		}

		[Test]
		public static void TestGenericEnumDependencyNames()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<GenericEnumDependencies>(.Deep);
			if (lua.DoString("assert(type(Result_void) == 'table' and type(Result_int32) == 'table')"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		public static class CollisionA
		{
			public enum Node { Value }
		}

		public static class CollisionB
		{
			public enum Node { Value }
		}

		public struct FirstContainer { public CollisionA.Node Value; }
		public struct SecondContainer { public CollisionB.Node Value; }

		public static class CollisionAPI
		{
			public static FirstContainer First() => default;
			public static SecondContainer Second() => default;
		}

		public static class HandleAPI
		{
			public static bool IsNull(NativeHandle* value) => value == null;
		}

		public struct Leaf
		{
			public int32 Value;
			public this(int32 value) { Value = value; }
		}

		public struct Payload
		{
			public int32 Value;
			public Leaf Child;
			public NestedChoice Choice;
			public this(int32 value) { this = default; Value = value; }
		}

		public class First
		{
			public Second Other;
			public int32 Value;
			public this(int32 value) { Value = value; }
		}

		public class Second
		{
			public First Other;
		}

		public class Surface
		{
			public Leaf Field;
			public Payload Item { get; set; }
			public int32 this[NestedChoice key] => (int32)key;
		}

		public static class WrappedAPI
		{
			public static int32 Read(Span<Payload> values) => values[0].Value;
			public static (Leaf, int32) Create() => (.(42), 7);
			public static function int32(Choice) ReadChoice = (value) => (int32)value;
		}

		public class Grandparent
		{
			public int32 Read() => 42;
		}

		public class Parent : Grandparent
		{
			public First Other;
		}

		public class Derived : Parent
		{
			public this() {}
		}

		public static class API
		{
			public static Payload Echo(Payload value) => value;
			public static int32 ReadChoice(Choice value) => (int32)value;
			public static int32 Pick(Choice value) => 1;
			public static int32 Pick(int32 value) => 2;
			public static int32 ReadGlobalChoice(GlobalAutoChoice value) => (int32)value;
			public static First EchoClass(First value) => value;
			public static int32 Excluded(ExcludedChoice value) => (int32)value;
		}

		public struct Exclusions : IMethodExclusionProvider
		{
			[Comptime]
			public static void CollectExcludedMethods(Type type, HashSet<StringView> excluded)
				=> excluded.Add("Excluded");
		}

		[Test(ShouldFail = true)]
		public static void TestConflictingDependencyNames()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			using (let ns = tinker.BeginNamespace("Bindings"))
				ns.AutoTinkClass<CollisionAPI>(.Deep);
		}

		[Test]
		public static void TestScopedDefaultUntypedEnums()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			using (let ns = tinker.BeginNamespace("Types"))
				ns.AutoTinkClass<API, ?>(.Deep, .IncludeEnums);
			if (lua.DoString("""
				assert(Types.API.ReadChoice(Types.Choice.One) == 1)
				assert(Types.Choice.One == 1 and Choice == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestOpaqueHandleDependency()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<HandleAPI, ?>(.Deep, .IncludeStructs);
			if (lua.DoString("assert(HandleAPI.IsNull(nullptr.void))"))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestDeepDefaultsToIncludeAll()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<API>(.Deep);
			if (lua.DoString("""
				assert(API.ReadChoice(Choice.One) == 1)
				assert(API.Echo(Payload(7)).Value == 7)
				assert(API.EchoClass(First(42)).Value == 42)
				assert(LuaTinker == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestCustomNamespace()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			using (let ns = tinker.BeginNamespace("Game"))
				ns.AutoTinkClass<API, ?>(.Deep, .IncludeAll, name: "Bindings");
			if (lua.DoString("""
				assert(Game.Bindings.ReadChoice(Game.Choice.One) == 1)
				assert(Game.Bindings.ReadGlobalChoice(Game.GlobalAutoChoice.Value) == 9)
				local payload = Game.Payload(7)
				payload.Child = Game.Leaf(42)
				assert(Game.Bindings.Echo(payload).Child.Value == 42)
				assert(Game.LuaTinker == nil and Payload == nil and API == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestShallowDoesNotRegisterDependencies()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<API>(.Shallow);
			if (lua.DoString("""
				assert(API ~= nil)
				assert(Payload == nil and First == nil and Choice == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestTypedEnumDependencies()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<API, ?>(.Deep, .IncludeEnums | .TypedEnums);
			if (lua.DoString("""
				assert(API.Pick(Choice.One) == 1)
				assert(API.ReadGlobalChoice(GlobalAutoChoice.Value) == 9)
				assert(NestedChoice == nil)
				assert(Payload == nil and First == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestDeepRegistersNestedStructDependencies()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<API, ?>(.Deep, .IncludeStructs);
			if (lua.DoString("""
				assert(API.Echo(Payload(7)).Value == 7)
				assert(Leaf(3).Value == 3 and First == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestRecursiveStructDependenciesAndExclusions()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<API, Exclusions, ?>(.Deep, .IncludeStructs | .IncludeEnums);
			if (lua.DoString("""
				assert(Leaf(42).Value == 42)
				assert(NestedChoice.Two == 2)
				assert(ExcludedChoice == nil and API.Excluded == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestRecursiveClassDependenciesWithCycles()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<API, ?>(.Deep, .IncludeClasses);
			if (lua.DoString("""
				assert(API.EchoClass(First(7)).Value == 7)
				assert(Second() ~= nil and Payload == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestFieldPropertyAndIndexerDependencies()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<Surface, ?>(.Deep, .IncludeStructs | .IncludeEnums);
			if (lua.DoString("""
				local surface = Surface()
				surface.Field = Leaf(42)
				surface.Item = Payload(7)
				assert(surface.Field.Value == 42 and surface.Item.Value == 7)
				assert(surface[2] == 2 and NestedChoice.Two ~= nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestWrappedDependencies()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<WrappedAPI, ?>(.Deep, .IncludeStructs | .IncludeEnums);
			if (lua.DoString("""
				assert(WrappedAPI.Read({Payload(7)}) == 7)
				assert(WrappedAPI.ReadChoice(Choice.One) == 1)
				local leaf = WrappedAPI.Create()
				assert(leaf.Value == 42)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestShallowRegistersParentHierarchy()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			using (let ns = tinker.BeginNamespace("Types"))
				ns.AutoTinkClass<Derived>(.Shallow, name: "NamedDerived");
			if (lua.DoString("""
				assert(Types.NamedDerived():Read() == 42)
				assert(Types.First == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestDeepRegistersParentHierarchyWithoutIncludeClasses()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<Derived, ?>(.Deep, .IncludeEnums, name: "NamedDerived");
			if (lua.DoString("""
				assert(NamedDerived():Read() == 42)
				assert(First == nil)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}

		[Test]
		public static void TestExistingDependencyRegistration()
		{
			let lua = scope Lua(true);
			let tinker = scope LuaTinker(lua);
			tinker.AutoTinkClass<Payload>(.Shallow, name: "ExistingPayload");
			tinker.AutoTinkClass<API, ?>(.Deep, .IncludeStructs);
			if (lua.DoString("""
				assert(API.Echo(ExistingPayload(7)).Value == 7)
				assert(Payload == nil)
				assert(Leaf(42).Value == 42)
				"""))
				Test.FatalError(lua.ToString(-1, .. scope .()));
		}
	}
}
