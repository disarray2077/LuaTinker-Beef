using System;
using System.Collections;
using System.IO;

namespace LuaTinker.Playground;

#if BF_PLATFORM_WINDOWS
extension PlatformTools
{
    // Symbols borrow exportStorage, which must remain alive while the set is used.
    [Comptime]
    internal static bool TryCollectSDLExports(String exportStorage, HashSet<StringView> symbols)
    {
        String dumpbin = scope .();
        String library = scope .();
        if (FindDumpbin(dumpbin) case .Err || FindSDLLibrary(library) case .Err ||
            RunCommand(dumpbin, scope $"/nologo /exports \"{library}\"", exportStorage) case .Err)
            return false;

        for (let line in exportStorage.Split('\n'))
        {
            let start = line.IndexOf("SDL_");
            if (start < 0)
                continue;
            StringView symbol = .(line, start);
            let end = symbol.IndexOf(' ');
            if (end >= 0)
                symbol = .(symbol, 0, end);
            symbols.Add(symbol);
        }
        return !symbols.IsEmpty;
    }

    [Comptime]
    private static Result<void> FindDumpbin(String output)
    {
        String programFiles = scope .();
        Try!(Environment.GetEnvironmentVariable("ProgramFiles(x86)", programFiles));
        String vswhere = scope $"{programFiles}/Microsoft Visual Studio/Installer/vswhere.exe";
        String paths = scope .();
        Try!(RunCommand(vswhere,
            "-latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find VC/Tools/MSVC/**/bin/Hostx64/x64/dumpbin.exe", paths));
        for (var path in paths.Split('\n'))
        {
            path.Trim();
            if (!File.Exists(path))
                continue;
            output.Append(path);
            return .Ok;
        }
        return .Err;
    }

    [Comptime]
    private static Result<void> FindSDLLibrary(String output)
    {
        // SDL2 uses Beef's bundled package; support installed and source-build compiler layouts.
        String directory = scope .();
        Try!(Path.GetDirectoryPath(Compiler.CompilerPath, directory));
        while (!directory.IsEmpty)
        {
            String library = scope $"{directory}/BeefLibs/SDL2/dist/SDL2.dll";
            if (File.Exists(library))
            {
                output.Append(library);
                return .Ok;
            }
            String parent = scope .();
            if (Path.GetDirectoryPath(directory, parent) case .Err || parent == directory)
                break;
            directory.Set(parent);
        }
        return .Err;
    }
}
#endif
