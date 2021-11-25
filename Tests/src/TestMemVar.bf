using System;
using KeraLua;

namespace LuaTinker.Tests
{
	static class TestMemVar
	{
		public struct Vector2 : this(int x, int y);

		public struct Actor
		{
			private Vector2 mPos;

			public ref Actor Instance() mut => ref this;
	
			public void SetPosition(Vector2 vec) mut
			{
				mPos = vec;
			}
	
			public ref Vector2 GetPosition() mut
			{
				return ref mPos;
			}
		}

		private static Vector2 mVec;

		[Test]
		public static void Test()
		{
			let lua = scope Lua(true);
			lua.Encoding = System.Text.Encoding.UTF8;

			LuaTinker tinker = scope .(lua);
			tinker.AddClass<Vector2>("Vector2");
			tinker.AddClassCtor<Vector2, (int, int)>();
			tinker.AddClassVar<Vector2, int>("x", offsetof(Vector2, x));
			tinker.AddClassVar<Vector2, int>("y", offsetof(Vector2, y));

			tinker.AddMethod("Vec", (function ref Vector2())
				() => { return ref mVec; });
			
			tinker.AddClass<Actor>("Actor");
			tinker.AddClassCtor<Actor>();
			tinker.AddClassMethod<Actor, function ref Vector2(mut Actor this)>("getPos", => Actor.GetPosition);
			tinker.AddClassMethod<Actor, function void(mut Actor this, Vector2)>("setPos", => Actor.SetPosition);

			if (lua.DoString(
				@"""
				actor = Actor()
				assert(actor:getPos().x == 0)
				assert(actor:getPos().y == 0)
				actor:setPos(Vector2(123, 321))
				assert(actor:getPos().x == 123)
				assert(actor:getPos().y == 321)

				assert(Vec().x == 0)
				assert(Vec().y == 0)
				Vec().x = 10
				Vec().y = 15
				assert(Vec().x == 10)
				assert(Vec().y == 15)
				"""
				))
			{
				Test.FatalError(lua.ToString(-1, .. scope .()));
			}

			var luaActor = tinker.GetValue<Actor>("actor").Get();
			Test.Assert(luaActor.GetPosition().x == 123);
			Test.Assert(luaActor.GetPosition().y == 321);

			Test.Assert(mVec.x == 10);
			Test.Assert(mVec.y == 15);
		}
	}
}
