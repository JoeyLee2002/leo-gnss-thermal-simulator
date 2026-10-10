using System;
using System.IO;

internal static class SmokeProbe
{
    private static int Main(string[] args)
    {
        if (args.Length != 2 || args[0] != "--smoke") return 17;
        Directory.CreateDirectory(args[1]);
        File.WriteAllLines(Path.Combine(args[1], "probe.txt"), new[] {
            Path.GetFullPath(args[1]),
            Environment.GetEnvironmentVariable("LEOTHERM_RUNTIME_ROOT"),
            Environment.GetEnvironmentVariable("MCR_CACHE_ROOT"),
            Environment.GetEnvironmentVariable("PATH")
        });
        return Path.GetFileName(args[1].TrimEnd('\\')) == "exit17" ? 17 : 0;
    }
}
