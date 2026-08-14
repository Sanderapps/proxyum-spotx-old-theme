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
    [switch]$KeepHomeContent,
    [switch]$StartSpotify,
    [switch]$DoNotStartSpotify,
    [switch]$AllowDefenderExclusions,
    [switch]$ForceDowngrade,
    [switch]$RemoveStoreVersion,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$InstallerVersion = '1.1.0'
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

function Write-Stage {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Number,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $stagePercentages = @{ 1 = 5; 2 = 20; 3 = 35; 4 = 45 }
    $percentage = $stagePercentages[$Number]
    Write-Progress `
        -Activity 'Proxyum SpotX Old Theme Installer' `
        -Status ("Etapa {0}/4: {1} ({2}%)" -f $Number, $Message, $percentage) `
        -PercentComplete $percentage
    Write-Host ("[Etapa {0}/4 | {1}%] {2}" -f $Number, $percentage, $Message) -ForegroundColor Cyan
}

function Get-InstalledSpotifyDesktop {
    $candidatePaths = @(
        (Join-Path $env:APPDATA 'Spotify\Spotify.exe'),
        (Join-Path $env:LOCALAPPDATA 'Spotify\Spotify.exe')
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            $item = Get-Item -LiteralPath $candidatePath
            return [PSCustomObject]@{
                Path = $item.FullName
                Version = $item.VersionInfo.FileVersion
            }
        }
    }

    return $null
}

function Confirm-InstallPlan {
    param(
        [Parameter(Mandatory = $true)]
        [Version]$TargetVersion,
        [switch]$ForceDowngrade,
        [switch]$RemoveStoreVersion,
        [switch]$DryRun
    )

    $installedDesktop = Get-InstalledSpotifyDesktop
    if ($installedDesktop) {
        Write-Host ("Spotify desktop encontrado: {0}" -f $installedDesktop.Version) -ForegroundColor White
        Write-Host ("Local: {0}" -f $installedDesktop.Path) -ForegroundColor DarkGray

        try {
            $installedVersion = [Version]$installedDesktop.Version
        }
        catch {
            $installedVersion = $null
            Write-Warning 'Nao foi possivel comparar a versao instalada. O SpotX fara a verificacao.'
        }

        if ($installedVersion -and $installedVersion -gt $TargetVersion -and -not $ForceDowngrade -and -not $DryRun) {
            Write-Warning ("A versao {0} sera rebaixada para {1}." -f $installedVersion, $TargetVersion)
            $confirmation = Read-Host 'Digite REBAIXAR para continuar ou pressione Enter para cancelar'
            if ($confirmation -cne 'REBAIXAR') {
                Write-Host 'Instalacao cancelada. Nenhum arquivo foi alterado.' -ForegroundColor Yellow
                exit 0
            }
        }
    }
    else {
        Write-Host 'Nenhuma instalacao desktop do Spotify foi encontrada.' -ForegroundColor DarkGray
    }

    $storePackage = Get-AppxPackage -Name SpotifyAB.SpotifyMusic -ErrorAction SilentlyContinue
    $storeRemovalConfirmed = [bool]$RemoveStoreVersion
    if ($storePackage -and -not $storeRemovalConfirmed -and -not $DryRun) {
        Write-Warning 'A versao Microsoft Store do Spotify foi encontrada e precisa ser removida.'
        $confirmation = Read-Host 'Digite REMOVER para continuar ou pressione Enter para cancelar'
        if ($confirmation -cne 'REMOVER') {
            Write-Host 'Instalacao cancelada. Nenhum arquivo foi alterado.' -ForegroundColor Yellow
            exit 0
        }
        $storeRemovalConfirmed = $true
    }

    return [PSCustomObject]@{
        RemoveStoreVersion = $storeRemovalConfirmed
    }
}

function Select-HomeContentPreference {
    param(
        [switch]$HidePodcasts,
        [switch]$KeepHomeContent,
        [switch]$DryRun
    )

    if ($HidePodcasts -and $KeepHomeContent) {
        throw 'Use somente uma opcao: -HidePodcasts ou -KeepHomeContent.'
    }

    if ($HidePodcasts) { return 'Hide' }
    if ($KeepHomeContent -or $DryRun) { return 'Keep' }

    Write-Host 'Conteudo da pagina inicial:' -ForegroundColor White
    Write-Host '  [1] Manter podcasts, episodios e audiolivros'
    Write-Host '  [2] Remover podcasts, episodios e audiolivros'

    do {
        $choice = Read-Host 'Escolha 1 ou 2'
    }
    while ($choice -notin @('1', '2'))

    if ($choice -eq '2') { return 'Hide' }
    return 'Keep'
}

function Complete-SpotifyLaunchChoice {
    param(
        [switch]$StartSpotify,
        [switch]$DoNotStartSpotify
    )

    if ($StartSpotify -and $DoNotStartSpotify) {
        throw 'Use somente uma opcao: -StartSpotify ou -DoNotStartSpotify.'
    }

    $shouldStart = [bool]$StartSpotify
    if (-not $StartSpotify -and -not $DoNotStartSpotify) {
        Write-Host ''
        $choice = Read-Host 'Deseja abrir o Spotify agora? [S/N]'
        $shouldStart = $choice -match '^(s|sim|y|yes)$'
    }

    if (-not $shouldStart) {
        Write-Host 'Spotify nao sera aberto.' -ForegroundColor DarkGray
        return
    }

    $spotifyPaths = @(
        (Join-Path $env:APPDATA 'Spotify\Spotify.exe'),
        (Join-Path $env:LOCALAPPDATA 'Spotify\Spotify.exe')
    )
    $spotifyExecutable = $spotifyPaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1

    if (-not $spotifyExecutable) {
        Write-Warning 'A instalacao terminou, mas Spotify.exe nao foi encontrado para abertura automatica.'
        return
    }

    Start-Process -FilePath $spotifyExecutable
    Write-Host 'Spotify aberto.' -ForegroundColor Green
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
Write-Stage -Number 1 -Message 'Verificando ambiente e instalacao existente'
Assert-Environment

Write-Warning 'Este perfil usa Spotify 1.2.13.661 (2023) para manter o tema antigo.'
Write-Warning 'O SpotX modifica arquivos assinados do Spotify. Use por sua conta e risco.'
Write-Host ''

$targetVersion = [Version]($SpotifyVersion -replace '\.g[0-9a-f]+$', '')
$installPlan = Confirm-InstallPlan `
    -TargetVersion $targetVersion `
    -ForceDowngrade:$ForceDowngrade `
    -RemoveStoreVersion:$RemoveStoreVersion `
    -DryRun:$DryRun
$homeContentPreference = Select-HomeContentPreference `
    -HidePodcasts:$HidePodcasts `
    -KeepHomeContent:$KeepHomeContent `
    -DryRun:$DryRun
Write-Host ''

[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$workDirectory = Join-Path ([IO.Path]::GetTempPath()) ("ProxyumSpotX-" + [Guid]::NewGuid().ToString('N'))
$downloadedScript = Join-Path $workDirectory 'spotx-run.ps1'

try {
    $null = New-Item -ItemType Directory -Path $workDirectory -Force

    Write-Stage -Number 2 -Message 'Baixando a revisao verificada do SpotX'
    $curlCommand = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curlCommand) {
        $curlPath = $curlCommand.Source
        & $curlPath -L --fail --retry 3 --connect-timeout 20 --max-time 180 --show-error $SpotXUrl -o $downloadedScript
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao baixar o SpotX com curl.exe (codigo $LASTEXITCODE)."
        }
    }
    else {
        Invoke-WebRequest -Uri $SpotXUrl -OutFile $downloadedScript -UseBasicParsing -TimeoutSec 180
    }

    Write-Stage -Number 3 -Message 'Validando a integridade SHA-256'
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

    if ($homeContentPreference -eq 'Hide') {
        $spotXArguments += '-podcasts_off'
    }
    else {
        $spotXArguments += '-podcasts_on'
    }

    if (-not $AllowDefenderExclusions) {
        $spotXArguments += '-defender_exclusions_off'
    }

    if ($installPlan.RemoveStoreVersion) {
        $spotXArguments += '-confirm_uninstall_ms_spoti'
    }

    if ($DryRun) {
        Write-Host ''
        Write-Host 'Dry run concluido. Nenhuma alteracao foi aplicada.' -ForegroundColor Yellow
        Write-Host ("Script: " + $SpotXUrl)
        Write-Host ("Argumentos: " + ($spotXArguments -join ' '))
        exit 0
    }

    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    Write-Stage -Number 4 -Message 'Instalando o Spotify e aplicando o Old theme'
    Write-Host 'Esta etapa pode levar alguns minutos. A janela nao esta travada.' -ForegroundColor Yellow

    if ($AllowDefenderExclusions) {
        Write-Host 'Modo interativo do Defender habilitado; responda aos prompts do SpotX.' -ForegroundColor Yellow
        & $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $downloadedScript @spotXArguments
        $spotXExitCode = $LASTEXITCODE
    }
    else {
        $processArguments = @(
            '-NoLogo',
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', $downloadedScript
        ) + $spotXArguments

        $spotXProcess = Start-Process `
            -FilePath $windowsPowerShell `
            -ArgumentList $processArguments `
            -NoNewWindow `
            -PassThru

        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        $nextHeartbeat = 0
        while (-not $spotXProcess.HasExited) {
            $elapsedSeconds = [int]$stopwatch.Elapsed.TotalSeconds
            $estimatedPercentage = [Math]::Min(95, 45 + [int]($elapsedSeconds / 6))
            Write-Progress `
                -Activity 'Proxyum SpotX Old Theme Installer' `
                -Status ("Instalacao em andamento: {0}% estimado, {1}s decorridos" -f $estimatedPercentage, $elapsedSeconds) `
                -PercentComplete $estimatedPercentage

            if ($elapsedSeconds -ge $nextHeartbeat) {
                Write-Host ("[Proxyum] Ainda trabalhando... {0}s decorridos" -f $elapsedSeconds) -ForegroundColor DarkGray
                $nextHeartbeat = $elapsedSeconds + 15
            }

            Start-Sleep -Seconds 1
            $spotXProcess.Refresh()
        }

        $stopwatch.Stop()
        $spotXProcess.WaitForExit()
        $spotXExitCode = $spotXProcess.ExitCode
        Write-Progress `
            -Activity 'Proxyum SpotX Old Theme Installer' `
            -Status 'Processo concluido (100%)' `
            -PercentComplete 100
        Write-Host ("[100%] Etapa concluida em {0}s." -f [int]$stopwatch.Elapsed.TotalSeconds) -ForegroundColor Green
        Write-Progress -Activity 'Proxyum SpotX Old Theme Installer' -Completed
    }

    if ($spotXExitCode -ne 0) {
        throw "O SpotX terminou com o codigo $spotXExitCode."
    }

    Write-Host ''
    Write-Host 'Instalacao concluida pelo Proxyum Installer.' -ForegroundColor Green
    Complete-SpotifyLaunchChoice `
        -StartSpotify:$StartSpotify `
        -DoNotStartSpotify:$DoNotStartSpotify
}
catch {
    Write-Progress -Activity 'Proxyum SpotX Old Theme Installer' -Completed
    Write-Host ''
    Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    Remove-VerifiedTempDirectory -Path $workDirectory
}

