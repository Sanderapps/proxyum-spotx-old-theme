[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installerPath = Join-Path $repositoryRoot 'Install-ProxyumSpotX.ps1'
$bootstrapPath = Join-Path $repositoryRoot 'i.ps1'
$batchPath = Join-Path $repositoryRoot 'Instalar-ProxyumSpotX.bat'
$launcherSourcePath = Join-Path $repositoryRoot 'src\ProxyumSpotXLauncher.cs'
$buildScriptPath = Join-Path $repositoryRoot 'build\Build-Exe.ps1'
$guiSourcePath = Join-Path $repositoryRoot 'src\ProxyumSpotXGui.cs'
$guiBuildScriptPath = Join-Path $repositoryRoot 'build\Build-Gui.ps1'
$iconBuildScriptPath = Join-Path $repositoryRoot 'build\Build-Icon.ps1'
$iconPath = Join-Path $repositoryRoot 'assets\ProxyumSpotX.ico'
$logoPath = Join-Path $repositoryRoot 'assets\LOGO INSTALLER.png'
$virusTotalScriptPath = Join-Path $repositoryRoot 'scripts\Scan-VirusTotal.ps1'
$virusTotalWorkflowPath = Join-Path $repositoryRoot '.github\workflows\virustotal.yml'
$cmdPath = Join-Path $repositoryRoot 'Install.cmd'

if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw 'Install-ProxyumSpotX.ps1 nao encontrado.'
}

if (-not (Test-Path -LiteralPath $bootstrapPath -PathType Leaf)) {
    throw 'i.ps1 nao encontrado.'
}

if (-not (Test-Path -LiteralPath $batchPath -PathType Leaf)) {
    throw 'Instalar-ProxyumSpotX.bat nao encontrado.'
}

if (-not (Test-Path -LiteralPath $launcherSourcePath -PathType Leaf)) {
    throw 'Codigo-fonte do executavel nao encontrado.'
}

if (-not (Test-Path -LiteralPath $buildScriptPath -PathType Leaf)) {
    throw 'Script de compilacao do executavel nao encontrado.'
}

if (-not (Test-Path -LiteralPath $guiSourcePath -PathType Leaf)) {
    throw 'Codigo-fonte da interface grafica nao encontrado.'
}

if (-not (Test-Path -LiteralPath $guiBuildScriptPath -PathType Leaf)) {
    throw 'Script de compilacao da interface grafica nao encontrado.'
}

foreach ($visualAsset in @($iconBuildScriptPath, $iconPath, $logoPath)) {
    if (-not (Test-Path -LiteralPath $visualAsset -PathType Leaf)) {
        throw "Recurso visual obrigatorio nao encontrado: $visualAsset"
    }
}

if (-not (Test-Path -LiteralPath $virusTotalScriptPath -PathType Leaf)) {
    throw 'Script de analise VirusTotal nao encontrado.'
}

if (-not (Test-Path -LiteralPath $virusTotalWorkflowPath -PathType Leaf)) {
    throw 'Workflow do VirusTotal nao encontrado.'
}

if (-not (Test-Path -LiteralPath $cmdPath -PathType Leaf)) {
    throw 'Install.cmd nao encontrado.'
}

$tokens = $null
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile(
    $installerPath,
    [ref]$tokens,
    [ref]$parseErrors
)

if ($parseErrors.Count -gt 0) {
    $messages = $parseErrors | ForEach-Object { $_.Message }
    throw ("Erros de sintaxe: " + ($messages -join '; '))
}

$bootstrapTokens = $null
$bootstrapParseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile(
    $bootstrapPath,
    [ref]$bootstrapTokens,
    [ref]$bootstrapParseErrors
)
if ($bootstrapParseErrors.Count -gt 0) {
    $messages = $bootstrapParseErrors | ForEach-Object { $_.Message }
    throw ("Erros de sintaxe no i.ps1: " + ($messages -join '; '))
}

$installerContent = Get-Content -LiteralPath $installerPath -Raw
$requiredValues = @(
    '1.2.13.661.ga588f749',
    '2a179d3cf0d207cc7a8b4401eaea88b3c290a30e',
    'BCF113D289C8AAF5990887D36AF5D6AE7E1D8FA183A68A819D5892CB99B84AB8',
    '-block_update_on',
    '-defender_exclusions_off',
    'Ainda trabalhando',
    '-ForceDowngrade',
    '-RemoveStoreVersion',
    'PercentComplete',
    '100%',
    'Escolha 1 ou 2',
    'Deseja abrir o Spotify agora?',
    'Spotify aberto e processo confirmado.',
    'Assert-SpotifyUiIntegrity',
    'Apps\xpui.spa nao foi criada',
    'Resultado confirmado pelos arquivos instalados.',
    '-KeepHomeContent',
    '-DoNotStartSpotify',
    'REMOVER COMPLETAMENTE',
    'Digite REMOVER TUDO para confirmar',
    'Remove-SafeSpotifyDirectory',
    'SpotifyAB.SpotifyMusic',
    '[switch]$Uninstall',
    '[switch]$ConfirmCompleteRemoval',
    '[switch]$GuiMode',
    '$proxyumBanner',
    '$spotXBanner',
    'Write-TwoColorBanner'
)

