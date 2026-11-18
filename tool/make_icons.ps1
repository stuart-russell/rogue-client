# Draws the Rogue app icon and writes every size the platforms need.
#
#   .\tool\make_icons.ps1
#
# Outputs:
#   assets/branding/icon-1024.png, icon-512.png   (master artwork)
#   android/app/src/main/res/mipmap-*/ic_launcher.png            (legacy)
#   android/app/src/main/res/mipmap-*/ic_launcher_background.png (adaptive layer)
#   android/app/src/main/res/drawable-xhdpi/tv_banner.png        (Android TV)
#   windows/runner/resources/app_icon.ico
#
# The mark is drawn rather than bitmapped so it stays crisp at 48 px and 256 px.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$accent = [System.Drawing.Color]::FromArgb(255, 255, 90, 98)   # #FF5A62
$inkTop = [System.Drawing.Color]::FromArgb(255, 18, 21, 31)    # #12151F
$inkBottom = [System.Drawing.Color]::FromArgb(255, 8, 9, 13)   # #08090D

function Get-BoldFontFamily {
  foreach ($name in @('Segoe UI Black', 'Segoe UI', 'Arial')) {
    $family = [System.Drawing.FontFamily]::Families | Where-Object { $_.Name -eq $name }
    if ($family) { return $family }
  }
  return [System.Drawing.FontFamily]::GenericSansSerif
}

$family = Get-BoldFontFamily
$style = if ($family.Name -eq 'Segoe UI Black') {
  [System.Drawing.FontStyle]::Regular
} else {
  [System.Drawing.FontStyle]::Bold
}

function New-RoundedPath([System.Drawing.RectangleF]$rect, [float]$radius) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $radius * 2
  $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
  $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
  $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
  $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

function New-MasterBitmap([int]$size, [bool]$rounded, [double]$markScale, [bool]$withMark = $true) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)

  $rect = New-Object System.Drawing.RectangleF 0, 0, $size, $size

  # Background: soft vertical ink gradient inside an optional rounded square.
  $radius = if ($rounded) { $size * 0.22 } else { 0 }
  if ($rounded) {
    $path = New-RoundedPath $rect $radius
  } else {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    [void]$path.AddRectangle($rect)
  }

  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect, $inkTop, $inkBottom, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
  $g.FillPath($brush, $path)

  # Coral glow behind the mark.
  $glowSize = $size * 0.92
  $glowRect = New-Object System.Drawing.RectangleF (($size - $glowSize) / 2), (($size - $glowSize) / 2), $glowSize, $glowSize
  $glow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $glow.AddEllipse($glowRect)
  $glowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($glow)
  $glowBrush.CenterColor = [System.Drawing.Color]::FromArgb(46, $accent)
  $glowBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $accent))
  $g.FillPath($glowBrush, $glow)

  if (-not $withMark) {
    $g.Dispose()
    return $bmp
  }

  # The mark.
  $fontSize = $size * $markScale
  $font = New-Object System.Drawing.Font($family, $fontSize, $style, [System.Drawing.GraphicsUnit]::Pixel)
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = [System.Drawing.StringAlignment]::Center
  $format.LineAlignment = [System.Drawing.StringAlignment]::Center
  $textRect = New-Object System.Drawing.RectangleF 0, ($size * -0.02), $size, $size
  $textBrush = New-Object System.Drawing.SolidBrush $accent
  $g.DrawString('R', $font, $textBrush, $textRect, $format)

  # Clip to the rounded square for the legacy/windows artwork.
  if ($rounded) {
    $g.SetClip($path)
    $g.ResetClip()
  }

  $g.Dispose()
  return $bmp
}

function Save-Scaled([System.Drawing.Bitmap]$source, [int]$size, [string]$path) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.DrawImage($source, 0, 0, $size, $size)
  $g.Dispose()
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

# A transparent canvas holding only the coral R, for the adaptive foreground.
function New-MarkBitmap([int]$size, [double]$markScale) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)

  $fontSize = $size * $markScale
  $font = New-Object System.Drawing.Font($family, $fontSize, $style, [System.Drawing.GraphicsUnit]::Pixel)
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = [System.Drawing.StringAlignment]::Center
  $format.LineAlignment = [System.Drawing.StringAlignment]::Center
  $textRect = New-Object System.Drawing.RectangleF 0, ($size * -0.02), $size, $size
  $brush = New-Object System.Drawing.SolidBrush $accent
  $g.DrawString('R', $font, $brush, $textRect, $format)
  $g.Dispose()
  return $bmp
}

# --- master artwork -------------------------------------------------------
$master = New-MasterBitmap 1024 $true 0.62
Save-Scaled $master 1024 (Join-Path $projectRoot 'assets\branding\icon-1024.png')
Save-Scaled $master 512 (Join-Path $projectRoot 'assets\branding\icon-512.png')

