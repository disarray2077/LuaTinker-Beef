using System;
using System.Collections;
using System.Diagnostics;
using System.IO;

namespace LuaTinker.Playground;

static class PlatformTools
{
#if !BF_PLATFORM_WINDOWS && !BF_PLATFORM_LINUX
    [Comptime, Inline]
    internal static bool TryCollectSDLExports(String exportStorage, HashSet<StringView> symbols) => false;
#endif

    [Comptime]
    private static Result<void> RunCommand(StringView program, StringView arguments, String output)
    {
        ProcessStartInfo startInfo = scope .();
        startInfo.UseShellExecute = false;
        startInfo.CreateNoWindow = true;
        startInfo.RedirectStandardOutput = true;
        startInfo.SetArguments(arguments);
        if (File.Exists(program))
            startInfo.SetFileName(program);
        else
        {
            String path = scope .();
            Try!(Environment.GetEnvironmentVariable("PATH", path));
            bool found = false;
            for (let dir in path.Split(
#if BF_PLATFORM_WINDOWS
                ';'
#else
                ':'
#endif
                ))
            {
                String executable = scope $"{dir}/{program}";
                if (!File.Exists(executable))
                    continue;
                startInfo.SetFileName(executable);
                found = true;
                break;
            }
            if (!found)
                return .Err;
        }

        SpawnedProcess process = scope .();
        if (process.Start(startInfo) case .Err)
            return .Err;
        UnbufferedFileStream stream = scope .();
        if (process.AttachStandardOutput(stream) case .Err)
            return .Err;

        StreamReader reader = scope .(stream);
        String line = scope .();
        while (reader.ReadLine(line) case .Ok)
        {
            output.Append(line);
            output.Append('\n');
            line.Clear();
        }
        return process.ExitCode == 0 ? .Ok : .Err;
    }
}
