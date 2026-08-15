using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Globalization;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Windows.Forms;

[assembly: AssemblyTitle("Proxyum SpotX Setup")]
[assembly: AssemblyDescription("Interface grafica do Proxyum SpotX Old Theme")]
[assembly: AssemblyCompany("Proxyum")]
[assembly: AssemblyProduct("Proxyum SpotX Old Theme")]
[assembly: AssemblyCopyright("Proxyum")]
[assembly: AssemblyVersion("1.5.3.0")]
[assembly: AssemblyFileVersion("1.5.3.0")]

internal static class GuiProgram
{
    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new InstallerForm());
    }
}

internal sealed class InstallerForm : Form
{
    private const string ResourceName = "ProxyumSpotX.InstallProxyumSpotX.ps1";
    private const string LogoResourceName = "ProxyumSpotX.Logo.png";
    private const string TempPrefix = "ProxyumSpotX-Gui-";

    private readonly Color background = Color.FromArgb(18, 18, 18);
    private readonly Color surface = Color.FromArgb(30, 30, 30);
    private readonly Color spotifyGreen = Color.FromArgb(29, 185, 84);
    private readonly Color textWhite = Color.FromArgb(245, 245, 245);
    private readonly Color textMuted = Color.FromArgb(170, 170, 170);

    private readonly string tempRoot;
    private readonly string tempScript;
    private Button installButton;
    private Button removeButton;
    private Button exitButton;
    private RadioButton keepContentRadio;
    private RadioButton hideContentRadio;
    private CheckBox startSpotifyCheck;
    private ProgressBar progressBar;
    private Label statusLabel;
    private RichTextBox logBox;
    private Process runningProcess;
    private bool busy;
    private bool openSpotifyAfterSuccess;
    private Image logoImage;

    internal InstallerForm()
    {
        tempRoot = Path.GetFullPath(Path.GetTempPath()).TrimEnd('\\');
        tempScript = Path.Combine(
            tempRoot,
            TempPrefix + Guid.NewGuid().ToString("N") + ".ps1"
        );

        BuildInterface();
        FormClosing += OnFormClosing;
        FormClosed += delegate
        {
            if (logoImage != null)
            {
                logoImage.Dispose();
            }
        };

        try
        {
            ExtractInstaller();
            SetStatus("PRONTO PARA INICIAR", spotifyGreen);
            AppendLog("[SISTEMA] Instalador interno carregado e pronto.");
        }
        catch (Exception exception)
        {
            SetStatus("ERRO AO PREPARAR", Color.OrangeRed);
            AppendLog("ERRO: " + exception.Message);
            installButton.Enabled = false;
            removeButton.Enabled = false;
        }
    }

