[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'backups')
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker CLI not found. Install and start Docker Desktop, then run this script again.'
}
& docker info *> $null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop is not running. Start it and try again.' }

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputDirectory = (Resolve-Path $OutputDirectory).Path

Write-Host ''
Write-Host 'On Railway > Postgres > Variables, copy DATABASE_PUBLIC_URL.' -ForegroundColor Cyan
Write-Host 'If it is missing, enable TCP Proxy/Public Networking temporarily, copy DATABASE_PUBLIC_URL, and disable it after the dump.' -ForegroundColor Yellow
Write-Host 'Do not share this URL in chat or commit it to GitHub.' -ForegroundColor Yellow
$secureUrl = Read-Host 'Paste DATABASE_PUBLIC_URL (input is hidden)' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureUrl)
try {
    $url = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

$pattern = '^postgres(?:ql)?://(?<user>[^:/@?#]+):(?<password>[^@/?#]*)@(?<host>\[[^\]]+\]|[^:/?#]+):(?<port>\d+)/(?<database>[^?/#]+)(?<query>\?.*)?$'
if ($url -notmatch $pattern) {
    $url = $null
    throw 'URL format was not recognized. Use the full DATABASE_PUBLIC_URL value from the Railway Postgres Variables tab.'
}
$match = [regex]::Match($url, $pattern)
$user = [Uri]::UnescapeDataString($match.Groups['user'].Value)
$password = [Uri]::UnescapeDataString($match.Groups['password'].Value)
$hostName = $match.Groups['host'].Value.Trim('[', ']')
$port = $match.Groups['port'].Value
$database = [Uri]::UnescapeDataString($match.Groups['database'].Value)
$query = $match.Groups['query'].Value
$url = $null
$secureUrl = $null

$sslMode = 'prefer'
if ($query -match '(?:\?|&)sslmode=([^&]+)') {
    $sslMode = [Uri]::UnescapeDataString($Matches[1])
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$fileName = "bigsister-railway-$stamp.dump"
$dumpPath = Join-Path $OutputDirectory $fileName
$oldPassword = $env:PGPASSWORD
$oldSslMode = $env:PGSSLMODE
try {
    $env:PGPASSWORD = $password
    $env:PGSSLMODE = $sslMode
    $dockerArgs = @(
        'run', '--rm', '-e', 'PGPASSWORD', '-e', 'PGSSLMODE',
        '-v', "$($OutputDirectory):/backup",
        'postgres:17-alpine', 'pg_dump',
        '--host', $hostName, '--port', $port, '--username', $user,
        '--dbname', $database, '--format=custom', '--no-owner', '--no-acl',
        '--file', "/backup/$fileName"
    )
    Write-Host 'Creating PostgreSQL backup. Do not close this window...' -ForegroundColor Cyan
    & docker @dockerArgs
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -Force -ErrorAction SilentlyContinue $dumpPath
        throw 'pg_dump failed. Check connectivity and DATABASE_PUBLIC_URL, then retry. No successful backup was created.'
    }
    if (-not (Test-Path $dumpPath) -or (Get-Item $dumpPath).Length -lt 100) {
        throw 'Backup file is missing or unexpectedly small. Treat the backup as failed.'
    }
    $verifyArgs = @('run', '--rm', '-v', "$($OutputDirectory):/backup", 'postgres:17-alpine', 'pg_restore', '--list', "/backup/$fileName")
    & docker @verifyArgs *> $null
    if ($LASTEXITCODE -ne 0) { throw 'The file was created, but pg_restore could not validate it. Do not use it as your only backup.' }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $dumpPath).Hash
    Set-Content -LiteralPath "$dumpPath.sha256.txt" -Value "$hash  $fileName" -Encoding ascii
    Write-Host ''
    Write-Host "Backup verified: $dumpPath" -ForegroundColor Green
    Write-Host "SHA-256: $hash" -ForegroundColor Green
    Write-Host 'Keep this dump private; it contains your database records.' -ForegroundColor Yellow
} finally {
    if ($null -eq $oldPassword) { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue } else { $env:PGPASSWORD = $oldPassword }
    if ($null -eq $oldSslMode) { Remove-Item Env:PGSSLMODE -ErrorAction SilentlyContinue } else { $env:PGSSLMODE = $oldSslMode }
    $password = $null
}
