using System;

namespace LuaTinker;

class StringBuilder : String
{
	[AllowAppend]
	public this() : base()
	{
	}

	[AllowAppend]
	public this(String str) : base(str)
	{
	}

	[AllowAppend(ZeroGap=true)]
	public this(char8* char8Ptr) : base(char8Ptr)
	{
	}
}