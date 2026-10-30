using System;
using System.Collections;
using System.ComponentModel;
using System.Windows.Forms;
using LuaTinker.Helpers;

namespace LuaTinker.Playground;

struct FormsExclusions : IMethodExclusionProvider
{
    [Comptime]
    public static void CollectExcludedMethods(Type type, HashSet<StringView> excluded)
    {
        // Binding this Result<IComponent> return triggers an invalid StringView? conversion in Beef.
        if (type == typeof(ReadOnlyCollectionBase<IComponent>.Enumerator))
            excluded.Add("GetNext");
    }
}

static class FormsBindings
{
    public static void Register(LuaTinker tinker, LuaTinkerState state)
    {
        [Comptime]
        static void EmitEventHandlers()
        {
            for (let declaration in TypeDeclaration.TypeDeclarations)
            {
                let name = declaration.GetName(.. scope .());
                let namespaceName = declaration.GetNamespace(.. scope .());
                if (!name.EndsWith("EventHandler") ||
                    (namespaceName != "System.Windows.Forms" &&
                     !(namespaceName == "System" && name == "EventHandler")))
                    continue;
                let type = declaration.ResolvedType;
                if (IsDelegateType(type))
                    Compiler.MixinRoot(scope $"tinker.RegisterDelegate<comptype({type.GetTypeId()})>(.Persistent);");
            }
        }
        EmitEventHandlers();
		
		using (let forms = tinker.BeginNamespace("Forms"))
		{
		    forms.AutoTinkClass<Application>(.Deep, .Inline);
		    forms.AutoTinkClass<MessageBox>(.Deep);
		    forms.AutoTinkClass<Container, FormsExclusions>(.Deep);

	        [Comptime]
	        static void EmitComponents()
	        {
				let code = scope String();
	            for (let declaration in TypeDeclaration.TypeDeclarations)
	            {
	                if (declaration.GetNamespace(.. scope .()) != "System.Windows.Forms")
	                    continue;
	                let type = declaration.ResolvedType;
	                if (!type.IsSubtypeOf(typeof(Component)))
	                    continue;
	                let typeCode = scope $"comptype({type.GetTypeId()})";
	                code.AppendF($"if (!state.IsClassRegistered<{typeCode}>()) forms.AutoTinkClass<{typeCode}, FormsExclusions>(.Deep);\n");
	                // Components can transfer ownership to Beef, including child controls.
	                if (!type.IsAbstract)
	                    code.AppendF($"tinker.AddClassCtor<{typeCode}>(.Heap);\n");
	            }
	            Compiler.MixinRoot(code);
			}
	        EmitComponents();
		}
    }
}
