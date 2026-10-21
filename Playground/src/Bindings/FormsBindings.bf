using System;
using System.Windows.Forms;
using LuaTinker.Helpers;

namespace LuaTinker.Playground;

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

	        [Comptime]
	        static void EmitControls()
	        {
				let code = scope String();
	            for (let declaration in TypeDeclaration.TypeDeclarations)
	            {
	                if (declaration.GetNamespace(.. scope .()) != "System.Windows.Forms")
	                    continue;
	                let type = declaration.ResolvedType;
	                if (!type.IsSubtypeOf(typeof(Control)))
	                    continue;
	                let typeCode = scope $"comptype({type.GetTypeId()})";
	                code.AppendF($"if (!state.IsClassRegistered<{typeCode}>()) forms.AutoTinkClass<{typeCode}>(.Deep);\n");
	                // BeefForms owns and deletes controls added to a parent's Controls collection.
	                if (!type.IsAbstract)
	                    code.AppendF($"tinker.AddClassCtor<{typeCode}>(.Heap);\n");
	            }
	            Compiler.MixinRoot(code);
			}
	        EmitControls();
		}
    }
}
