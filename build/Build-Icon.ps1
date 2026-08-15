[CmdletBinding()]
param(
    [string]$SourcePng,
    [string]$OutputIcon
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SourcePng)) {
    $SourcePng = Join-Path $repositoryRoot 'assets\LOGO INSTALLER.png'
}
if ([string]::IsNullOrWhiteSpace($OutputIcon)) {
    $OutputIcon = Join-Path $repositoryRoot 'assets\ProxyumSpotX.ico'
}
if (-not (Test-Path -LiteralPath $SourcePng -PathType Leaf)) {
    throw 'PNG de origem do icone nao encontrado.'
}

Add-Type -AssemblyName System.Drawing
$sizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
$frames = New-Object 'System.Collections.Generic.List[byte[]]'
$sourceImage = [Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourcePng))

try {
    foreach ($size in $sizes) {
        $bitmap = New-Object Drawing.Bitmap(
            $size,
            $size,
            [Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        try {
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([Drawing.Color]::Transparent)
                $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.DrawImage($sourceImage, 0, 0, $size, $size)
            }
            finally {
                $graphics.Dispose()
            }

            $memory = New-Object IO.MemoryStream
            try {
                $bitmap.Save($memory, [Drawing.Imaging.ImageFormat]::Png)
                $frames.Add($memory.ToArray())
            }
            finally {
                $memory.Dispose()
            }
        }
        finally {
            $bitmap.Dispose()
        }
    }
}
finally {
    $sourceImage.Dispose()
}

$outputDirectory = Split-Path -Parent $OutputIcon
$null = New-Item -ItemType Directory -Path $outputDirectory -Force
$stream = New-Object IO.FileStream(
    $OutputIcon,
    [IO.FileMode]::Create,
    [IO.FileAccess]::Write,
    [IO.FileShare]::None
)
$writer = New-Object IO.BinaryWriter($stream)
try {
    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]$frames.Count)

    $offset = 6 + (16 * $frames.Count)
    for ($index = 0; $index -lt $frames.Count; $index++) {
        $size = $sizes[$index]
        $dimension = if ($size -eq 256) { [byte]0 } else { [byte]$size }
        $frame = $frames[$index]

        $writer.Write($dimension)
        $writer.Write($dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$frame.Length)
        $writer.Write([UInt32]$offset)
        $offset += $frame.Length
    }

    foreach ($frame in $frames) {
        $writer.Write($frame)
    }
}
finally {
    $writer.Dispose()
    $stream.Dispose()
}

$hash = (Get-FileHash -LiteralPath $OutputIcon -Algorithm SHA256).Hash
Write-Host ("Icone criado: {0}" -f $OutputIcon) -ForegroundColor Green
Write-Host ("Tamanhos: {0}" -f ($sizes -join ', ')) -ForegroundColor Green
Write-Host ("SHA-256: {0}" -f $hash) -ForegroundColor Green
