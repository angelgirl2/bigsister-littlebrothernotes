[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'backups')
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command railway -ErrorAction SilentlyContinue)) {
    throw 'Railway CLI not found. Install its Windows prebuilt binary from https://docs.railway.com/cli, then reopen PowerShell.'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory = (Resolve-Path $OutputDirectory).Path

Write-Host 'This script downloads files from the selected Railway volume; it does not change or delete them.' -ForegroundColor Cyan
Write-Host 'First run: railway login' -ForegroundColor Cyan
Write-Host 'Then run: railway link  (choose the existing Big Sister Notes project/environment)' -ForegroundColor Cyan
Write-Host 'The media volume is the API service volume mounted at /data/media. Do NOT choose the Postgres volume.' -ForegroundColor Yellow
Write-Host ''
& railway volume list
if ($LASTEXITCODE -ne 0) { throw 'railway volume list failed. Authenticate and link the correct Railway project first.' }
$volumeId = Read-Host 'Enter the ID/name of the API media volume mounted at /data/media'
if ([string]::IsNullOrWhiteSpace($volumeId)) { throw 'No volume selected.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$downloadPath = Join-Path $OutputDirectory "railway-media-$stamp"
$zipPath = "$downloadPath.zip"
Write-Host "Downloading volume files to: $downloadPath" -ForegroundColor Cyan
& railway volume files --volume $volumeId download / $downloadPath
if ($LASTEXITCODE -ne 0) { throw 'Volume download failed. Check the selected volume and Railway CLI output.' }
if (-not (Test-Path $downloadPath -PathType Container)) { throw 'Expected download folder was not found; do not proceed with migration.' }

$files = @(Get-ChildItem -LiteralPath $downloadPath -File -Recurse -Force)
Write-Host "Downloaded file count: $($files.Count)"
if ($files.Count -eq 0) {
    Write-Warning 'No files were found in this volume. Verify that the selected volume is the API /data/media volume.'
} else {
    Compress-Archive -Path (Join-Path $downloadPath '*') -DestinationPath $zipPath -CompressionLevel Optimal
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
    Set-Content -LiteralPath "$zipPath.sha256.txt" -Value "$hash  $(Split-Path $zipPath -Leaf)" -Encoding ascii
    Write-Host "Media files downloaded and packed: $zipPath" -ForegroundColor Green
    Write-Host "SHA-256: $hash" -ForegroundColor Green
}
Write-Host 'Keep the download folder too. Do not delete the Railway volume.' -ForegroundColor Yellow
