param(
    [string]$Runtime='C:\LEOTherm_Portable_Test_20261008\LEOTherm_1.2.1_portable\runtime\v911',
    [string]$Destination='C:\LEOTherm_Progress_Test_v1_3',
    [string]$Version='1.3',
    [string]$BuildSuffix=''
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if($BuildSuffix -and $BuildSuffix -notmatch '^[A-Za-z0-9_]+$'){throw 'Invalid build suffix.'}
if($BuildSuffix){$BuildSuffix='_'+$BuildSuffix}
if(Test-Path -LiteralPath $Destination){throw 'Use a new runtime test directory.'}
if(-not(Test-Path -LiteralPath (Join-Path $Runtime 'runtime\win64'))){throw 'Runtime R2021b not found.'}
New-Item -ItemType Directory -Path $Destination | Out-Null
$exe=Join-Path $Destination 'LEOTherm.exe'
Copy-Item -LiteralPath (Join-Path $root ('results\standalone_v'+($Version -replace '\.','_')+$BuildSuffix+'\LEOTherm.exe')) -Destination $exe
$originalPath=$env:PATH; $originalCache=$env:MCR_CACHE_ROOT
try {
    $runtimePaths=@('runtime\win64','bin\win64','sys\os\win64') | ForEach-Object {Join-Path $Runtime $_}
    $otherPaths=$originalPath -split ';' | Where-Object {$_ -notmatch '(?i)matlab'}
    $env:PATH=($runtimePaths+$otherPaths) -join ';'
    $env:MCR_CACHE_ROOT=Join-Path $Destination 'cache'
    $output=Join-Path $Destination 'gui_result'
    $process=Start-Process -FilePath $exe -ArgumentList @('--gui-progress-smoke',('"'+$output+'"')) `
        -WorkingDirectory $Destination -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $Destination 'stdout.log') `
        -RedirectStandardError (Join-Path $Destination 'stderr.log')
    $process.WaitForExit()
    if($process.ExitCode -ne 0){throw "Runtime GUI progress failed: exit $($process.ExitCode)"}
    $state=Get-Content -LiteralPath (Join-Path $output 'gui_progress_smoke.json') -Raw | ConvertFrom-Json
    if($state.outcome -ne 'passed' -or $state.version -ne $Version -or $state.checks.Count -ne 3){throw 'GUI completion check failed.'}
    $nonAscii=@(Get-ChildItem -LiteralPath $Destination -Recurse -Force | Where-Object {$_.Name -match '[^\x20-\x7e]'})
    if($nonAscii.Count){throw 'Non-ASCII generated resource or output name.'}
    Write-Output "RUNTIME_GUI_PROGRESS_OK version=$Version exit=$($process.ExitCode)"
    $state.checks | Format-Table language,closeRequested,timerCallbacks,lastStage,stopLatencyS
} finally {
    $env:PATH=$originalPath; $env:MCR_CACHE_ROOT=$originalCache
}
