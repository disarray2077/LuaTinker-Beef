using System;
using System.Collections;
using LuaTinker.Helpers;

using internal LuaTinker;
using internal LuaTinker.Helpers;

namespace LuaTinker
{
	extension LuaTinker
	{
		/// Opens an independent binding scope for a Lua namespace.
		public NamespaceScope BeginNamespace(StringView name)
			=> .(this, name);

		/// Registers a class and opens a scope for its bindings.
		public ClassScope<T> BeginClass<T>(StringView name = "")
		{
			let path = scope String();
			AppendScopeClassName(typeof(T), name, path);
			AddScopedClass(typeof(T), "", path);
			return .(this);
		}

		internal static void AppendScopeClassName(Type type, StringView name, String path)
		{
			if (name.IsEmpty)
			{
				type.GetName(path);
				if (let specialized = type as System.Reflection.SpecializedGenericType)
					for (int i < specialized.GenericParamCount)
						specialized.GetGenericArg(i).GetName(path);
			}
			else
				path.Append(name);
		}
	}

	/// Owns a namespace path without retaining entries on the Lua stack.
	public struct NamespaceScope : IDisposable
	{
		private LuaTinker mTinker;
		private String mPath;

		internal this(LuaTinker tinker, StringView path)
		{
			mTinker = tinker;
			mPath = new .(path);
			mTinker.AddNamespace(mPath);
		}

		public void Dispose() { delete mPath; }

		public NamespaceScope BeginNamespace(StringView name)
		{
			let path = scope String(mPath);
			path.Append('.');
			path.Append(name);
			return .(mTinker, path);
		}

		public ClassScope<T> BeginClass<T>(StringView name = "")
		{
			let className = scope String();
			LuaTinker.AppendScopeClassName(typeof(T), name, className);
			mTinker.AddScopedClass(typeof(T), mPath, className);
			return .(mTinker);
		}

		/// Binds T's supported static members directly into this namespace, without registering dependencies.
		[Inline]
		public void AutoTinkClass<T>(AutoTinkShallowMode mode, enum { Inline } name)
			=> AutoTinkInline<T, NoMethodExclusions, const AutoTinkFlags.None>(.None);

		/// Binds T's supported static members directly into this namespace, without registering dependencies.
		/// @where Exclusions Supplies method names to omit, including all their overloads.
		[Inline]
		public void AutoTinkClass<T, Exclusions>(AutoTinkShallowMode mode, enum { Inline } name)
			where Exclusions : struct, IMethodExclusionProvider
			=> AutoTinkInline<T, Exclusions, const AutoTinkFlags.None>(.None);

		/// Binds T's supported static members here and recursively registers dependencies.
		[Inline]
		public void AutoTinkClass<T>(AutoTinkDeepMode mode, enum { Inline } name)
			=> AutoTinkInline<T, NoMethodExclusions, const AutoTinkFlags.IncludeAll>(.IncludeAll);

		/// Binds T's supported static members here and recursively registers dependencies.
		/// @where Exclusions Supplies method names to omit from T and each dependency, including all overloads.
		[Inline]
		public void AutoTinkClass<T, Exclusions>(AutoTinkDeepMode mode, enum { Inline } name)
			where Exclusions : struct, IMethodExclusionProvider
			=> AutoTinkInline<T, Exclusions, const AutoTinkFlags.IncludeAll>(.IncludeAll);

		/// Binds T's supported static members here and recursively registers selected dependencies.
		/// @param flags Compile-time dependency inclusion options.
		[Inline]
		public void AutoTinkClass<T, Flags>(AutoTinkDeepMode mode, Flags flags, enum { Inline } name)
			where Flags : const AutoTinkFlags
			=> AutoTinkInline<T, NoMethodExclusions, const Flags>(flags);

		/// Binds T's supported static members here and recursively registers selected dependencies.
		/// @where Exclusions Supplies method names to omit from T and each dependency, including all overloads.
		/// @param flags Compile-time dependency inclusion options.
		[Inline]
		public void AutoTinkClass<T, Exclusions, Flags>(AutoTinkDeepMode mode, Flags flags, enum { Inline } name)
			where Exclusions : struct, IMethodExclusionProvider
			where Flags : const AutoTinkFlags
			=> AutoTinkInline<T, Exclusions, const Flags>(flags);

		private void AutoTinkInline<T, Exclusions, Flags>(Flags flags)
			where Exclusions : struct, IMethodExclusionProvider
			where Flags : const AutoTinkFlags
		{
			mTinker.BeginAutoTink<T, Exclusions, const Flags, const true>(flags, "", mPath);
		}

		[OnCompile(.TypeInit), Comptime]
		private static void EmitBindings()
			=> ScopeBindingGenerator.EmitNamespace(typeof(Self));
	}

	/// Carries the registered class type for subsequent bindings.
	public struct ClassScope<T> : IDisposable
	{
		private LuaTinker mTinker;

		internal this(LuaTinker tinker) { mTinker = tinker; }

		public void Dispose() {}