# --- Android launcher icons ----------------------------------------------
$densities = [ordered]@{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
$res = Join-Path $projectRoot 'android\app\src\main\res'
foreach ($entry in $densities.GetEnumerator()) {
  Save-Scaled $master $entry.Value (Join-Path $res "mipmap-$($entry.Key)\ic_launcher.png")
}

# Adaptive icon: gradient background without the mark, plus a transparent
# foreground carrying the R inside the 66% safe zone. Launchers replace an
# empty foreground with a generated letter tile, so it must not be blank.
$adaptiveBackground = New-MasterBitmap 1080 $false 0.0 $false
$foreground = New-MarkBitmap 1080 0.56
$adaptiveSizes = [ordered]@{ 'mdpi' = 108; 'hdpi' = 162; 'xhdpi' = 216; 'xxhdpi' = 324; 'xxxhdpi' = 432 }
foreach ($entry in $adaptiveSizes.GetEnumerator()) {
  Save-Scaled $adaptiveBackground $entry.Value (Join-Path $res "mipmap-$($entry.Key)\ic_launcher_background.png")
  Save-Scaled $foreground $entry.Value (Join-Path $res "mipmap-$($entry.Key)\ic_launcher_foreground.png")
}

$anydpi = Join-Path $res 'mipmap-anydpi-v26'
if (-not (Test-Path $anydpi)) { New-Item -ItemType Directory -Force -Path $anydpi | Out-Null }
@'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'@ | Set-Content (Join-Path $anydpi 'ic_launcher.xml') -Encoding UTF8

# --- Android TV banner (320x180) -----------------------------------------
$banner = New-Object System.Drawing.Bitmap 320, 180
$bg = [System.Drawing.Graphics]::FromImage($banner)
$bg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$bg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$bannerRect = New-Object System.Drawing.RectangleF 0, 0, 320, 180
$bannerBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  $bannerRect, $inkTop, $inkBottom, [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
$bg.FillRectangle($bannerBrush, $bannerRect)

$mark = New-MasterBitmap 240 $true 0.62
$bg.DrawImage($mark, 24, 42, 96, 96)

$wordmarkFont = New-Object System.Drawing.Font($family, 32, $style, [System.Drawing.GraphicsUnit]::Pixel)
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 244, 246, 251))
$spacing = 5.0
$letters = 'ROGUE'.ToCharArray()
$widths = @()
foreach ($ch in $letters) {
  $widths += [double]($bg.MeasureString([string]$ch, $wordmarkFont).Width - 6)
}
$x = 134.0
$baseline = 62.0
for ($i = 0; $i -lt $letters.Length; $i++) {
  $bg.DrawString([string]$letters[$i], $wordmarkFont, $white, [float]$x, [float]$baseline)
  $x += $widths[$i] + $spacing
}
$dotBrush = New-Object System.Drawing.SolidBrush $accent
$bg.FillEllipse($dotBrush, [float]($x + 1), [float]($baseline + 12), 9, 9)

$tagFont = New-Object System.Drawing.Font($family, 13, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$muted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 152, 161, 184))
$bg.DrawString('IPTV CLIENT', $tagFont, $muted, 136, 100)
$bg.Dispose()
$tvDir = Join-Path $res 'drawable-xhdpi'
if (-not (Test-Path $tvDir)) { New-Item -ItemType Directory -Force -Path $tvDir | Out-Null }
$banner.Save((Join-Path $tvDir 'tv_banner.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$banner.Dispose()

# --- Windows .ico (PNG entries, multi-size) ------------------------------
$icoSizes = @(16, 24, 32, 48, 64, 128, 256)
$images = @()
foreach ($size in $icoSizes) {
  $tmp = New-Object System.IO.MemoryStream
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.DrawImage($master, 0, 0, $size, $size)
  $g.Dispose()
  $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $images += , $tmp.ToArray()
  $tmp.Dispose()
}

$icoPath = Join-Path $projectRoot 'windows\runner\resources\app_icon.ico'
$stream = [System.IO.File]::Create($icoPath)
$writer = New-Object System.IO.BinaryWriter $stream
$writer.Write([UInt16]0)
$writer.Write([UInt16]1)
$writer.Write([UInt16]$icoSizes.Count)
$offset = 6 + 16 * $icoSizes.Count
for ($i = 0; $i -lt $icoSizes.Count; $i++) {
  $size = $icoSizes[$i]
  $data = $images[$i]
  $dim = if ($size -ge 256) { 0 } else { $size }
  $writer.Write([byte]$dim)
  $writer.Write([byte]$dim)
  $writer.Write([byte]0)
  $writer.Write([byte]0)
  $writer.Write([UInt16]1)
  $writer.Write([UInt16]32)
  $writer.Write([UInt32]$data.Length)
  $writer.Write([UInt32]$offset)
  $offset += $data.Length
}
foreach ($data in $images) { $writer.Write($data) }
$writer.Flush()
$writer.Dispose()

$master.Dispose()
$adaptiveBackground.Dispose()
$foreground.Dispose()
Write-Host "Icons written for Android (5 densities + adaptive + TV banner), Windows and branding masters."
