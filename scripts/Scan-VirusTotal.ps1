[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [Parameter(Mandatory = $true)]
    [string]$ApiKey,

    [Parameter(Mandatory = $true)]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [ValidateRange(20, 300)]
    [int]$PollSeconds = 30,

    [ValidateRange(1, 60)]
    [int]$TimeoutMinutes = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion -lt [Version]'7.0') {
    throw 'A automacao do VirusTotal requer PowerShell 7 ou superior.'
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw 'O segredo VIRUSTOTAL_API_KEY nao foi configurado no GitHub.'
}

$resolvedFile = (Resolve-Path -LiteralPath $FilePath).Path
$resolvedRepository = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$file = Get-Item -LiteralPath $resolvedFile
if ($file.Length -gt 32MB) {
    throw 'O arquivo ultrapassa 32 MB e requer o endpoint de upload para arquivos grandes.'
}

$sha256 = (Get-FileHash -LiteralPath $resolvedFile -Algorithm SHA256).Hash.ToLowerInvariant()
$headers = @{ 'x-apikey' = $ApiKey }
$fileEndpoint = "https://www.virustotal.com/api/v3/files/$sha256"
$analysis = $null
$alreadyKnown = $false

try {
    $null = Invoke-RestMethod -Method Get -Uri $fileEndpoint -Headers $headers
    $alreadyKnown = $true
}
catch {
    $statusCode = $null
    if ($null -ne $_.Exception.Response) {
        $statusCode = [int]$_.Exception.Response.StatusCode
    }
    if ($statusCode -ne 404) {
        throw
    }
}

if ($alreadyKnown) {
    Write-Host 'Arquivo ja conhecido pelo VirusTotal; solicitando nova analise.'
    $analysis = Invoke-RestMethod `
        -Method Post `
        -Uri "$fileEndpoint/analyse" `
        -Headers $headers
}
else {
    Write-Host 'Enviando o instalador publicado ao VirusTotal.'
    $analysis = Invoke-RestMethod `
        -Method Post `
        -Uri 'https://www.virustotal.com/api/v3/files' `
        -Headers $headers `
        -Form @{ file = $file }
}

$analysisId = [string]$analysis.data.id
if ([string]::IsNullOrWhiteSpace($analysisId)) {
    throw 'O VirusTotal nao retornou um identificador de analise.'
}

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$analysisResult = $null
do {
    if ((Get-Date) -ge $deadline) {
        throw "A analise do VirusTotal nao terminou em $TimeoutMinutes minutos."
    }

    Start-Sleep -Seconds $PollSeconds
    $analysisResult = Invoke-RestMethod `
        -Method Get `
        -Uri "https://www.virustotal.com/api/v3/analyses/$analysisId" `
        -Headers $headers
    $status = [string]$analysisResult.data.attributes.status
    Write-Host ("Status da analise: {0}" -f $status)
} while ($status -ne 'completed')

$report = Invoke-RestMethod -Method Get -Uri $fileEndpoint -Headers $headers
$stats = $report.data.attributes.last_analysis_stats
$malicious = [int]$stats.malicious
$suspicious = [int]$stats.suspicious
$harmless = [int]$stats.harmless
$undetected = [int]$stats.undetected
$flagged = $malicious + $suspicious
$total = $malicious + $suspicious + $harmless + $undetected

$reportUrl = "https://www.virustotal.com/gui/file/$sha256"
$utcTimestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss ''UTC''')
$startMarker = '<!-- virustotal-report:start -->'
$endMarker = '<!-- virustotal-report:end -->'
$readmePath = Join-Path $resolvedRepository 'README.md'
$readme = Get-Content -LiteralPath $readmePath -Raw
$startIndex = $readme.IndexOf($startMarker, [StringComparison]::Ordinal)
$endIndex = $readme.IndexOf($endMarker, [StringComparison]::Ordinal)
if ($startIndex -lt 0 -or $endIndex -le $startIndex) {
    throw 'Os marcadores do relatorio VirusTotal nao foram encontrados no README.'
}

$sectionLines = @(
    $startMarker,
    '## Analise de seguranca',
    '',
    "O instalador visual da versao **$ReleaseTag** foi analisado automaticamente pelo VirusTotal.",
    '',
    "**Resultado:** $flagged de $total mecanismos marcaram o arquivo como malicioso ou suspeito.",
    '',
    "[Ver o relatorio completo no VirusTotal]($reportUrl)",
    '',
    "`SHA-256: $sha256`  ",
    "Ultima analise: $utcTimestamp.",
    '',
    'O VirusTotal agrega resultados de varios mecanismos e nao substitui uma auditoria completa do codigo.',
    $endMarker
)
$section = $sectionLines -join "`n"
$suffixIndex = $endIndex + $endMarker.Length
$updatedReadme =
    $readme.Substring(0, $startIndex) +
    $section +
    $readme.Substring($suffixIndex)
[IO.File]::WriteAllText(
    $readmePath,
    $updatedReadme,
    [Text.UTF8Encoding]::new($false)
)

$reportDirectory = Split-Path -Parent $ReportPath
if (-not [string]::IsNullOrWhiteSpace($reportDirectory)) {
    $null = New-Item -ItemType Directory -Path $reportDirectory -Force
}
$reportSummary = [ordered]@{
    release = $ReleaseTag
    file = $file.Name
    sha256 = $sha256
    scanned_at = $utcTimestamp
    virustotal_url = $reportUrl
    stats = [ordered]@{
        malicious = $malicious
        suspicious = $suspicious
        harmless = $harmless
        undetected = $undetected
        total = $total
    }
}
$reportSummary |
    ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath $ReportPath -Encoding utf8NoBOM

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "sha256=$sha256"
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "report_url=$reportUrl"
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "flagged=$flagged"
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "total=$total"
}

Write-Host ("Relatorio concluido: {0}/{1} marcacoes." -f $flagged, $total) -ForegroundColor Green
Write-Host $reportUrl