		[OnCompile(.TypeInit), Comptime]
		private static void EmitBindings()
			=> ScopeBindingGenerator.EmitClass(typeof(Self));
	}

	internal static class ScopeBindingGenerator
	{
		private struct Token
		{
			public StringView Text;
			public int Start;
			public int End;
		}

		[Comptime]
		public static void EmitNamespace(Type owner)
		{
			String code = scope .();
			EmitFamily("AddNamespace", false, code);
			EmitMethods("AutoTinkClass", "AutoTinkClass", false, true, code);
			Compiler.EmitTypeBody(owner, code);
		}

		[Comptime]
		public static void EmitClass(Type owner)
		{
			String code = scope .();
			let structScope = (owner as System.Reflection.SpecializedGenericType)?.GetGenericArg(0).IsStruct ?? false;
			EmitFamily("AddClass", true, code, structScope);
			if (structScope)
				EmitFamily("AddStruct", true, code);
			Compiler.EmitTypeBody(owner, code);
		}

		private static void EmitFamily(StringView prefix, bool classScope, String code, bool structScope = false)
		{
			HashSet<StringView> names = scope .();
			for (let method in typeof(LuaTinker).GetMethods(.Public | .NonPublic | .DeclaredOnly))
			{
				if (!method.Name.StartsWith(prefix) || method.Name.Length == prefix.Length || !names.Add(method.Name))
					continue;
				let scopeName = scope String("Add");
				scopeName.Append(method.Name.Substring(prefix.Length));
				EmitMethods(method.Name, scopeName, classScope, false, code, structScope);
			}
		}

		// Reflection discovers the methods; declaration text preserves their constraints and defaults.
		private static void EmitMethods(StringView sourceName, StringView scopeName, bool classScope, bool autoTink, String code, bool structScope = false)
		{
			let source = typeof(LuaTinker).TypeDeclaration.GetMethodDeclarationText(sourceName);
			List<Token> tokens = scope .();
			Tokenize(source, tokens);
			int declarationStart = 0;
			for (int i < tokens.Count)
			{
				if (tokens[i].Text != sourceName || i + 1 >= tokens.Count ||
					(tokens[i + 1].Text != "<" && tokens[i + 1].Text != "("))
					continue;
				int visibilityIndex = -1;
				for (int j = declarationStart; j < i; j++)
					if (tokens[j].Text == ((classScope || autoTink) ? "public" : "internal"))
						visibilityIndex = j;
				let nameIndex = i;
				int genericStart = -1;
				int genericEnd = -1;
				int parameterStart = i + 1;
				if (tokens[parameterStart].Text == "<")
				{
					genericStart = parameterStart;
					genericEnd = FindClose(tokens, genericStart, "<", ">");
					parameterStart = genericEnd + 1;
				}
				let parameterEnd = FindClose(tokens, parameterStart, "(", ")");
				int bodyStart = parameterEnd + 1;
				while (tokens[bodyStart].Text != "{" && tokens[bodyStart].Text != "=>")
					bodyStart++;
				let bodyEnd = tokens[bodyStart].Text == "{"
					? FindClose(tokens, bodyStart, "{", "}")
					: FindSemicolon(tokens, bodyStart);
				declarationStart = bodyEnd + 1;
				i = bodyEnd;
				if (visibilityIndex < 0)
					continue;
				bool requiresClass = false;
				if (structScope)
					for (int j = parameterEnd + 1; j + 3 < bodyStart; j++)
						if (tokens[j].Text == "where" && tokens[j + 1].Text == "T" && tokens[j + 2].Text == ":" && tokens[j + 3].Text == "class")
							requiresClass = true;
				if (requiresClass)
					continue;

				List<(int start, int end)> generics = scope .();
				if (genericStart >= 0)
					Split(tokens, genericStart + 1, genericEnd, generics);
				List<(int start, int end)> parameters = scope .();
				Split(tokens, parameterStart + 1, parameterEnd, parameters);

				code.Append("[Inline]\npublic ");
				AppendSource(source, tokens, visibilityIndex + 1, nameIndex, code);
				code.Append(scopeName);
				let firstGeneric = classScope ? 1 : 0;
				if (generics.Count > firstGeneric)
				{
					code.Append('<');
					AppendParts(source, tokens, generics, firstGeneric, code);
					code.Append('>');
				}
				code.Append('(');
				AppendParts(source, tokens, parameters, !classScope && !autoTink ? 1 : 0, code);
				code.Append(')');
				AppendSource(source, tokens, parameterEnd + 1, bodyStart, code);
				if (autoTink)
				{
					let expression = scope String(source.Substring(tokens[bodyStart + 1].Start,
						tokens[bodyEnd].Start - tokens[bodyStart + 1].Start));
					// Reuse the root forwarder's flags and exclusions, replacing only its destination.
					expression.Replace("namespacePath: \"\"", "namespacePath: mPath");
					code.AppendF($"\n=> mTinker.{expression};\n");
					continue;
				}
				code.AppendF($"\n=> mTinker.{sourceName}");
				if (!generics.IsEmpty)
				{
					code.Append('<');
					for (let generic in generics)
					{
						if (@generic.Index > 0)
							code.Append(", ");
						let name = tokens[generic.start].Text;
						if (IsConstGeneric(tokens, parameterEnd + 1, bodyStart, name))
							code.Append("const ");
						code.Append(name);
					}
					code.Append('>');
				}
				code.Append('(');
				if (!classScope && !autoTink)
					code.Append("mPath");
				for (let parameter in parameters)
				{
					if (!classScope && !autoTink && @parameter.Index == 0)
						continue;
					if (@parameter.Index > 0)
						code.Append(", ");
					int nameIndexInParameter = parameter.end - 1;
					for (int j = parameter.start; j < parameter.end; j++)
						if (tokens[j].Text == "=")
						{
							nameIndexInParameter = j - 1;
							break;
						}
					let name = tokens[nameIndexInParameter].Text;
					if (tokens[parameter.start].Text == "ref" || tokens[parameter.start].Text == "out" || tokens[parameter.start].Text == "params")
						code.AppendF($"{tokens[parameter.start].Text} ");
					code.Append(name);
				}
				code.Append(");\n");
			}
		}

