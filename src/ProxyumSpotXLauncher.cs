using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

[assembly: AssemblyTitle("Proxyum SpotX Installer")]
[assembly: AssemblyDescription("Inicializador do Proxyum SpotX Old Theme")]
[assembly: AssemblyCompany("Proxyum")]
[assembly: AssemblyProduct("Proxyum SpotX Old Theme")]
[assembly: AssemblyCopyright("Proxyum")]
[assembly: AssemblyVersion("1.5.2.0")]
[assembly: AssemblyFileVersion("1.5.2.0")]

internal static class Program
{
    private const string ResourceName = "ProxyumSpotX.InstallProxyumSpotX.ps1";
    private const string TempPrefix = "ProxyumSpotX-Exe-";

    private static int Main(string[] args)
    {
        bool noPause = Array.IndexOf(args, "--no-pause") >= 0;
        string tempRoot = Path.GetFullPath(Path.GetTempPath()).TrimEnd('\\');
        string tempScript = Path.Combine(
            tempRoot,
            TempPrefix + Guid.NewGuid().ToString("N") + ".ps1"
        );
        int exitCode = 1;

        try
        {
            Console.Title = "Proxyum SpotX Old Theme Installer";
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("[Proxyum] Preparando o instalador...");
            Console.ResetColor();

            ExtractInstaller(tempScript);

            string systemRoot = Environment.GetEnvironmentVariable("SystemRoot");
            if (String.IsNullOrWhiteSpace(systemRoot))
            {
                throw new InvalidOperationException("A pasta do Windows nao foi encontrada.");
            }

            string powerShell = Path.Combine(
                systemRoot,
                "System32",
                "WindowsPowerShell",
                "v1.0",
                "powershell.exe"
            );
            if (!File.Exists(powerShell))
            {
                throw new FileNotFoundException("Windows PowerShell nao encontrado.", powerShell);
            }

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = powerShell;
            startInfo.Arguments =
                "-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"" + tempScript + "\"";
            startInfo.UseShellExecute = false;

            using (Process process = Process.Start(startInfo))
            {
                if (process == null)
                {
                    throw new InvalidOperationException("Nao foi possivel iniciar o instalador.");
                }

                process.WaitForExit();
                exitCode = process.ExitCode;
            }

            Console.WriteLine();
            if (exitCode == 0)
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("[Proxyum] Instalador finalizado.");
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("[Proxyum] O instalador terminou com erro " + exitCode + ".");
            }
            Console.ResetColor();
        }
        catch (Exception exception)
        {
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("ERRO: " + exception.Message);
            Console.ResetColor();
            exitCode = 1;
        }
        finally
        {
            DeleteVerifiedTempFile(tempRoot, tempScript);
        }

        if (!noPause)
        {
            Console.WriteLine();
            Console.Write("Pressione qualquer tecla para fechar...");
            Console.ReadKey(true);
        }

        return exitCode;
    }

    private static void ExtractInstaller(string destination)
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream input = assembly.GetManifestResourceStream(ResourceName))
        {
            if (input == null)
            {
                throw new InvalidOperationException("O instalador interno nao foi encontrado.");
            }

            using (FileStream output = new FileStream(
                destination,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None
            ))
            {
                input.CopyTo(output);
            }
        }
    }

    private static void DeleteVerifiedTempFile(string tempRoot, string tempScript)
    {
        string resolved = Path.GetFullPath(tempScript);
        string expectedPrefix = tempRoot + "\\" + TempPrefix;
        bool expectedPath = resolved.StartsWith(
            expectedPrefix,
            StringComparison.OrdinalIgnoreCase
        );
        bool expectedExtension = String.Equals(
            Path.GetExtension(resolved),
            ".ps1",
            StringComparison.OrdinalIgnoreCase
        );

        if (!expectedPath || !expectedExtension)
        {
            return;
        }

        try
        {
            if (File.Exists(resolved))
            {
                File.Delete(resolved);
            }
        }
        catch
        {
            // A limpeza temporaria nao deve esconder o resultado do instalador.
        }
    }
}
