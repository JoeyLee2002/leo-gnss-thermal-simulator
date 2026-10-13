param([Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$destinationPath=[IO.Path]::GetFullPath($Destination)
$expected=[IO.Path]::GetFullPath((Join-Path $root 'results/github_v1_5_release_checkout'))
if($destinationPath -ne $expected -or -not(Test-Path -LiteralPath (Join-Path $destinationPath '.git'))){throw 'Use the prepared isolated release checkout.'}

$modified=@(git -C $root -c core.quotepath=false -c core.autocrlf=false diff --name-only --diff-filter=ACMRT HEAD)
$deleted=@(git -C $root -c core.quotepath=false -c core.autocrlf=false diff --name-only --diff-filter=D HEAD)
$extra=@(git -C $root -c core.quotepath=false ls-files --others --exclude-standard)
$extra=$extra | Where-Object {
    ($_ -match '^(src/|tests/)' -and $_ -match '\.m$') -or
    ($_ -match '^tools/' -and $_ -match '\.(m|ps1|py|mjs)$') -or
    ($_ -match '^docs/' -and ($_ -match 'v1\.5' -or $_ -match '^docs/manual_images/' -or $_ -eq 'docs/manual_render_audit.json') -and $_ -notmatch '_preview\.png$') -or
    ($_ -match '^patches/PATCH_v1\.5' -and $_ -match '\.md$') -or
    $_ -match '^examples/reports/(thermal_report_v1\.5_(en|zh)\.pdf|reference_network_sweep_sample_v1\.2\.0_zh\.pdf)$'
}
$exactSources=@(Get-ChildItem -LiteralPath (Join-Path $root 'src') -Recurse -File | ForEach-Object {
    $_.FullName.Substring($root.Length+1) -replace '\\','/'
})
$paths=@($modified+$extra+$exactSources | Sort-Object -Unique)
$manifest=[ordered]@{}
foreach($relative in $paths){
    $source=Join-Path $root $relative
    $target=[IO.Path]::GetFullPath((Join-Path $destinationPath $relative))
    if(-not $target.StartsWith($destinationPath+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Target outside release checkout.'}
    if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw "Missing source: $relative"}
    $parent=Split-Path -Parent $target
    if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force | Out-Null}
    Copy-Item -LiteralPath $source -Destination $target -Force
    $manifest[$relative]=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
}
foreach($relative in $deleted){
    $target=[IO.Path]::GetFullPath((Join-Path $destinationPath $relative))
    if(-not $target.StartsWith($destinationPath+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Deletion outside release checkout.'}
    if(Test-Path -LiteralPath $target -PathType Leaf){Remove-Item -LiteralPath $target}
}

$record=Join-Path $destinationPath 'docs/verification/v1.5'
New-Item -ItemType Directory -Path (Join-Path $record 'runtime_checks') -Force | Out-Null
$records=@{
    'verification_v1_5_status.txt'=(Join-Path $root 'results/verification_v1_5_status.txt')
    'release_gate2.log'='C:/Users/30698/AppData/Local/Temp/release_gate2.log'
    'paper_results.csv'='C:/LEOTherm_Paper_Test_v1_5_release/paper_result/paper_results.csv'
    'audit.csv'='C:/LEOTherm_Paper_Test_v1_5_release/paper_result/audit.csv'
    'paper_study_status.json'='C:/LEOTherm_Paper_Test_v1_5_release/paper_result/paper_study_status.json'
    'time_refinement.csv'='C:/LEOTherm_Paper_Test_v1_5_release/paper_result/sweep36/time_refinement.csv'
    'runtime_status_read_audit.json'='C:/LEOTherm_Paper_Test_v1_5_release/runtime_status_read_audit.json'
    'documentation_qa.json'=(Join-Path $root 'results/illustrated_manuals_v1_5_qa.json')
    'package_audit.json'=(Join-Path $root 'results/illustrated_manuals_v1_5_package_audit.json')
}
foreach($name in $records.Keys){Copy-Item -LiteralPath $records[$name] -Destination (Join-Path $record $name) -Force}
$focusRoot='C:/LEOTherm_Focus_Test_v1_5_release'
Get-ChildItem -LiteralPath $focusRoot -Recurse -File | Where-Object {
    $_.Name -match '(status|manifest|check)' -and $_.Extension -in '.txt','.json'
} | ForEach-Object {
    $name=$_.FullName.Substring($focusRoot.Length+1) -replace '[\\/]', '_'
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $record "runtime_checks/$name") -Force
}

$sha=[Security.Cryptography.SHA256]::Create()
$sourceManifest=[ordered]@{}
$sourceFiles=@(Get-ChildItem -LiteralPath (Join-Path $root 'src') -Recurse -File)
$copiedSourceFiles=@(Get-ChildItem -LiteralPath (Join-Path $destinationPath 'src') -Recurse -File)
if($sourceFiles.Count -ne $copiedSourceFiles.Count){throw 'Release src inventory differs from tested source.'}
foreach($file in $sourceFiles){
    $relative=$file.FullName.Substring($root.Length+1) -replace '\\','/'
    $copy=Join-Path $destinationPath $relative
    $raw=(Get-FileHash -LiteralPath $file.FullName).Hash
    if($raw -ne (Get-FileHash -LiteralPath $copy).Hash){throw "Source mismatch: $relative"}
    $text=[Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($copy)).Replace("`r`n","`n")
    $normalized=[Convert]::ToHexString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))
    $sourceManifest[$relative]=[ordered]@{sha256=$raw;normalizedLfSha256=$normalized}
}
$sha.Dispose()
$metadata=[ordered]@{version='1.5';baseCommit='c6d565f2d49a739141dc6c455949f679cc28290e';sourceFileCount=$sourceFiles.Count;exeSha256='CAEB39ECC63D81479E6356F7BBD6DC1FA691BA1EE618C20B9F52CE0DD3928BDE';files=$sourceManifest}
[IO.File]::WriteAllText((Join-Path $record 'publication_source_manifest.json'),($metadata | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
Write-Output "RELEASE_CHECKOUT_PREPARED FILES=$($paths.Count) SRC=$($sourceFiles.Count)"
