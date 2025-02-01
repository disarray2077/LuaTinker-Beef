#if BF_DELETE_SENTINEL
namespace System
{
	extension Object
	{
		Object mDeleteSentinel ~ { if (Compiler.IsComptime) return; if (this == null) Runtime.FatalError(); Internal.Dbg_MarkObjectDeleted(_ = new .()); }
	}
}
#endif