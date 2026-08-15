[CmdletBinding()]
param(
    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot 'artifacts'
}
$sourcePath = Join-Path $repositoryRoot 'src\ProxyumSpotXGui.cs'
$installerPath = Join-Path $repositoryRoot 'Install-ProxyumSpotX.ps1'
$iconPath = Join-Path $repositoryRoot 'assets\ProxyumSpotX.ico'
$logoPath = Join-Path $repositoryRoot 'assets\LOGO INSTALLER.png'
$outputPath = Join-Path $OutputDirectory 'ProxyumSpotX-Setup.exe'
$resourceName = 'ProxyumSpotX.InstallProxyumSpotX.ps1'
$logoResourceName = 'ProxyumSpotX.Logo.png'

$compilerCandidates = @(
    (Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)
$compiler = $compilerCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1

if (-not $compiler) {
    throw 'Compilador C# do .NET Framework nao encontrado.'
}
if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    throw 'Icone da interface grafica nao encontrado.'
}
if (-not (Test-Path -LiteralPath $logoPath -PathType Leaf)) {
    throw 'Logo da interface grafica nao encontrado.'
}

$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$compilerArguments = @(
    '/nologo',
    '/target:winexe',
    '/platform:anycpu',
    '/optimize+',
    '/reference:System.Windows.Forms.dll',
    '/reference:System.Drawing.dll',
    ('/win32icon:' + $iconPath),
    ('/out:' + $outputPath),
    ('/resource:' + $installerPath + ',' + $resourceName),
    ('/resource:' + $logoPath + ',' + $logoResourceName),
    $sourcePath
)

& $compiler @compilerArguments
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao compilar a interface grafica (codigo $LASTEXITCODE)."
}

$assembly = [Reflection.Assembly]::LoadFile([IO.Path]::GetFullPath($outputPath))
if ($resourceName -notin $assembly.GetManifestResourceNames()) {
    throw 'A interface compilada nao possui o instalador embutido.'
}
if ($logoResourceName -notin $assembly.GetManifestResourceNames()) {
    throw 'A interface compilada nao possui o logo embutido.'
}

$resourceStream = $assembly.GetManifestResourceStream($resourceName)
try {
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $embeddedHash = ([BitConverter]::ToString(
            $sha256.ComputeHash($resourceStream)
        )).Replace('-', '')
    }
    finally {
        $sha256.Dispose()
    }
}
finally {
    $resourceStream.Dispose()
}

$installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
if (-not $embeddedHash.Equals($installerHash, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'O instalador embutido na interface nao corresponde ao original.'
}

$hash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
Write-Host ("Interface criada: {0}" -f $outputPath) -ForegroundColor Green
Write-Host ("SHA-256: {0}" -f $hash) -ForegroundColor Green
Write-Host ("Instalador embutido: {0}" -f $embeddedHash) -ForegroundColor Green
