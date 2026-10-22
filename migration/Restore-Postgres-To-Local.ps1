[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DumpPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot
if (-not (Test-Path '.env')) { throw 'Root .env is missing. Copy .env.example to .env and configure it first.' }
if (-not (Test-Path $DumpPath -PathType Leaf)) { throw "Database dump not found: $DumpPath" }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker CLI not found.' }
& docker info *> $null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop is not running.' }

$envValues = @{}
foreach ($line in Get-Content '.env') {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$' -and $Matches[1] -notlike '#*') {
        $value = $Matches[2].Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) { $value = $value.Substring(1, $value.Length - 2) }
        $envValues[$Matches[1]] = $value
    }
}
$dbName = $envValues['POSTGRES_DB']
$dbUser = $envValues['POSTGRES_USER']
if ([string]::IsNullOrWhiteSpace($dbName) -or [string]::IsNullOrWhiteSpace($dbUser)) { throw 'POSTGRES_DB or POSTGRES_USER is missing from .env.' }

$DumpPath = (Resolve-Path $DumpPath).Path
Write-Host 'Starting ONLY the local database; the API will remain stopped.' -ForegroundColor Cyan
& docker compose up -d db
if ($LASTEXITCODE -ne 0) { throw 'Could not start the local database.' }
$containerId = (& docker compose ps -q db).Trim()
if ([string]::IsNullOrWhiteSpace($containerId)) { throw 'Could not identify the local Postgres container.' }

# Safety check: refuse to overwrite a non-empty local database.
$tables = (& docker compose exec -T db psql -U $dbUser -d $dbName -Atc "SELECT count(*) FROM pg_tables WHERE schemaname='public';").Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect the destination database.' }
if ($tables -ne '0') {
    throw "The destination database already contains $tables public tables. Restore stopped to avoid overwriting existing data. Use a fresh empty destination instead."
}

$containerDump = '/tmp/bigsister-railway.dump'
& docker cp $DumpPath "${containerId}:$containerDump"
if ($LASTEXITCODE -ne 0) { throw 'Could not copy the dump into the local database container.' }
Write-Host 'Restoring into the empty local database...' -ForegroundColor Cyan
& docker compose exec -T db pg_restore --exit-on-error --no-owner --no-acl -U $dbUser -d $dbName $containerDump
$restoreExit = $LASTEXITCODE
& docker compose exec -T db rm -f $containerDump *> $null
if ($restoreExit -ne 0) { throw 'pg_restore failed. Keep the source dump and Railway data untouched. Review the error before retrying.' }
Write-Host 'PostgreSQL restore completed. The API was not started automatically.' -ForegroundColor Green
Write-Host 'Next: restore media into a fresh media volume, then start API and verify data before changing phone URLs.' -ForegroundColor Yellow
