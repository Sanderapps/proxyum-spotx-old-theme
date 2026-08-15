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
$sourcePath = Join-Path $repositoryRoot 'src\ProxyumSpotXLauncher.cs'
$installerPath = Join-Path $repositoryRoot 'Install-ProxyumSpotX.ps1'
$iconPath = Join-Path $repositoryRoot 'assets\ProxyumSpotX.ico'
$outputPath = Join-Path $OutputDirectory 'ProxyumSpotX-Installer.exe'
$resourceName = 'ProxyumSpotX.InstallProxyumSpotX.ps1'

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
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw 'Codigo-fonte do inicializador nao encontrado.'
}
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw 'Instalador PowerShell nao encontrado.'
}
if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf)) {
    throw 'Icone do executavel nao encontrado.'
}

$null = New-Item -ItemType Directory -Path $OutputDirectory -Force

$compilerArguments = @(
    '/nologo',
    '/target:exe',
    '/platform:anycpu',
    '/optimize+',
    ('/win32icon:' + $iconPath),
    ('/out:' + $outputPath),
    ('/resource:' + $installerPath + ',' + $resourceName),
    $sourcePath
)

& $compiler @compilerArguments
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao compilar o executavel (codigo $LASTEXITCODE)."
}

$assembly = [Reflection.Assembly]::LoadFile([IO.Path]::GetFullPath($outputPath))
if ($resourceName -notin $assembly.GetManifestResourceNames()) {
    throw 'O executavel compilado nao possui o instalador embutido.'
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
    throw 'O instalador embutido nao corresponde ao arquivo original.'
}

$hash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
Write-Host ("Executavel criado: {0}" -f $outputPath) -ForegroundColor Green
Write-Host ("SHA-256: {0}" -f $hash) -ForegroundColor Green
Write-Host ("Instalador embutido: {0}" -f $embeddedHash) -ForegroundColor Green
