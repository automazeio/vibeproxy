# VibeProxy Windows - Icon Conversion Script
# Converts PNG icons to ICO format for Windows application icon

$ErrorActionPreference = "Stop"

$ResourcesDir = Join-Path $PSScriptRoot "VibeProxy\Resources"

Write-Host "VibeProxy Icon Converter" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Check if ImageMagick is available
$imageMagick = Get-Command "magick" -ErrorAction SilentlyContinue
if (-not $imageMagick) {
    $imageMagick = Get-Command "convert" -ErrorAction SilentlyContinue
}

if ($imageMagick) {
    Write-Host "Using ImageMagick for conversion" -ForegroundColor Green

    # Convert glyph.png to app-icon.ico with multiple sizes
    $glyphPng = Join-Path $ResourcesDir "glyph.png"
    $appIco = Join-Path $ResourcesDir "app-icon.ico"

    if (Test-Path $glyphPng) {
        Write-Host "Converting glyph.png to app-icon.ico..." -ForegroundColor Yellow
        & magick $glyphPng -define icon:auto-resize=256,128,64,48,32,16 $appIco
        Write-Host "Created app-icon.ico" -ForegroundColor Green
    }

    # Convert active icon
    $activePng = Join-Path $ResourcesDir "icon-active.png"
    $activeIco = Join-Path $ResourcesDir "icon-active.ico"

    if (Test-Path $activePng) {
        Write-Host "Converting icon-active.png to icon-active.ico..." -ForegroundColor Yellow
        & magick $activePng -define icon:auto-resize=48,32,16 $activeIco
        Write-Host "Created icon-active.ico" -ForegroundColor Green
    }

    # Convert inactive icon
    $inactivePng = Join-Path $ResourcesDir "icon-inactive.png"
    $inactiveIco = Join-Path $ResourcesDir "icon-inactive.ico"

    if (Test-Path $inactivePng) {
        Write-Host "Converting icon-inactive.png to icon-inactive.ico..." -ForegroundColor Yellow
        & magick $inactivePng -define icon:auto-resize=48,32,16 $inactiveIco
        Write-Host "Created icon-inactive.ico" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Icon conversion complete!" -ForegroundColor Green
}
else {
    Write-Host "ImageMagick not found. Using .NET conversion..." -ForegroundColor Yellow

    # Use .NET to create a basic ICO file
    Add-Type -AssemblyName System.Drawing

    function Convert-PngToIco {
        param(
            [string]$PngPath,
            [string]$IcoPath,
            [int[]]$Sizes = @(16, 32, 48)
        )

        if (-not (Test-Path $PngPath)) {
            Write-Host "File not found: $PngPath" -ForegroundColor Red
            return
        }

        try {
            $bitmap = [System.Drawing.Bitmap]::new($PngPath)

            # Create ICO file with header
            $stream = [System.IO.File]::Create($IcoPath)
            $writer = [System.IO.BinaryWriter]::new($stream)

            # ICO header
            $writer.Write([Int16]0)           # Reserved
            $writer.Write([Int16]1)           # Image type (1 = ICO)
            $writer.Write([Int16]$Sizes.Count) # Number of images

            $imageDataOffset = 6 + (16 * $Sizes.Count)
            $imageDataList = @()

            foreach ($size in $Sizes) {
                $resized = [System.Drawing.Bitmap]::new($bitmap, $size, $size)
                $ms = [System.IO.MemoryStream]::new()
                $resized.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $imageData = $ms.ToArray()
                $imageDataList += ,@{ Size = $size; Data = $imageData }

                # Directory entry
                $writer.Write([Byte]$size)                           # Width
                $writer.Write([Byte]$size)                           # Height
                $writer.Write([Byte]0)                               # Color palette
                $writer.Write([Byte]0)                               # Reserved
                $writer.Write([Int16]1)                              # Color planes
                $writer.Write([Int16]32)                             # Bits per pixel
                $writer.Write([Int32]$imageData.Length)              # Size of image data
                $writer.Write([Int32]$imageDataOffset)               # Offset of image data

                $imageDataOffset += $imageData.Length
                $resized.Dispose()
                $ms.Dispose()
            }

            # Write image data
            foreach ($img in $imageDataList) {
                $writer.Write($img.Data)
            }

            $writer.Close()
            $stream.Close()
            $bitmap.Dispose()

            Write-Host "Created $IcoPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to convert $PngPath : $_" -ForegroundColor Red
        }
    }

    # Convert icons
    Convert-PngToIco -PngPath (Join-Path $ResourcesDir "glyph.png") -IcoPath (Join-Path $ResourcesDir "app-icon.ico") -Sizes @(16, 32, 48, 64, 128, 256)
    Convert-PngToIco -PngPath (Join-Path $ResourcesDir "icon-active.png") -IcoPath (Join-Path $ResourcesDir "icon-active.ico") -Sizes @(16, 32, 48)
    Convert-PngToIco -PngPath (Join-Path $ResourcesDir "icon-inactive.png") -IcoPath (Join-Path $ResourcesDir "icon-inactive.ico") -Sizes @(16, 32, 48)

    Write-Host ""
    Write-Host "Icon conversion complete!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Note: After conversion, rebuild the project:" -ForegroundColor Cyan
Write-Host "  cd VibeProxyWindows && dotnet build" -ForegroundColor Gray
