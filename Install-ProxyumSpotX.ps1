<#
.SYNOPSIS
    Instalador Proxyum para Spotify 1.2.13.661 com o perfil Old theme do SpotX.

.DESCRIPTION
    Baixa uma revisao fixa do instalador SpotX, valida seu SHA-256 e executa
    somente depois da verificacao. Por padrao, preserva podcasts, bloqueia
    atualizacoes do Spotify e impede que o SpotX crie exclusoes no Defender.

.NOTES
    Autor do instalador: Proxyum
    Dependencia externa: SpotX (licenca MIT)
#>

[CmdletBinding()]
param(
    [switch]$HidePodcasts,
    [switch]$StartSpotify,
    [switch]$AllowDefenderExclusions,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InstallerVersion = '1.0.0'
$SpotifyVersion = '1.2.13.661.ga588f749'
$SpotXCommit = '2a179d3cf0d207cc7a8b4401eaea88b3c290a30e'
$SpotXUrl = "https://raw.githubusercontent.com/SpotX-Official/SpotX/$SpotXCommit/run.ps1"
$ExpectedSpotXSha256 = 'BCF113D289C8AAF5990887D36AF5D6AE7E1D8FA183A68A819D5892CB99B84AB8'

function Write-ProxyumHeader {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host "  Proxyum SpotX Old Theme Installer v$InstallerVersion" -ForegroundColor Cyan
    Write-Host "  Spotify alvo: $SpotifyVersion" -ForegroundColor White
    Write-Host '  Autor: Proxyum' -ForegroundColor White
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Assert-Environment {
    if ($env:OS -ne 'Windows_NT') {
        throw 'Este instalador funciona somente no Windows.'
    }

    if ($PSVersionTable.PSVersion -lt [Version]'5.1') {
        throw 'PowerShell 5.1 ou superior e necessario.'
    }
}

function Remove-VerifiedTempDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $expectedPrefix = $tempRoot + '\ProxyumSpotX-'

    if (-not $resolvedPath.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Recusa de seguranca: caminho temporario inesperado: $resolvedPath"
    }

    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

Write-ProxyumHeader
Assert-Environment

Write-Warning 'Este perfil usa Spotify 1.2.13.661 (2023) para manter o tema antigo.'
Write-Warning 'O SpotX modifica arquivos assinados do Spotify. Use por sua conta e risco.'
Write-Host ''

[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$workDirectory = Join-Path ([IO.Path]::GetTempPath()) ("ProxyumSpotX-" + [Guid]::NewGuid().ToString('N'))
$downloadedScript = Join-Path $workDirectory 'spotx-run.ps1'

try {
    $null = New-Item -ItemType Directory -Path $workDirectory -Force

    Write-Host 'Baixando a revisao verificada do SpotX...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri $SpotXUrl -OutFile $downloadedScript -UseBasicParsing

    $actualHash = (Get-FileHash -LiteralPath $downloadedScript -Algorithm SHA256).Hash
    if (-not $actualHash.Equals($ExpectedSpotXSha256, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Falha de integridade. Esperado: $ExpectedSpotXSha256; recebido: $actualHash"
    }

    Write-Host 'SHA-256 confirmado.' -ForegroundColor Green

    $spotXArguments = @(
        '-v', $SpotifyVersion,
        '-confirm_spoti_recomended_over',
        '-block_update_on',
        '-no_pause',
        '-language', 'pt'
    )

    if ($HidePodcasts) {
        $spotXArguments += '-podcasts_off'
    }
    else {
        $spotXArguments += '-podcasts_on'
    }

    if (-not $AllowDefenderExclusions) {
        $spotXArguments += '-defender_exclusions_off'
    }

    if ($StartSpotify) {
        $spotXArguments += '-start_spoti'
    }

    if ($DryRun) {
        Write-Host ''
        Write-Host 'Dry run concluido. Nenhuma alteracao foi aplicada.' -ForegroundColor Yellow
        Write-Host ("Script: " + $SpotXUrl)
        Write-Host ("Argumentos: " + ($spotXArguments -join ' '))
        exit 0
    }

    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    Write-Host 'Executando o perfil Old theme...' -ForegroundColor Cyan
    & $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $downloadedScript @spotXArguments

    if ($LASTEXITCODE -ne 0) {
        throw "O SpotX terminou com o codigo $LASTEXITCODE."
    }

    Write-Host ''
    Write-Host 'Instalacao concluida pelo Proxyum Installer.' -ForegroundColor Green
}
catch {
    Write-Host ''
    Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    Remove-VerifiedTempDirectory -Path $workDirectory
}

