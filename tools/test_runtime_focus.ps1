param(
    [string]$Runtime='C:\LEOTherm_Portable_Test_20261008\LEOTherm_1.2.1_portable\runtime\v911',
    [string]$Destination='C:\LEOTherm_Focus_Test_v1_3',
    [string]$BuildSuffix='focus_fix',
    [string]$Version='1.3',
    [switch]$IncludeModuleCheck,
    [switch]$IncludeStartupCheck,
    [switch]$IncludeFigureCheck,
    [ValidateSet('startup','module','figure','window','progress','completion','samples')]
    [string[]]$Checks=@()
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if($BuildSuffix -and $BuildSuffix -notmatch '^[A-Za-z0-9_]+$'){throw 'Invalid build suffix.'}
if($Version -notmatch '^\d+(\.\d+){1,2}$'){throw 'Invalid version.'}
if(Test-Path -LiteralPath $Destination){throw 'Use a new runtime test directory.'}
if(-not(Test-Path -LiteralPath (Join-Path $Runtime 'runtime\win64'))){throw 'Runtime R2021b not found.'}
New-Item -ItemType Directory -Path $Destination | Out-Null
$exe=Join-Path $Destination 'LEOTherm.exe'
$buildTag='standalone_v'+($Version -replace '\.','_')
if($BuildSuffix){$buildTag+='_'+$BuildSuffix}
Copy-Item -LiteralPath (Join-Path $root ('results\'+$buildTag+'\LEOTherm.exe')) -Destination $exe
$originalPath=$env:PATH; $originalCache=$env:MCR_CACHE_ROOT
try {
    $runtimePaths=@('runtime\win64','bin\win64','sys\os\win64') | ForEach-Object {Join-Path $Runtime $_}
    $otherPaths=$originalPath -split ';' | Where-Object {$_ -notmatch '(?i)matlab'}
    $env:PATH=($runtimePaths+$otherPaths) -join ';'
    $env:MCR_CACHE_ROOT=Join-Path $Destination 'cache'
    $modes=@('window','progress','completion')
    if($IncludeFigureCheck){$modes=@('figure')+$modes}
    if($IncludeModuleCheck){$modes=@('module')+$modes+@('samples')}
    if($IncludeStartupCheck){$modes=@('startup')+$modes}
    if($Checks.Count){$modes=$Checks}
    foreach($mode in $modes){
        $output=Join-Path $Destination $mode
        $argument=if($mode -eq 'completion'){'--gui-smoke'}else{'--gui-'+$mode+'-smoke'}
        if($IncludeFigureCheck -and $mode -eq 'completion'){$argument='--gui-report-window-smoke'}
        if($mode -eq 'samples'){$argument='--sample-reports'}
        $process=Start-Process -FilePath $exe -ArgumentList @($argument,('"'+$output+'"')) `
            -WorkingDirectory $Destination -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $Destination ($mode+'_stdout.log')) `
            -RedirectStandardError (Join-Path $Destination ($mode+'_stderr.log'))
        $process.WaitForExit()
        if($process.ExitCode -ne 0){throw "Runtime $mode check failed: exit $($process.ExitCode)"}
        Write-Output "RUNTIME_CHECK_OK mode=$mode exit=$($process.ExitCode)"
    }
    if($modes -contains 'window'){
        $state=Get-Content -LiteralPath (Join-Path $Destination 'window\gui_window_smoke.json') -Raw | ConvertFrom-Json
        if($state.outcome -ne 'passed' -or $state.version -ne $Version){throw 'Window restoration check failed.'}
    }
    if($modes -contains 'figure'){
        $figures=Get-Content -LiteralPath (Join-Path $Destination 'figure\gui_figure_smoke.json') -Raw | ConvertFrom-Json
        if($figures.outcome -ne 'passed' -or @($figures.visibilityAtCreation | Where-Object {$_ -ne 'off'}).Count){throw 'Background figure check failed.'}
    }
    if($modes -contains 'module'){
        $modules=Get-Content -LiteralPath (Join-Path $Destination 'module\module_buttons_smoke.json') -Raw | ConvertFrom-Json
        if($modules.outcome -ne 'passed' -or $modules.automaticReport -or $modules.version -ne $Version){throw 'Module routing check failed.'}
    }
    if($modes -contains 'progress'){
        $progress=Get-Content -LiteralPath (Join-Path $Destination 'progress\gui_progress_smoke.json') -Raw | ConvertFrom-Json
        if($progress.outcome -ne 'passed' -or $progress.checks.Count -ne 3){throw 'Progress regression failed.'}
    }
    if($modes -contains 'completion'){
        if(-not(Test-Path -LiteralPath (Join-Path $Destination 'completion\report\thermal_report_en.pdf'))){throw 'Report missing.'}
    }
    $nonAscii=@(Get-ChildItem -LiteralPath $Destination -Recurse -Force | Where-Object {$_.Name -match '[^\x20-\x7e]'})
    if($nonAscii.Count){throw 'Non-ASCII generated resource or output name.'}
    if($modes -contains 'window'){$state.windowStates | Format-Table initialState,restoredState}
    if($modes -contains 'progress'){$progress.checks | Format-Table language,closeRequested,stopLatencyS}
    Get-FileHash -LiteralPath $exe -Algorithm SHA256
    Write-Output 'RUNTIME_FOCUS_REGRESSION_OK'
} finally {
    $env:PATH=$originalPath; $env:MCR_CACHE_ROOT=$originalCache
}
