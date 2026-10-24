// Command-line driver around the unmodified IronBrew 2 library (MIT, https://github.com/Trollicus/ironbrew-2).
// It only exposes ObfuscationSettings as flags so the test corpus can be generated in several configurations;
// no IronBrew 2 source is changed or copied here.
//
//   Ib2Driver <input.lua> <output.lua> [--no-flow] [--no-mutate] [--no-super] [--no-compress]
//                                      [--strings] [--important-strings] [--lineinfo]
using System;
using System.IO;
using IronBrew2;
using IronBrew2.Obfuscator;

static class Ib2Driver
{
    static int Main(string[] args)
    {
        if (args.Length < 2) { Console.Error.WriteLine("usage: Ib2Driver input.lua output.lua [flags]"); return 2; }
        var s = new ObfuscationSettings();
        for (int i = 2; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--no-flow": s.ControlFlow = false; break;
                case "--no-mutate": s.Mutate = false; break;
                case "--no-super": s.SuperOperators = false; break;
                case "--no-compress": s.BytecodeCompress = false; break;
                case "--strings": s.EncryptStrings = true; break;
                case "--important-strings": s.EncryptImportantStrings = true; break;
                case "--lineinfo": s.PreserveLineInfo = true; break;
                default: Console.Error.WriteLine("unknown flag " + args[i]); return 2;
            }
        }
        string work = Path.Combine(Path.GetTempPath(), "ib2-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(work);
        try
        {
            if (!IB2.Obfuscate(work, Path.GetFullPath(args[0]), s, out string err))
            {
                Console.Error.WriteLine("IronBrew 2 failed: " + err);
                return 1;
            }
            File.Copy(Path.Combine(work, "out.lua"), args[1], true);
            return 0;
        }
        finally { try { Directory.Delete(work, true); } catch { } }
    }
}