foreach ($requiredValue in $requiredValues) {
    if (-not $installerContent.Contains($requiredValue)) {
        throw "Valor obrigatorio ausente: $requiredValue"
    }
}

$bootstrapContent = Get-Content -LiteralPath $bootstrapPath -Raw
$installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
$expectedHashLine = '$ExpectedSha256 = ''' + $installerHash + ''''
if (-not $bootstrapContent.Contains($expectedHashLine)) {
    throw 'SHA-256 do instalador nao corresponde ao valor embutido no i.ps1.'
}
$expectedReleaseLine = '$ReleaseVersion = ''v1.5.3'''
if (-not $bootstrapContent.Contains($expectedReleaseLine)) {
    throw 'i.ps1 nao aponta para a release v1.5.3.'
}
if ($bootstrapContent.Contains('[CmdletBinding()]') -or $bootstrapContent -match '(?m)^\s*param\s*\(') {
    throw 'i.ps1 nao pode ter CmdletBinding ou param no topo porque sera executado com iex.'
}

$bootstrapBytes = [IO.File]::ReadAllBytes($bootstrapPath)
$hasUtf8Bom =
    $bootstrapBytes.Length -ge 3 -and
    $bootstrapBytes[0] -eq 0xEF -and
    $bootstrapBytes[1] -eq 0xBB -and
    $bootstrapBytes[2] -eq 0xBF
if ($hasUtf8Bom) {
    throw 'i.ps1 deve ser UTF-8 sem BOM para funcionar com irm | iex no Windows PowerShell 5.1.'
}

$batchContent = Get-Content -LiteralPath $batchPath -Raw
if (-not $batchContent.Contains('releases/latest/download/i.ps1')) {
    throw 'O instalador .bat nao chama o i.ps1 publicado.'
}
if (-not $batchContent.Contains('powershell.exe')) {
    throw 'O instalador .bat nao chama o Windows PowerShell.'
}
$batchBytes = [IO.File]::ReadAllBytes($batchPath)
$batchHasBom =
    $batchBytes.Length -ge 3 -and
    $batchBytes[0] -eq 0xEF -and
    $batchBytes[1] -eq 0xBB -and
    $batchBytes[2] -eq 0xBF
if ($batchHasBom) {
    throw 'Instalar-ProxyumSpotX.bat nao pode possuir BOM.'
}

$launcherSource = Get-Content -LiteralPath $launcherSourcePath -Raw
foreach ($requiredLauncherValue in @(
    'ProxyumSpotX.InstallProxyumSpotX.ps1',
    'GetManifestResourceStream',
    'ExecutionPolicy Bypass',
    'DeleteVerifiedTempFile'
)) {
    if (-not $launcherSource.Contains($requiredLauncherValue)) {
        throw "Valor obrigatorio ausente do executavel: $requiredLauncherValue"
    }
}

$buildTokens = $null
$buildParseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile(
    $buildScriptPath,
    [ref]$buildTokens,
    [ref]$buildParseErrors
)
if ($buildParseErrors.Count -gt 0) {
    $messages = $buildParseErrors | ForEach-Object { $_.Message }
    throw ("Erros de sintaxe no Build-Exe.ps1: " + ($messages -join '; '))
}
$buildContent = Get-Content -LiteralPath $buildScriptPath -Raw
if (
    -not $buildContent.Contains('/target:exe') -or
    -not $buildContent.Contains('/win32icon:') -or
    -not $buildContent.Contains('/resource:') -or
    -not $buildContent.Contains('GetManifestResourceNames')
) {
    throw 'Build-Exe.ps1 nao compila o executavel com o instalador embutido.'
}

$iconBuildTokens = $null
$iconBuildParseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile(
    $iconBuildScriptPath,
    [ref]$iconBuildTokens,
    [ref]$iconBuildParseErrors
)
if ($iconBuildParseErrors.Count -gt 0) {
    $messages = $iconBuildParseErrors | ForEach-Object { $_.Message }
    throw ("Erros de sintaxe no Build-Icon.ps1: " + ($messages -join '; '))
}
$iconHeader = [IO.File]::ReadAllBytes($iconPath) | Select-Object -First 6
if (
    $iconHeader.Count -ne 6 -or
    $iconHeader[0] -ne 0 -or
    $iconHeader[1] -ne 0 -or
    $iconHeader[2] -ne 1 -or
    $iconHeader[3] -ne 0 -or
    $iconHeader[4] -ne 9 -or
    $iconHeader[5] -ne 0
) {
    throw 'ProxyumSpotX.ico nao possui nove imagens de icone validas.'
}

