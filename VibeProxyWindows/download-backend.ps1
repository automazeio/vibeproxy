# VibeProxy Windows - Backend Download Script
# Downloads the cli-proxy-api.exe binary from GitHub releases

param(
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

$ResourcesDir = Join-Path $PSScriptRoot "VibeProxy\Resources"
$TargetPath = Join-Path $ResourcesDir "cli-proxy-api.exe"

Write-Host "VibeProxy Backend Downloader" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

# Create Resources directory if it doesn't exist
if (-not (Test-Path $ResourcesDir)) {
    New-Item -ItemType Directory -Path $ResourcesDir -Force | Out-Null
    Write-Host "Created Resources directory" -ForegroundColor Green
}

# Determine download URL
$RepoOwner = "router-for-me"
$RepoName = "CLIProxyAPI"

if ($Version -eq "latest") {
    Write-Host "Fetching latest release information..." -ForegroundColor Yellow
    $ReleaseUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"

    try {
        $Release = Invoke-RestMethod -Uri $ReleaseUrl -Headers @{ "User-Agent" = "VibeProxy-Downloader" }
        $Version = $Release.tag_name
        Write-Host "Latest version: $Version" -ForegroundColor Green

        # Find Windows asset
        $WindowsAsset = $Release.assets | Where-Object { $_.name -like "*windows*" -or $_.name -like "*win*" -or $_.name -eq "cli-proxy-api.exe" }

        if ($WindowsAsset) {
            $DownloadUrl = $WindowsAsset.browser_download_url
        } else {
            # Try common naming patterns
            $DownloadUrl = "https://github.com/$RepoOwner/$RepoName/releases/download/$Version/cli-proxy-api-windows-amd64.exe"
        }
    }
    catch {
        Write-Host "Failed to fetch release info: $_" -ForegroundColor Red
        Write-Host "Trying fallback URL..." -ForegroundColor Yellow
        $DownloadUrl = "https://github.com/$RepoOwner/$RepoName/releases/latest/download/cli-proxy-api-windows-amd64.exe"
    }
} else {
    $DownloadUrl = "https://github.com/$RepoOwner/$RepoName/releases/download/$Version/cli-proxy-api-windows-amd64.exe"
}

Write-Host "Download URL: $DownloadUrl" -ForegroundColor Cyan

# Download the binary
Write-Host "Downloading cli-proxy-api.exe..." -ForegroundColor Yellow

try {
    $ProgressPreference = 'SilentlyContinue'  # Speeds up download
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TargetPath -UseBasicParsing
    $ProgressPreference = 'Continue'

    if (Test-Path $TargetPath) {
        $FileInfo = Get-Item $TargetPath
        Write-Host "Downloaded successfully!" -ForegroundColor Green
        Write-Host "  Location: $TargetPath" -ForegroundColor Gray
        Write-Host "  Size: $([math]::Round($FileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
    }
}
catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download manually from:" -ForegroundColor Yellow
    Write-Host "  https://github.com/$RepoOwner/$RepoName/releases" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Then place the executable at:" -ForegroundColor Yellow
    Write-Host "  $TargetPath" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "Setup complete! You can now build and run VibeProxy:" -ForegroundColor Green
Write-Host "  cd VibeProxyWindows" -ForegroundColor Gray
Write-Host "  dotnet run" -ForegroundColor Gray