    private void BuildInterface()
    {
        Text = "Proxyum SpotX Old Theme";
        BackColor = background;
        ForeColor = textWhite;
        ClientSize = new Size(760, 620);
        MinimumSize = new Size(776, 659);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
        AutoScaleMode = AutoScaleMode.Dpi;
        try
        {
            Icon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        }
        catch
        {
            // O icone do executavel continua disponivel no Explorer.
        }

        Panel header = new Panel();
        header.BackColor = Color.FromArgb(12, 12, 12);
        header.Location = new Point(0, 0);
        header.Size = new Size(760, 102);
        header.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        Controls.Add(header);

        try
        {
            logoImage = LoadLogoImage();
            PictureBox logo = new PictureBox();
            logo.BackColor = Color.Transparent;
            logo.Image = logoImage;
            logo.Location = new Point(92, 12);
            logo.Size = new Size(76, 76);
            logo.SizeMode = PictureBoxSizeMode.Zoom;
            header.Controls.Add(logo);
        }
        catch
        {
            // A interface permanece funcional mesmo se o recurso visual falhar.
        }

        Label proxyumLabel = new Label();
        proxyumLabel.AutoSize = true;
        proxyumLabel.Text = "PROXYUM";
        proxyumLabel.ForeColor = textWhite;
        proxyumLabel.Font = new Font("Segoe UI", 27F, FontStyle.Bold, GraphicsUnit.Point);
        proxyumLabel.Location = new Point(180, 17);
        header.Controls.Add(proxyumLabel);

        Label spotXLabel = new Label();
        spotXLabel.AutoSize = true;
        spotXLabel.Text = "SPOTX";
        spotXLabel.ForeColor = spotifyGreen;
        spotXLabel.Font = new Font("Segoe UI", 27F, FontStyle.Bold, GraphicsUnit.Point);
        spotXLabel.Location = new Point(376, 17);
        header.Controls.Add(spotXLabel);

        Label subtitle = new Label();
        subtitle.AutoSize = true;
        subtitle.Text = "TEMA ANTIGO  |  SPOTIFY 1.2.13.661  |  VERSAO 1.5.3";
        subtitle.ForeColor = textMuted;
        subtitle.Location = new Point(222, 72);
        header.Controls.Add(subtitle);

        GroupBox optionsBox = new GroupBox();
        optionsBox.Text = " OPCOES DA PAGINA INICIAL ";
        optionsBox.ForeColor = spotifyGreen;
        optionsBox.BackColor = surface;
        optionsBox.Location = new Point(24, 120);
        optionsBox.Size = new Size(712, 100);
        Controls.Add(optionsBox);

        keepContentRadio = new RadioButton();
        keepContentRadio.Text = "Manter podcasts, episodios e audiolivros";
        keepContentRadio.ForeColor = textWhite;
        keepContentRadio.Location = new Point(20, 27);
        keepContentRadio.Size = new Size(310, 24);
        keepContentRadio.Checked = true;
        optionsBox.Controls.Add(keepContentRadio);

        hideContentRadio = new RadioButton();
        hideContentRadio.Text = "Remover podcasts, episodios e audiolivros";
        hideContentRadio.ForeColor = textWhite;
        hideContentRadio.Location = new Point(360, 27);
        hideContentRadio.Size = new Size(320, 24);
        optionsBox.Controls.Add(hideContentRadio);

        startSpotifyCheck = new CheckBox();
        startSpotifyCheck.Text = "Abrir o Spotify quando terminar";
        startSpotifyCheck.ForeColor = textWhite;
        startSpotifyCheck.Location = new Point(20, 62);
        startSpotifyCheck.Size = new Size(270, 24);
        startSpotifyCheck.Checked = true;
        optionsBox.Controls.Add(startSpotifyCheck);

        installButton = CreateButton(
            "INSTALAR OU REPARAR",
            new Point(24, 238),
            new Size(360, 48),
            spotifyGreen,
            Color.Black
        );
        installButton.Click += StartInstall;
        Controls.Add(installButton);

        removeButton = CreateButton(
            "REMOVER COMPLETAMENTE",
            new Point(398, 238),
            new Size(230, 48),
            Color.FromArgb(55, 55, 55),
            textWhite
        );
        removeButton.Click += StartRemoval;
        Controls.Add(removeButton);

        exitButton = CreateButton(
            "SAIR",
            new Point(642, 238),
            new Size(94, 48),
            Color.FromArgb(40, 40, 40),
            textMuted
        );
        exitButton.Click += delegate { Close(); };
        Controls.Add(exitButton);

        statusLabel = new Label();
        statusLabel.AutoSize = false;
        statusLabel.TextAlign = ContentAlignment.MiddleLeft;
        statusLabel.Font = new Font("Consolas", 10F, FontStyle.Bold, GraphicsUnit.Point);
        statusLabel.Location = new Point(24, 304);
        statusLabel.Size = new Size(712, 24);
        Controls.Add(statusLabel);

        progressBar = new ProgressBar();
        progressBar.Location = new Point(24, 334);
        progressBar.Size = new Size(712, 18);
        progressBar.Minimum = 0;
        progressBar.Maximum = 100;
        progressBar.Value = 0;
        Controls.Add(progressBar);

        logBox = new RichTextBox();
        logBox.BackColor = Color.FromArgb(10, 10, 10);
        logBox.ForeColor = Color.FromArgb(205, 205, 205);
        logBox.BorderStyle = BorderStyle.FixedSingle;
        logBox.Font = new Font("Consolas", 9F, FontStyle.Regular, GraphicsUnit.Point);
        logBox.Location = new Point(24, 370);
        logBox.Size = new Size(712, 226);
        logBox.ReadOnly = true;
        logBox.DetectUrls = false;
        logBox.WordWrap = false;
        Controls.Add(logBox);

    }