		private static bool IsConstGeneric(List<Token> tokens, int start, int end, StringView name)
		{
			for (int i = start; i + 3 < end; i++)
				if (tokens[i].Text == "where" && tokens[i + 1].Text == name && tokens[i + 2].Text == ":" && tokens[i + 3].Text == "const")
					return true;
			return false;
		}

		private static void AppendSource(StringView source, List<Token> tokens, int start, int end, String code)
		{
			if (start < end)
				code.Append(source.Substring(tokens[start].Start, tokens[end].Start - tokens[start].Start));
		}

		private static void AppendParts(StringView source, List<Token> tokens, List<(int start, int end)> parts, int first, String code)
		{
			for (int i = first; i < parts.Count; i++)
			{
				if (i > first)
					code.Append(", ");
				let part = parts[i];
				code.Append(source.Substring(tokens[part.start].Start, tokens[part.end - 1].End - tokens[part.start].Start));
			}
		}

		private static int FindClose(List<Token> tokens, int start, StringView open, StringView close)
		{
			int depth = 0;
			for (int i = start; i < tokens.Count; i++)
			{
				if (tokens[i].Text == open)
					depth++;
				else if (tokens[i].Text == close && --depth == 0)
					return i;
			}
			Runtime.FatalError("Unbalanced binding declaration");
		}

		private static int FindSemicolon(List<Token> tokens, int start)
		{
			for (int i = start; i < tokens.Count; i++)
				if (tokens[i].Text == ";")
					return i;
			Runtime.FatalError("Missing binding declaration terminator");
		}

		private static void Split(List<Token> tokens, int start, int end, List<(int start, int end)> parts)
		{
			int depth = 0;
			int first = start;
			for (int i = start; i < end; i++)
			{
				let text = tokens[i].Text;
				if (text == "<" || text == "(" || text == "[" || text == "{")
					depth++;
				else if (text == ">" || text == ")" || text == "]" || text == "}")
					depth--;
				else if (text == "," && depth == 0)
				{
					parts.Add((first, i));
					first = i + 1;
				}
			}
			if (first < end)
				parts.Add((first, end));
		}

		private static bool IsIdentifier(char8 c)
			=> c.IsLetterOrDigit || c == '_' || (uint8)c >= 0x80;

		private static void Tokenize(StringView source, List<Token> tokens)
		{
			for (int i = 0; i < source.Length;)
			{
				if (source[i].IsWhiteSpace)
				{
					i++;
					continue;
				}
				if (source[i] == '#' || (i + 1 < source.Length && source[i] == '/' && source[i + 1] == '/'))
				{
					while (i < source.Length && source[i] != '\n')
						i++;
					continue;
				}
				if (i + 1 < source.Length && source[i] == '/' && source[i + 1] == '*')
				{
					i += 2;
					while (i + 1 < source.Length && !(source[i] == '*' && source[i + 1] == '/'))
						i++;
					i += 2;
					continue;
				}
				let start = i;
				if (source[i] == '"' || source[i] == '\'')
				{
					let quote = source[i++];
					let triple = quote == '"' && i + 1 < source.Length && source[i] == quote && source[i + 1] == quote;
					if (triple)
						i += 2;
					while (i < source.Length)
					{
						if (!triple && source[i] == '\\')
							i += 2;
						else if (source[i] == quote && (!triple || (i + 2 < source.Length && source[i + 1] == quote && source[i + 2] == quote)))
						{
							i += triple ? 3 : 1;
							break;
						}
						else
							i++;
					}
				}
				else if (IsIdentifier(source[i]))
				{
					while (i < source.Length && IsIdentifier(source[i]))
						i++;
				}
				else
				{
					i++;
					if (source[start] == '=' && i < source.Length && source[i] == '>')
						i++;
				}
				tokens.Add(.() { Text = source.Substring(start, i - start), Start = start, End = i });
			}
		}
	}
}