$guiSource = Get-Content -LiteralPath $guiSourcePath -Raw
foreach ($requiredGuiValue in @(
    'System.Windows.Forms',
    'ProxyumSpotX.InstallProxyumSpotX.ps1',
    'INSTALAR OU REPARAR',
    'REMOVER COMPLETAMENTE',
    '-ConfirmCompleteRemoval',
    '-GuiMode',
    'StandardOutputEncoding',
    'StartSpotifyFromGui',
    'ProxyumSpotX.Logo.png',
    'LoadLogoImage',
    'CreateNoWindow = true'
)) {
    if (-not $guiSource.Contains($requiredGuiValue)) {
        throw "Valor obrigatorio ausente da interface: $requiredGuiValue"
    }
}

$guiBuildTokens = $null
$guiBuildParseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile(
    $guiBuildScriptPath,
    [ref]$guiBuildTokens,
    [ref]$guiBuildParseErrors
)
if ($guiBuildParseErrors.Count -gt 0) {
    $messages = $guiBuildParseErrors | ForEach-Object { $_.Message }
    throw ("Erros de sintaxe no Build-Gui.ps1: " + ($messages -join '; '))
}

$virusTotalTokens = $null
$virusTotalParseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile(
    $virusTotalScriptPath,
    [ref]$virusTotalTokens,
    [ref]$virusTotalParseErrors
)
if ($virusTotalParseErrors.Count -gt 0) {
    $messages = $virusTotalParseErrors | ForEach-Object { $_.Message }
    throw ("Erros de sintaxe no Scan-VirusTotal.ps1: " + ($messages -join '; '))
}
$virusTotalContent = Get-Content -LiteralPath $virusTotalScriptPath -Raw
foreach ($requiredVirusTotalValue in @(
    'https://www.virustotal.com/api/v3/files',
    'https://www.virustotal.com/api/v3/analyses/',
    'virustotal-report:start',
    'virustotal-report:end',
    'VIRUSTOTAL_API_KEY',
    'last_analysis_stats',
    '$total = $malicious + $suspicious + $harmless + $undetected'
)) {
    if (-not $virusTotalContent.Contains($requiredVirusTotalValue)) {
        throw "Valor obrigatorio ausente da automacao VirusTotal: $requiredVirusTotalValue"
    }
}

$virusTotalWorkflow = Get-Content -LiteralPath $virusTotalWorkflowPath -Raw
foreach ($requiredWorkflowValue in @(
    'types: [published]',
    'workflow_dispatch:',
    'secrets.VIRUSTOTAL_API_KEY',
    'ProxyumSpotX-Setup.exe',
    'Scan-VirusTotal.ps1',
    'contents: write'
)) {
    if (-not $virusTotalWorkflow.Contains($requiredWorkflowValue)) {
        throw "Valor obrigatorio ausente do workflow VirusTotal: $requiredWorkflowValue"
    }
}
$guiBuildContent = Get-Content -LiteralPath $guiBuildScriptPath -Raw
if (
    -not $guiBuildContent.Contains('/target:winexe') -or
    -not $guiBuildContent.Contains('System.Windows.Forms.dll') -or
    -not $guiBuildContent.Contains('/win32icon:') -or
    -not $guiBuildContent.Contains('ProxyumSpotX.Logo.png') -or
    -not $guiBuildContent.Contains('/resource:')
) {
    throw 'Build-Gui.ps1 nao compila a interface grafica corretamente.'
}

$cmdContent = Get-Content -LiteralPath $cmdPath -Raw
if (-not $cmdContent.Contains('Install-ProxyumSpotX.ps1')) {
    throw 'Install.cmd nao chama o instalador PowerShell.'
}

$readmePath = Join-Path $repositoryRoot 'README.md'
$readmeContent = Get-Content -LiteralPath $readmePath -Raw
$codeFence = (([string][char]96) * 3) + 'powershell'
$installerBlocks = [regex]::Matches($readmeContent, [regex]::Escape($codeFence)).Count
if ($installerBlocks -ne 1) {
    throw "README deve ter exatamente um bloco powershell; encontrado: $installerBlocks"
}
if (-not $readmeContent.Contains('releases/latest/download/i.ps1|iex')) {
    throw 'Comando remoto curto ausente do README.'
}
if (-not $readmeContent.Contains('releases/latest/download/Instalar-ProxyumSpotX.bat')) {
    throw 'Link do instalador .bat ausente do README.'
}
if (-not $readmeContent.Contains('releases/latest/download/ProxyumSpotX-Installer.exe')) {
    throw 'Link do instalador .exe ausente do README.'
}
if (-not $readmeContent.Contains('releases/latest/download/ProxyumSpotX-Setup.exe')) {
    throw 'Link do instalador visual ausente do README.'
}
if (
    -not $readmeContent.Contains('<!-- virustotal-report:start -->') -or
    -not $readmeContent.Contains('<!-- virustotal-report:end -->')
) {
    throw 'Marcadores do relatorio VirusTotal ausentes do README.'
}

Write-Host 'Validacao local concluida com sucesso.' -ForegroundColor Green
