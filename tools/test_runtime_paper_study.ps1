param(
    [string]$Runtime='C:\LEOTherm_Portable_Test_20261008\LEOTherm_1.2.1_portable\runtime\v911',
    [string]$Destination='C:\LEOTherm_Paper_Test_v1_2_10',
    [string]$Version='1.2.10'
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if(Test-Path -LiteralPath $Destination){throw 'Use a new runtime test directory.'}
if(-not(Test-Path -LiteralPath (Join-Path $Runtime 'runtime\win64'))){throw 'Runtime R2021b not found.'}
New-Item -ItemType Directory -Path $Destination | Out-Null
$exe=Join-Path $Destination 'LEOTherm.exe'
Copy-Item -LiteralPath (Join-Path $root ('results\standalone_v'+($Version -replace '\.','_')+'\LEOTherm.exe')) -Destination $exe
$originalPath=$env:PATH; $originalCache=$env:MCR_CACHE_ROOT
try {
    $runtimePaths=@('runtime\win64','bin\win64','sys\os\win64') | ForEach-Object {Join-Path $Runtime $_}
    $otherPaths=$originalPath -split ';' | Where-Object {$_ -notmatch '(?i)matlab'}
    $env:PATH=($runtimePaths+$otherPaths) -join ';'
    $env:MCR_CACHE_ROOT=Join-Path $Destination 'cache'
    $output=Join-Path $Destination 'paper_result'
    $process=Start-Process -FilePath $exe -ArgumentList @('--paper-study',('"'+$output+'"'),'both') `
        -WorkingDirectory $Destination -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $Destination 'stdout.log') `
        -RedirectStandardError (Join-Path $Destination 'stderr.log')
    $process.WaitForExit()
    if($process.ExitCode -ne 0){throw "Runtime paper study failed: exit $($process.ExitCode)"}
    $status=Get-Content -LiteralPath (Join-Path $output 'paper_study_status.json') -Raw | ConvertFrom-Json
    if($status.status -ne 'complete' -or $status.caseCount -ne 36 -or $status.version -ne $Version){throw 'Study completion check failed.'}
    foreach($lang in @('zh','en')) {
        if(-not(Test-Path -LiteralPath (Join-Path $output "report\thermal_report_$lang.pdf"))){throw "Missing $lang PDF."}
    }
    Write-Output "RUNTIME_PAPER_STUDY_OK version=$Version cases=36 exit=$($process.ExitCode)"
} finally {
    $env:PATH=$originalPath; $env:MCR_CACHE_ROOT=$originalCache
}
