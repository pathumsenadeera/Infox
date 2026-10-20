# Run on Windows: powershell -File tool/generate_app_icons.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$appRoot = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Join-Path $appRoot 'assets/branding/app_icon.png'))
function Write-IconPng([string]$relativePath, [int]$size, [double]$scale = 1.0) {
    $target = Join-Path $appRoot $relativePath
    [System.IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
    $bitmap = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $edge = [int][Math]::Round($size * $scale)
        $offset = [int](($size - $edge) / 2)
        $graphics.DrawImage($source, [System.Drawing.Rectangle]::new($offset, $offset, $edge, $edge))
        $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
try {
    $densities = @{mdpi=1; hdpi=1.5; xhdpi=2; xxhdpi=3; xxxhdpi=4}
    foreach ($density in $densities.Keys) {
        Write-IconPng "android/app/src/main/res/mipmap-$density/ic_launcher.png" (48 * $densities[$density])
        # Keep the supplied artwork inside adaptive-icon masks without cropping it.
        Write-IconPng "android/app/src/main/res/mipmap-$density/ic_launcher_foreground.png" (108 * $densities[$density]) 0.72
    }
    foreach ($platform in @('ios', 'macos')) {
        $catalog = "$platform/Runner/Assets.xcassets/AppIcon.appiconset"
        $contents = Get-Content (Join-Path $appRoot "$catalog/Contents.json") -Raw | ConvertFrom-Json
        foreach ($entry in $contents.images) {
            $size = [double]($entry.size.Split('x')[0]) * [double]($entry.scale.TrimEnd('x'))
            Write-IconPng "$catalog/$($entry.filename)" $size
        }
    }
    foreach ($size in @(192, 512)) {
        Write-IconPng "web/icons/Icon-$size.png" $size
        Write-IconPng "web/icons/Icon-maskable-$size.png" $size 0.9
    }
    Write-IconPng 'web/favicon.png' 32
    # ICO entries use PNG payloads, supported by Windows Vista and later.
    $sizes = @(16, 32, 48, 64, 128, 256)
    $payloads = @()
    foreach ($size in $sizes) {
        $bitmap = [System.Drawing.Bitmap]::new($source, $size, $size)
        $memory = [System.IO.MemoryStream]::new()
        $bitmap.Save($memory, [System.Drawing.Imaging.ImageFormat]::Png)
        $payloads += ,$memory.ToArray()
        $memory.Dispose(); $bitmap.Dispose()
    }
    $file = [System.IO.File]::Create((Join-Path $appRoot 'windows/runner/resources/app_icon.ico'))
    $writer = [System.IO.BinaryWriter]::new($file)
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $dimension = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }
            $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
            $writer.Write([byte]0); $writer.Write([byte]0)
            $writer.Write([uint16]1); $writer.Write([uint16]32)
            $writer.Write([uint32]$payloads[$i].Length); $writer.Write([uint32]$offset)
            $offset += $payloads[$i].Length
        }
        foreach ($payload in $payloads) { $writer.Write([byte[]]$payload) }
    } finally { $writer.Dispose() }
} finally { $source.Dispose() }
Write-Output 'Generated launcher icons for Android, iOS, macOS, Windows and web.'
