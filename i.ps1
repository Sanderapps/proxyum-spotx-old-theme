Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ReleaseVersion = 'v1.5.0'
$ExpectedSha256 = '48AFA1AD1F6A73211EA6E65EF20A15A60E37A8B6E8C9673F6F0B05D3B7E93383'
$InstallerUrl = "https://github.com/Sanderapps/proxyum-spotx-old-theme/releases/download/$ReleaseVersion/Install-ProxyumSpotX.ps1"
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$tempInstaller = Join-Path $tempRoot ("ProxyumSpotX-Bootstrap-" + [Guid]::NewGuid().ToString('N') + '.ps1')

try {
    Write-Host '[Proxyum] Baixando o instalador...' -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $curlCommand = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curlCommand) {
        $curlPath = $curlCommand.Source
        & $curlPath -L --fail --retry 3 --connect-timeout 20 --max-time 180 --show-error $InstallerUrl -o $tempInstaller
        if ($LASTEXITCODE -ne 0) {
            throw "Falha no download (codigo $LASTEXITCODE)."
        }
    }
    else {
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $tempInstaller -UseBasicParsing -TimeoutSec 180
    }

    $actualHash = (Get-FileHash -LiteralPath $tempInstaller -Algorithm SHA256).Hash
    if (-not $actualHash.Equals($ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Falha de integridade. SHA-256 recebido: $actualHash"
    }

    Write-Host '[Proxyum] Download verificado. Abrindo o menu...' -ForegroundColor Green
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    & $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tempInstaller
    if ($LASTEXITCODE -ne 0) {
        throw "O instalador terminou com o codigo $LASTEXITCODE."
    }
}
catch {
    Write-Host ''
    Write-Host ("ERRO: " + $_.Exception.Message) -ForegroundColor Red
    throw
}
finally {
    $resolvedFile = [IO.Path]::GetFullPath($tempInstaller)
    $expectedPrefix = $tempRoot + '\ProxyumSpotX-Bootstrap-'

    if (-not $resolvedFile.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Recusa de seguranca ao limpar arquivo temporario: $resolvedFile"
    }

    if (Test-Path -LiteralPath $resolvedFile -PathType Leaf) {
        Remove-Item -LiteralPath $resolvedFile -Force
    }
}
