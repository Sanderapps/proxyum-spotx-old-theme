[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$installerPath = Join-Path $repositoryRoot 'Install-ProxyumSpotX.ps1'
$cmdPath = Join-Path $repositoryRoot 'Install.cmd'

if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    throw 'Install-ProxyumSpotX.ps1 nao encontrado.'
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
    '-KeepHomeContent',
    '-DoNotStartSpotify',
    'Remover o Proxyum SpotX completamente',
    'Digite REMOVER TUDO para confirmar',
    'Remove-SafeSpotifyDirectory',
    'SpotifyAB.SpotifyMusic',
    '[switch]$Uninstall'
)

foreach ($requiredValue in $requiredValues) {
    if (-not $installerContent.Contains($requiredValue)) {
        throw "Valor obrigatorio ausente: $requiredValue"
    }
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

Write-Host 'Validacao local concluida com sucesso.' -ForegroundColor Green

