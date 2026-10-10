[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeRoot,
    [string]$OutputRoot,
    [string]$ArchiveTool,
    [string]$StagingRoot,
    [switch]$SkipArchive
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
if ($ArchiveTool -and !$StagingRoot) {
    $StagingRoot = Join-Path ([IO.Path]::GetTempPath()) ('LEOTherm_build_' + [Guid]::NewGuid().ToString('N'))
}
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$packageVersion = "$version-portable.1"
if (!$OutputRoot) { $OutputRoot = Join-Path $root "results\portable_$($version.Replace('.', '_'))_1" }
$RuntimeRoot = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$executable = Join-Path $root "results\standalone_v$($version.Replace('.', '_'))\LEOTherm.exe"
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $compiler)) { throw '.NET Framework x64 compiler was not found.' }
if (!(Test-Path -LiteralPath $executable)) { throw "Build the $version standalone application first." }
if (Test-Path -LiteralPath $OutputRoot) { throw "Refusing to overwrite existing output: $OutputRoot" }
[xml]$runtimeVersion = Get-Content -LiteralPath (Join-Path $RuntimeRoot 'VersionInfo.xml') -Raw
if ($runtimeVersion.MathWorks_version_info.release -ne 'R2021b' -or
    $runtimeVersion.MathWorks_version_info.description -ne 'Update 8') {
    throw 'Use a complete installed MATLAB Runtime R2021b Update 8.'
}
if (!(Test-Path -LiteralPath (Join-Path $RuntimeRoot 'mcr')) -or
    !(Get-Content -LiteralPath (Join-Path $RuntimeRoot 'MCR_license.txt') -Raw).Contains('MATLAB RUNTIME LICENSE')) {
    throw 'This is not an installed MATLAB Runtime. Do not redistribute a full MATLAB installation.'
}
$requiredRuntimeFiles = @('runtime\win64\mclmcrrt9_11.dll', 'bin\win64\MATLABWindow.exe',
    'sys\java\jre\win64\jre\bin\java.dll', 'bin\win64\vcruntime140.dll', 'bin\win64\msvcp140.dll')
