using System;
using System.Collections;
using System.IO;

namespace LuaTinker.Playground;

#if BF_PLATFORM_LINUX
extension PlatformTools
{
    // Symbols borrow exportStorage, which must remain alive while the set is used.
    [Comptime]
    internal static bool TryCollectSDLExports(String exportStorage, HashSet<StringView> symbols)
    {
        String library = scope .();
        if (FindSDLLibrary(library) case .Err ||
            RunCommand("nm", scope $"-D --defined-only {library}", exportStorage) case .Err)
            return false;

        for (let line in exportStorage.Split('\n'))
        {
            let space = line.LastIndexOf(' ');
            if (space < 0)
                continue;
            StringView symbol = .(line, space + 1);
            let version = symbol.IndexOf('@');
            if (version >= 0)
                symbol = .(symbol, 0, version);
            symbols.Add(symbol);
        }
        return !symbols.IsEmpty;
    }

    [Comptime]
    private static Result<void> FindSDLLibrary(String output)
    {
        String libDir = scope .();
        Try!(RunCommand("pkg-config", "--variable=libdir sdl2", libDir));
        libDir.Trim();
        String library = scope $"{libDir}/libSDL2.so";
        if (!File.Exists(library))
            return .Err;
        output.Append(library);
        return .Ok;
    }
}
#endif
