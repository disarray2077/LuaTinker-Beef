using System;

namespace LuaTinker.Helpers
{
	// Renders source only; callers supply complete statements, never unmatched control-flow syntax.
	class CodeWriter
	{
		private String mOutput;
		private int mDepth;
		private bool mAtLineStart = true;
		private int mNextChainId;
		private int mPendingElse;

		public this(String output)
		{
			mOutput = output;
		}

		[Inline]
		private void InvalidateElse()
		{
			mPendingElse = 0;
		}

		private void Indent()
		{
			if (!mAtLineStart)
				return;
			for (int i = 0; i < mDepth; i++)
				mOutput.Append("\t");
			mAtLineStart = false;
		}

		// Verbatim text (including any newlines); unlike Fragment, no indentation is inserted.
		public void Raw(StringView text)
		{
			InvalidateElse();
			mOutput.Append(text);
			if (!text.IsEmpty)
				mAtLineStart = text[text.Length - 1] == '\n';
		}

		public void Fragment(StringView text)
		{
			InvalidateElse();
			if (text.IsEmpty)
				return;
			Indent();
			mOutput.Append(text);
			mAtLineStart = text[text.Length - 1] == '\n';
		}

		public void Line(StringView text = "")
		{
			InvalidateElse();
			if (text.IndexOf('\n') == -1)
			{
				if (!text.IsEmpty)
					Fragment(text);
				mOutput.Append("\n");
				mAtLineStart = true;
				return;
			}
			int start = 0;
			for (int i = 0; i < text.Length; i++)
			{
				if (text[i] != '\n')
					continue;
				if (i > start)
				{
					Indent();
					mOutput.Append(text.Substring(start, i - start));
				}
				mOutput.Append("\n");
				mAtLineStart = true;
				start = i + 1;
			}
			if (start < text.Length)
			{
				Indent();
				mOutput.Append(text.Substring(start));
				mOutput.Append("\n");
				mAtLineStart = true;
			}
		}

		private void OpenBlock(StringView header)
		{
			if (!mAtLineStart)
				Runtime.FatalError("Cannot open a block inside a source line");
			Line(header);
			Line("{");
			mDepth++;
		}

		private void CloseBlock()
		{
			if (!mAtLineStart || mDepth == 0)
				Runtime.FatalError("Unbalanced generated source block");
			mDepth--;
			Line("}");
		}

		private void EmitBlock(StringView header, delegate void(CodeWriter) body)
		{
			OpenBlock(header);
			body(this);
			CloseBlock();
		}

		private void EmitBlock(StringView header, StringView body)
		{
			OpenBlock(header);
			if (!body.IsEmpty)
				Line(body);
			CloseBlock();
		}

		public void Block(StringView header, delegate void(CodeWriter) body)
		{
			InvalidateElse();
			EmitBlock(header, body);
		}

		public void Block(StringView header, StringView body)
		{
			InvalidateElse();
			EmitBlock(header, body);
		}

		// Writer-owned one-statement loop for source that intentionally omits braces.
		public void ForStatement(StringView header, StringView statement)
		{
			InvalidateElse();
			if (!mAtLineStart)
				Runtime.FatalError("Cannot open a loop inside a source line");
			Line(header);
			mDepth++;
			Line(statement);
			mDepth--;
		}

		// The returned chain only permits a branch immediately after this conditional.
		public ConditionalChain If(StringView condition, delegate void(CodeWriter) body)
		{
			InvalidateElse();
			EmitBlock(scope $"if ({condition})", body);
			let id = ++mNextChainId;
			mPendingElse = id;
			return .(this, id);
		}

		public ConditionalChain If(StringView condition, StringView body)
		{
			InvalidateElse();
			EmitBlock(scope $"if ({condition})", body);
			let id = ++mNextChainId;
			mPendingElse = id;
			return .(this, id);
		}

		private void CheckElse(int id)
		{
			if (id == 0 || mPendingElse != id || !mAtLineStart)
				Runtime.FatalError("Else must immediately follow its own if branch");
			mPendingElse = 0;
		}

		private ConditionalChain EmitElseIf(int id, StringView condition, delegate void(CodeWriter) body)
		{
			CheckElse(id);
			EmitBlock(scope $"else if ({condition})", body);
			mPendingElse = id;
			return .(this, id);
		}

		private ConditionalChain EmitElseIf(int id, StringView condition, StringView body)
		{
			CheckElse(id);
			EmitBlock(scope $"else if ({condition})", body);
			mPendingElse = id;
			return .(this, id);
		}

		private void EmitElse(int id, delegate void(CodeWriter) body)
		{
			CheckElse(id);
			EmitBlock("else", body);
		}

		private void EmitElse(int id, StringView body)
		{
			CheckElse(id);
			EmitBlock("else", body);
		}

		public struct ConditionalChain
		{
			private CodeWriter mWriter;
			private int mId;

			public this(CodeWriter writer, int id)
			{
				mWriter = writer;
				mId = id;
			}

			[Inline]
			public ConditionalChain ElseIf(StringView condition, delegate void(CodeWriter) body)
			{
				return mWriter.EmitElseIf(mId, condition, body);
			}

			[Inline]
			public ConditionalChain ElseIf(StringView condition, StringView body)
			{
				return mWriter.EmitElseIf(mId, condition, body);
			}

			[Inline]
			public void Else(delegate void(CodeWriter) body)
			{
				mWriter.EmitElse(mId, body);
			}

			[Inline]
			public void Else(StringView body)
			{
				mWriter.EmitElse(mId, body);
			}
		}

		public void Finish()
		{
			if (mDepth != 0 || !mAtLineStart)
				Runtime.FatalError("Unbalanced generated source");
		}
	}
}