foreach ($relative in $requiredRuntimeFiles) {
    if (!(Test-Path -LiteralPath (Join-Path $RuntimeRoot $relative))) { throw "Missing Runtime file: $relative" }
}
$null = New-Item -ItemType Directory -Path $OutputRoot
$bundleName = "LEOTherm_${version}_portable"
if ($StagingRoot) {
    if (Test-Path -LiteralPath $StagingRoot) { throw "Refusing to reuse staging: $StagingRoot" }
    $null = New-Item -ItemType Directory -Path $StagingRoot
} else { $StagingRoot = $OutputRoot }
$staging = Join-Path $StagingRoot $bundleName
$null = New-Item -ItemType Directory -Path (Join-Path $staging 'app')
Copy-Item -LiteralPath $executable -Destination (Join-Path $staging 'app\LEOTherm.exe')
Copy-Item -LiteralPath (Join-Path $root 'templates') -Destination $staging -Recurse
Copy-Item -LiteralPath (Join-Path $root 'docs\portable_en.md') -Destination (Join-Path $staging 'README.md')
Copy-Item -LiteralPath (Join-Path $root 'docs\免安装版使用.md') -Destination (Join-Path $staging 'README_CN.md')
foreach ($file in @('LICENSE', 'NOTICE.md')) { Copy-Item -LiteralPath (Join-Path $root $file) -Destination $staging }
Copy-Item -LiteralPath (Join-Path $RuntimeRoot 'MCR_license.txt') -Destination (Join-Path $staging 'MATLAB_RUNTIME_LICENSE.txt')
$launcher = Join-Path $staging 'Start_LEOTherm.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ "/out:$launcher" `
    /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll `
    (Join-Path $PSScriptRoot 'portable\PortableLauncher.cs')
if ($LASTEXITCODE -ne 0) { throw 'Portable launcher compilation failed.' }
$runtimeFiles = @(Get-ChildItem -LiteralPath $RuntimeRoot -File -Recurse)
$runtimeBytes = ($runtimeFiles | Measure-Object Length -Sum).Sum
$manifest = [ordered]@{
    schema = 'leotherm.portable.v1'; packageVersion = $packageVersion; appVersion = $version
    runtimeRelease = 'R2021b'; runtimeVersion = $runtimeVersion.MathWorks_version_info.version
    runtimeUpdate = 8; runtimeFileCount = $runtimeFiles.Count; runtimeBytes = $runtimeBytes
    runtimeUnmodified = $true
    runtimeSource = 'https://ssd.mathworks.com/supportfiles/downloads/R2021b/Release/8/deployment_files/installer/complete/win64/MATLAB_Runtime_R2021b_Update_8_win64.zip'
    appSha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
    runtimeDllSha256 = (Get-FileHash -LiteralPath (Join-Path $RuntimeRoot 'runtime\win64\mclmcrrt9_11.dll')).Hash
    runtimeLicenseSha256 = (Get-FileHash -LiteralPath (Join-Path $RuntimeRoot 'MCR_license.txt')).Hash
    createdUTC = [DateTime]::UtcNow.ToString('o')
    acceptance = 'Build only; consult the separate portable verification record.'
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $staging 'portable_manifest.json') -Encoding UTF8
if ($SkipArchive) {
    Write-Output "LAUNCHER_STAGING=$staging"
    Write-Output 'Runtime is NOT copied with -SkipArchive; this directory is not a distributable bundle.'
    return
}

# Stream the complete Runtime into ZIP64 without pruning or linking to the source installation.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archivePath = Join-Path $OutputRoot "LEOTherm_${version}_portable_windows_x64.zip"
if ($ArchiveTool) {
    $ArchiveTool = (Resolve-Path -LiteralPath $ArchiveTool).Path
    $null = New-Item -ItemType Directory -Path (Join-Path $staging 'runtime')
    $link = Join-Path $staging 'runtime\v911'
    try { $null = New-Item -ItemType Junction -Path $link -Target $RuntimeRoot }
    catch { throw 'Native archiving requires NTFS staging. Use -StagingRoot with a new directory on an NTFS drive.' }
    try {
        Push-Location -LiteralPath $StagingRoot
        try {
            # 7-Zip's default follows the junction and stores real files, not a symlink.
            & $ArchiveTool a -tzip -mx=1 -mmt=4 -bd -sse $archivePath $bundleName
            if ($LASTEXITCODE -ne 0) { throw 'Native ZIP creation failed.' }
        } finally { Pop-Location }
    } finally {
        $item = Get-Item -LiteralPath $link -Force
        if ($item.LinkType -ne 'Junction' -or $item.Target -ne $RuntimeRoot) {
            throw 'Unexpected staging link; refusing to remove it.'
        }
        # Remove only our junction, never recursively delete the source Runtime.
        $item.Delete()
    }
} else {
$stream = [IO.File]::Open($archivePath, [IO.FileMode]::CreateNew)
try {
    $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $staging -File -Recurse) {
            $relative = $file.FullName.Substring($staging.Length + 1).Replace('\', '/')
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName,
                "$bundleName/$relative", [IO.Compression.CompressionLevel]::Optimal)
        }
        $count = 0
        foreach ($file in $runtimeFiles) {
            $relative = $file.FullName.Substring($RuntimeRoot.Length + 1).Replace('\', '/')
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName,
                "$bundleName/runtime/v911/$relative", [IO.Compression.CompressionLevel]::Optimal)
            $count++
            if ($count % 10000 -eq 0) { Write-Output "RUNTIME_PACKED=$count/$($runtimeFiles.Count)" }
        }
    } finally { $zip.Dispose() }
} finally { $stream.Dispose() }
}
$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($archivePath))" | Set-Content -LiteralPath "$archivePath.sha256" -Encoding ASCII
Write-Output "PORTABLE_ARCHIVE=$archivePath"
Write-Output "PORTABLE_BYTES=$((Get-Item -LiteralPath $archivePath).Length)"
Write-Output "PORTABLE_SHA256=$hash"
