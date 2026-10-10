[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Archive,
    [Parameter(Mandatory = $true)][string]$ArchiveTool,
    [Parameter(Mandatory = $true)][string]$LauncherReference,
    [Parameter(Mandatory = $true)][string]$RecordPath
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (Test-Path -LiteralPath $RecordPath) { throw 'Use a new archive verification record.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Archive).Path)
try {
    $roots = @($zip.Entries | Where-Object { $_.FullName -match '^[^/]+/portable_manifest.json$' })
    if ($roots.Count -ne 1) { throw 'Expected one portable manifest.' }
    $reader = New-Object IO.StreamReader($roots[0].Open())
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    $prefix = $roots[0].FullName.Replace('portable_manifest.json', '')
    $paths = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $zip.Entries) {
        if (!$entry.FullName.StartsWith($prefix) -or $entry.FullName.Contains('\') -or
            $entry.FullName.Contains(':') -or ($entry.FullName.Split('/') -contains '..')) {
            throw "Unsafe archive path: $($entry.FullName)"
        }
        if (!$paths.Add($entry.FullName)) { throw "Duplicate Windows archive path: $($entry.FullName)" }
        if ((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {
            throw "Archive contains a symbolic link: $($entry.FullName)"
        }
    }
    $runtimeFiles = @($zip.Entries | Where-Object {
        $_.FullName.StartsWith($prefix + 'runtime/v911/') -and !$_.FullName.EndsWith('/')
    })
    $bytes = ($runtimeFiles | Measure-Object Length -Sum).Sum
    if ($runtimeFiles.Count -ne $manifest.runtimeFileCount -or $bytes -ne $manifest.runtimeBytes) {
        throw 'The archive does not contain the declared complete Runtime.'
    }
    $checks = @{
        'Start_LEOTherm.exe' = (Get-FileHash -LiteralPath $LauncherReference -Algorithm SHA256).Hash
        'app/LEOTherm.exe' = $manifest.appSha256
        'runtime/v911/runtime/win64/mclmcrrt9_11.dll' = $manifest.runtimeDllSha256
        'runtime/v911/MCR_license.txt' = $manifest.runtimeLicenseSha256
    }
    foreach ($relative in $checks.Keys) {
        $stream = $zip.GetEntry($prefix + $relative).Open()
        $algorithm = [Security.Cryptography.SHA256]::Create()
        try { $digest = [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '') }
        finally { $algorithm.Dispose(); $stream.Dispose() }
        if ($digest -ne $checks[$relative]) { throw "Critical archived file hash mismatch: $relative" }
    }
    $record = [ordered]@{
        outcome = 'complete'; packageVersion = $manifest.packageVersion
        archive = (Resolve-Path -LiteralPath $Archive).Path
        archiveBytes = (Get-Item -LiteralPath $Archive).Length
        runtimeFileCount = $runtimeFiles.Count; runtimeBytes = $bytes
        totalEntries = $zip.Entries.Count
        maximumEntryPathLength = ($zip.Entries.FullName | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        criticalHashesPassed = $true; unsafeOrSymlinkPaths = 0
        launcherSha256 = $checks['Start_LEOTherm.exe'].ToLowerInvariant()
    }
} finally { $zip.Dispose() }
& $ArchiveTool t -bd $Archive
if ($LASTEXITCODE -ne 0) { throw 'Full archive CRC test failed.' }
$record.fullCrcPassed = $true
$record.sha256 = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()
$expected = (Get-Content -LiteralPath "$Archive.sha256" -Raw).Split(' ')[0]
if ($record.sha256 -ne $expected) { throw 'Archive checksum sidecar mismatch.' }
$record | ConvertTo-Json | Set-Content -LiteralPath $RecordPath -Encoding UTF8
Write-Output 'PORTABLE_ARCHIVE_VERIFICATION_OK'
