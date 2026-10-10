using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using System.Xml;

internal static class PortableLauncher
{
    private static readonly string Root = AppDomain.CurrentDomain.BaseDirectory;
    private static readonly string DataRoot = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "LEOTherm", "Portable");
    private static string logPath;

    [STAThread]
    private static int Main(string[] args)
    {
        bool diagnostic = args.Length == 2 && args[0] == "--diagnose";
        bool smoke = args.Length == 2 &&
            (args[0] == "--smoke" || args[0] == "--gui-smoke");
        try
        {
            Directory.CreateDirectory(Path.Combine(DataRoot, "logs"));
            logPath = Path.Combine(DataRoot, "logs", "launch_" +
                DateTime.UtcNow.ToString("yyyyMMdd_HHmmss_fff", CultureInfo.InvariantCulture) +
                "_" + Process.GetCurrentProcess().Id + ".log");
            Log("Package directory: " + Root);
            if (args.Length != 0 && !diagnostic && !smoke)
                throw new InvalidOperationException(
                    "Use Start_LEOTherm.exe, --diagnose FILE, --smoke DIRECTORY, or --gui-smoke DIRECTORY.");
            Dictionary<string, object> manifest = ReadManifest();
            string runtime = Path.Combine(Root, "runtime", "v911");
            Validate(manifest, runtime);
            if (diagnostic)
            {
                WriteJson(args[1], new Dictionary<string, object> {
                    {"outcome", "ready"}, {"packageRoot", Root},
                    {"runtimeRoot", runtime}, {"runtimeRelease", "R2021b"},
                    {"packageVersion", manifest["packageVersion"]},
                    {"systemEnvironmentChanged", false}, {"log", logPath}
                });
                Log("Preflight passed; diagnosis does not start MATLAB or prove all DLL dependencies.");
                return 0;
            }
            // Noninteractive smoke tests are for developers already licensed to use the Runtime.
            // They never create or overwrite the end user's license acknowledgement.
            if (!smoke && !ConfirmLicense(runtime, (string)manifest["runtimeLicenseSha256"]))
                return 2;

            string cache = Path.Combine(DataRoot, "cache", (string)manifest["appVersion"]);
            Directory.CreateDirectory(cache);
            var start = new ProcessStartInfo(Path.Combine(Root, "app", "LEOTherm.exe"));
            start.UseShellExecute = false;
            start.WorkingDirectory = Path.Combine(Root, "app");
            start.Arguments = smoke ? args[0] + " " + Quote(Path.GetFullPath(args[1])) : "";
            string[] libraries = {
                Path.Combine(runtime, "runtime", "win64"),
                Path.Combine(runtime, "bin", "win64"),
                Path.Combine(runtime, "sys", "os", "win64")
            };
            start.EnvironmentVariables["PATH"] = string.Join(";", libraries) + ";" +
                (Environment.GetEnvironmentVariable("PATH") ?? "");
            start.EnvironmentVariables["MCR_CACHE_ROOT"] = cache;
            start.EnvironmentVariables["LEOTHERM_PORTABLE_ROOT"] = Root;
            start.EnvironmentVariables["LEOTHERM_RUNTIME_ROOT"] = runtime;
            start.EnvironmentVariables["LEOTHERM_LAUNCH_LOG"] = logPath;
            Log("Runtime directory: " + runtime);
            Log("Cache directory: " + cache);
            using (Process child = Process.Start(start))
            {
                if (child == null) throw new InvalidOperationException("Could not start LEOTherm.");
                Log("Application PID: " + child.Id);
                child.WaitForExit();
                Log("Application exit code: " + child.ExitCode);
                if (child.ExitCode != 0 && !smoke)
                    MessageBox.Show("LEOTherm exited unexpectedly (code " + child.ExitCode +
                        ").\n\nDiagnostic log:\n" + logPath +
                        "\n\nKeep this log when reporting the problem. Do not disable Windows security.",
                        "LEOTherm - startup problem", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return child.ExitCode;
            }
        }
        catch (Exception error)
        {
            Log(error.ToString());
            if (diagnostic)
            {
                try { WriteJson(args[1], new Dictionary<string, object> {
                    {"outcome", "failed"}, {"message", error.Message}, {"log", logPath}
                }); } catch { }
            }
            else if (!smoke)
                MessageBox.Show(error.Message + "\n\nExtract the complete portable ZIP to an " +
                    "English-only path, for example C:\\LEOTherm. " +
                    "Do not launch from inside the ZIP.\n\nDiagnostic log:\n" + logPath,
                    "LEOTherm - cannot start", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static Dictionary<string, object> ReadManifest()
    {
        return new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(
            File.ReadAllText(Path.Combine(Root, "portable_manifest.json"), Encoding.UTF8));
    }

    private static void Validate(Dictionary<string, object> manifest, string runtime)
    {
        if (!Environment.Is64BitOperatingSystem)
            throw new InvalidOperationException("This package requires 64-bit Windows.");
        if (Root.Any(c => c > 127))
            throw new InvalidOperationException("MATLAB Runtime requires an English-only package path.");
        if ((string)manifest["schema"] != "leotherm.portable.v1")
            throw new InvalidOperationException("Unknown portable package format.");
        string infoPath = Path.Combine(runtime, "VersionInfo.xml");
        var info = new XmlDocument();
        info.XmlResolver = null;
        info.Load(infoPath);
        if (info.SelectSingleNode("/MathWorks_version_info/release").InnerText != "R2021b" ||
            !info.SelectSingleNode("/MathWorks_version_info/version").InnerText.StartsWith("9.11."))
            throw new InvalidOperationException("The bundled Runtime is not R2021b (9.11).");
        VerifyHash(Path.Combine(Root, "app", "LEOTherm.exe"), (string)manifest["appSha256"]);
        VerifyHash(Path.Combine(runtime, "runtime", "win64", "mclmcrrt9_11.dll"),
            (string)manifest["runtimeDllSha256"]);
        VerifyHash(Path.Combine(runtime, "MCR_license.txt"), (string)manifest["runtimeLicenseSha256"]);
        foreach (string relative in new[] {
            @"bin\win64\MATLABWindow.exe", @"sys\java\jre\win64\jre\bin\java.dll",
            @"bin\win64\vcruntime140.dll", @"bin\win64\msvcp140.dll" })
            if (!File.Exists(Path.Combine(runtime, relative)))
                throw new FileNotFoundException("The Runtime package is incomplete: " + relative);
        Log("Critical package files and hashes verified.");
    }

    private static void VerifyHash(string path, string expected)
    {
        using (var algorithm = SHA256.Create())
        using (var stream = File.OpenRead(path))
        {
            string actual = BitConverter.ToString(algorithm.ComputeHash(stream)).Replace("-", "");
            if (!string.Equals(actual, expected, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("File is missing, modified or damaged: " + path);
        }
    }

    private static bool ConfirmLicense(string runtime, string licenseHash)
    {
        string acknowledgement = Path.Combine(DataRoot, "runtime_license_" + licenseHash + ".txt");
        if (File.Exists(acknowledgement)) return true;
        Application.EnableVisualStyles();
        using (var form = new Form())
        using (var license = new TextBox())
        using (var accept = new CheckBox())
        using (var proceed = new Button())
        using (var cancel = new Button())
        {
            form.Text = "LEOTherm - bundled MATLAB Runtime license";
            form.ClientSize = new System.Drawing.Size(760, 520);
            form.StartPosition = FormStartPosition.CenterScreen;
            form.MinimizeBox = false;
            license.Multiline = true; license.ReadOnly = true;
            license.ScrollBars = ScrollBars.Vertical;
            license.SetBounds(16, 16, 728, 400);
            license.Text = File.ReadAllText(Path.Combine(runtime, "MCR_license.txt"));
            accept.Text = "I accept the MATLAB Runtime license above.";
            accept.SetBounds(16, 430, 600, 28);
            proceed.Text = "Start LEOTherm"; proceed.Enabled = false;
            proceed.SetBounds(450, 475, 150, 30); proceed.DialogResult = DialogResult.OK;
            cancel.Text = "Cancel"; cancel.SetBounds(614, 475, 130, 30);
            cancel.DialogResult = DialogResult.Cancel;
            accept.CheckedChanged += delegate { proceed.Enabled = accept.Checked; };
            form.Controls.AddRange(new Control[] { license, accept, proceed, cancel });
            form.CancelButton = cancel;
            if (form.ShowDialog() != DialogResult.OK || !accept.Checked) return false;
        }
        File.WriteAllText(acknowledgement, "User acknowledged this Runtime license at " +
            DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture), Encoding.UTF8);
        return true;
    }

    private static string Quote(string value)
    {
        // Windows CommandLineToArgvW quoting, including a trailing directory separator.
        var result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in value)
        {
            if (c == '\\') { slashes++; continue; }
            result.Append('\\', c == '"' ? slashes * 2 + 1 : slashes);
            result.Append(c); slashes = 0;
        }
        result.Append('\\', slashes * 2); result.Append('"');
        return result.ToString();
    }

    private static void WriteJson(string path, object value)
    {
        File.WriteAllText(Path.GetFullPath(path), new JavaScriptSerializer().Serialize(value), Encoding.UTF8);
    }

    private static void Log(string message)
    {
        if (logPath == null) return;
        try { File.AppendAllText(logPath, DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture) +
            " " + message + Environment.NewLine, Encoding.UTF8); } catch { }
    }
}
