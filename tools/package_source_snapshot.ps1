param([Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$Destination=[IO.Path]::GetFullPath($Destination)
if(Test-Path -LiteralPath $Destination){throw 'Use a new source archive path.'}
$parent=Split-Path -Parent $Destination
if(-not(Test-Path -LiteralPath $parent)){throw 'Archive parent directory must exist.'}
$tracked=@(git -C $root -c core.quotepath=false ls-files)
if($LASTEXITCODE -ne 0){throw 'Cannot enumerate source repository.'}
$extra=@(git -C $root -c core.quotepath=false ls-files --others --exclude-standard)
if($LASTEXITCODE -ne 0){throw 'Cannot enumerate new source files.'}
$extra=$extra | Where-Object {
    $_ -match '^(src/|tests/|patches/PATCH_v1\.(2\.10|3|5)\.md$|docs/|examples/reports/(thermal_report_v1\.(2\.10|3|5)_|reference_network_sweep_sample)|tutorial/v1_2_10/|tools/(qa_paper_delivery\.py|qa_progress_delivery\.py|test_runtime_[A-Za-z0-9_]+\.ps1|test_report_closure_isolated\.ps1|run_progress_regression\.m|standalone_resources\.m|package_source_snapshot\.ps1)$)'
}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::Open($Destination,[IO.Compression.ZipArchiveMode]::Create)
$count=0
try {
    foreach($relative in @($tracked+$extra | Sort-Object -Unique)) {
        $path=[IO.Path]::GetFullPath((Join-Path $root $relative))
        if(-not $path.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
            throw 'Source path outside repository.'
        }
        if(Test-Path -LiteralPath $path -PathType Leaf) {
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$path,$relative,[IO.Compression.CompressionLevel]::Optimal) | Out-Null
            $count++
        }
    }
} finally {$zip.Dispose()}
Write-Output "SOURCE_SNAPSHOT=$Destination FILES=$count"