    private static Image LoadLogoImage()
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream stream = assembly.GetManifestResourceStream(LogoResourceName))
        {
            if (stream == null)
            {
                throw new InvalidOperationException("Logo interno nao encontrado.");
            }

            using (Image source = Image.FromStream(stream))
            {
                return new Bitmap(source);
            }
        }
    }

    private Button CreateButton(
        string text,
        Point location,
        Size size,
        Color buttonColor,
        Color foreground
    )
    {
        Button button = new Button();
        button.Text = text;
        button.Location = location;
        button.Size = size;
        button.BackColor = buttonColor;
        button.ForeColor = foreground;
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = buttonColor == spotifyGreen
            ? spotifyGreen
            : Color.FromArgb(85, 85, 85);
        button.FlatAppearance.BorderSize = 1;
        button.Font = new Font("Segoe UI", 9F, FontStyle.Bold, GraphicsUnit.Point);
        button.Cursor = Cursors.Hand;
        return button;
    }

    private void StartInstall(object sender, EventArgs eventArgs)
    {
        DialogResult answer = MessageBox.Show(
            "O instalador usara o Spotify 1.2.13.661 para manter o tema antigo. " +
            "Se houver uma versao mais nova, ela sera substituida. Deseja continuar?",
            "Confirmar instalacao",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Warning,
            MessageBoxDefaultButton.Button2
        );
        if (answer != DialogResult.Yes)
        {
            return;
        }

        string contentOption = hideContentRadio.Checked
            ? "-HidePodcasts"
            : "-KeepHomeContent";
        openSpotifyAfterSuccess = startSpotifyCheck.Checked;
        string startOption = "-DoNotStartSpotify";
        string arguments =
            "-Install -GuiMode -ForceDowngrade -RemoveStoreVersion " +
            contentOption + " " + startOption;

        StartInstallerProcess(arguments, "INSTALACAO EM ANDAMENTO");
    }

    private void StartRemoval(object sender, EventArgs eventArgs)
    {
        DialogResult answer = MessageBox.Show(
            "A remocao completa apaga o Spotify, login local, cache e preferencias. " +
            "Deseja remover tudo deste usuario?",
            "Confirmar remocao completa",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Warning,
            MessageBoxDefaultButton.Button2
        );
        if (answer != DialogResult.Yes)
        {
            return;
        }

        openSpotifyAfterSuccess = false;
        StartInstallerProcess(
            "-Uninstall -GuiMode -ConfirmCompleteRemoval",
            "REMOCAO EM ANDAMENTO"
        );
    }

    private void StartInstallerProcess(string operationArguments, string status)
    {
        if (busy)
        {
            return;
        }

        string systemRoot = Environment.GetEnvironmentVariable("SystemRoot");
        string powerShell = Path.Combine(
            systemRoot ?? String.Empty,
            "System32",
            "WindowsPowerShell",
            "v1.0",
            "powershell.exe"
        );
        if (!File.Exists(powerShell))
        {
            MessageBox.Show(
                "Windows PowerShell nao encontrado.",
                "Proxyum SpotX",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
            return;
        }

        SetBusy(true);
        logBox.Clear();
        progressBar.Style = ProgressBarStyle.Marquee;
        progressBar.MarqueeAnimationSpeed = 25;
        SetStatus(status, spotifyGreen);
        AppendLog("[SISTEMA] Iniciando operacao...");

        Process process = new Process();
        process.StartInfo.FileName = powerShell;
        process.StartInfo.Arguments =
            "-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"" +
            tempScript + "\" " + operationArguments;
        process.StartInfo.UseShellExecute = false;
        process.StartInfo.CreateNoWindow = true;
        process.StartInfo.WindowStyle = ProcessWindowStyle.Hidden;
        process.StartInfo.RedirectStandardOutput = true;
        process.StartInfo.RedirectStandardError = true;
        Encoding oemEncoding = Encoding.GetEncoding(
            CultureInfo.CurrentCulture.TextInfo.OEMCodePage
        );
        process.StartInfo.StandardOutputEncoding = oemEncoding;
        process.StartInfo.StandardErrorEncoding = oemEncoding;
        process.EnableRaisingEvents = true;
        process.OutputDataReceived += OnProcessOutput;
        process.ErrorDataReceived += OnProcessOutput;
        process.Exited += OnProcessExited;

        try
        {
            runningProcess = process;
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
        }
        catch (Exception exception)
        {
            process.Dispose();
            runningProcess = null;
            SetBusy(false);
            progressBar.Style = ProgressBarStyle.Continuous;
            progressBar.Value = 0;
            SetStatus("ERRO AO INICIAR", Color.OrangeRed);
            AppendLog("ERRO: " + exception.Message);
        }
    }

    private void OnProcessOutput(object sender, DataReceivedEventArgs eventArgs)
    {
        if (String.IsNullOrWhiteSpace(eventArgs.Data))
        {
            return;
        }

        AppendLog(eventArgs.Data);
        Match percentage = Regex.Match(eventArgs.Data, @"(?<!\d)(\d{1,3})%");
        if (percentage.Success)
        {
            int value;
            if (Int32.TryParse(percentage.Groups[1].Value, out value))
            {
                SetProgress(Math.Max(0, Math.Min(100, value)));
            }
        }
    }

    private void OnProcessExited(object sender, EventArgs eventArgs)
    {
        Process process = (Process)sender;
        process.WaitForExit();
        int exitCode = process.ExitCode;

        BeginInvoke((MethodInvoker)delegate
        {
            runningProcess = null;
            process.Dispose();
            SetBusy(false);
            progressBar.Style = ProgressBarStyle.Continuous;

            if (exitCode == 0)
            {
                progressBar.Value = 100;
                SetStatus("OPERACAO CONCLUIDA", spotifyGreen);
                AppendLog("[100%] Operacao concluida pelo Proxyum.");
                if (openSpotifyAfterSuccess)
                {
                    StartSpotifyFromGui();
                }
            }
            else
            {
                SetStatus("OPERACAO TERMINOU COM ERRO", Color.OrangeRed);
                AppendLog("ERRO: processo finalizado com codigo " + exitCode + ".");
            }
        });
    }

    private void StartSpotifyFromGui()
    {
        string roaming = Environment.GetFolderPath(
            Environment.SpecialFolder.ApplicationData
        );
        string local = Environment.GetFolderPath(
            Environment.SpecialFolder.LocalApplicationData
        );
        string[] candidates = new string[]
        {
            Path.Combine(roaming, "Spotify", "Spotify.exe"),
            Path.Combine(local, "Spotify", "Spotify.exe")
        };

        foreach (string candidate in candidates)
        {
            if (!File.Exists(candidate))
            {
                continue;
            }

            try
            {
                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.FileName = candidate;
                startInfo.WorkingDirectory = Path.GetDirectoryName(candidate);
                startInfo.UseShellExecute = true;
                startInfo.WindowStyle = ProcessWindowStyle.Normal;
                Process.Start(startInfo);
                AppendLog("[SPOTIFY] Aplicativo aberto automaticamente.");
                return;
            }
            catch (Exception exception)
            {
                AppendLog("ERRO ao abrir o Spotify: " + exception.Message);
                return;
            }
        }

        AppendLog("AVISO: Spotify.exe nao foi encontrado para abertura automatica.");
    }

    private void SetBusy(bool value)
    {
        busy = value;
        installButton.Enabled = !value;
        removeButton.Enabled = !value;
        exitButton.Enabled = !value;
        keepContentRadio.Enabled = !value;
        hideContentRadio.Enabled = !value;
        startSpotifyCheck.Enabled = !value;
    }

    private void SetStatus(string text, Color color)
    {
        if (InvokeRequired)
        {
            BeginInvoke((MethodInvoker)delegate { SetStatus(text, color); });
            return;
        }

        statusLabel.Text = "> " + text;
        statusLabel.ForeColor = color;
    }

    private void SetProgress(int value)
    {
        if (InvokeRequired)
        {
            BeginInvoke((MethodInvoker)delegate { SetProgress(value); });
            return;
        }

        progressBar.Style = ProgressBarStyle.Continuous;
        progressBar.Value = value;
    }

    private void AppendLog(string message)
    {
        if (InvokeRequired)
        {
            BeginInvoke((MethodInvoker)delegate { AppendLog(message); });
            return;
        }

        Color color = Color.FromArgb(205, 205, 205);
        if (message.IndexOf("ERRO", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            color = Color.OrangeRed;
        }
        else if (
            message.IndexOf("100%", StringComparison.OrdinalIgnoreCase) >= 0 ||
            message.IndexOf("confirmado", StringComparison.OrdinalIgnoreCase) >= 0 ||
            message.IndexOf("concluida", StringComparison.OrdinalIgnoreCase) >= 0
        )
        {
            color = spotifyGreen;
        }
        else if (message.IndexOf("AVISO", StringComparison.OrdinalIgnoreCase) >= 0)
        {
            color = Color.Gold;
        }

        logBox.SelectionStart = logBox.TextLength;
        logBox.SelectionLength = 0;
        logBox.SelectionColor = color;
        logBox.AppendText(message + Environment.NewLine);
        logBox.SelectionColor = logBox.ForeColor;
        logBox.ScrollToCaret();
    }

    private void ExtractInstaller()
    {
        Assembly assembly = Assembly.GetExecutingAssembly();
        using (Stream input = assembly.GetManifestResourceStream(ResourceName))
        {
            if (input == null)
            {
                throw new InvalidOperationException("O instalador interno nao foi encontrado.");
            }

            using (FileStream output = new FileStream(
                tempScript,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.Read
            ))
            {
                input.CopyTo(output);
            }
        }
    }

    private void OnFormClosing(object sender, FormClosingEventArgs eventArgs)
    {
        if (busy || (runningProcess != null && !runningProcess.HasExited))
        {
            eventArgs.Cancel = true;
            MessageBox.Show(
                "Aguarde a operacao terminar antes de fechar o instalador.",
                "Proxyum SpotX",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information
            );
            return;
        }

        DeleteVerifiedTempFile();
    }

    private void DeleteVerifiedTempFile()
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
            // Nao interromper o fechamento por causa da limpeza temporaria.
        }
    }
}
