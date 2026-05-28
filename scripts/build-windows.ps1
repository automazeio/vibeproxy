# Build Windows app
# Requires: .NET 8 SDK, Visual Studio 2022 (or Build Tools)

param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

Write-Host "🪟 Building VibeProxy Windows app..." -ForegroundColor Cyan

# Build shared Rust core first
Write-Host "📦 Building shared Rust core..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\shared\core"
try {
    cargo build --release
    if ($LASTEXITCODE -ne 0) {
        throw "Rust build failed"
    }
} finally {
    Pop-Location
}

# Copy Rust DLL to Windows app output
$rustDll = "$PSScriptRoot\..\shared\core\target\release\vibeproxy_core.dll"
$windowsOutput = "$PSScriptRoot\..\apps\windows\VibeProxy\bin\$Configuration\net8.0-windows10.0.19041.0\win-x64"
if (Test-Path $rustDll) {
    New-Item -ItemType Directory -Force -Path $windowsOutput | Out-Null
    Copy-Item $rustDll $windowsOutput -Force
    Write-Host "✓ Copied Rust DLL to Windows app" -ForegroundColor Green
}

# Build Windows app
Write-Host "🪟 Building Windows app..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\apps\windows"
try {
    dotnet build -c $Configuration
    if ($LASTEXITCODE -ne 0) {
        throw "Windows build failed"
    }
} finally {
    Pop-Location
}

Write-Host "✅ Windows build complete!" -ForegroundColor Green
