param(
    [string]$Runtime = 'C:\LEOTherm_Portable_Test_20261008\LEOTherm_1.2.1_portable\runtime\v911',
    [string]$Destination = 'C:\LEOTherm_Report_Test_v1_2_5',
    [string]$Version = '1.2.5'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (Test-Path -LiteralPath $Destination) { throw 'Use a new runtime test directory.' }
if (-not (Test-Path -LiteralPath (Join-Path $Runtime 'runtime\win64'))) {
    throw 'MATLAB Runtime R2021b directory not found.'
}
New-Item -ItemType Directory -Path $Destination | Out-Null
$exe = Join-Path $Destination 'LEOTherm.exe'
$build = 'results\standalone_v' + ($Version -replace '\.','_') + '\LEOTherm.exe'
Copy-Item -LiteralPath (Join-Path $root $build) -Destination $exe
$originalPath = $env:PATH
$originalCache = $env:MCR_CACHE_ROOT
try {
    $runtimePaths = @('runtime\win64','bin\win64','sys\os\win64') | ForEach-Object { Join-Path $Runtime $_ }
    $otherPaths = $originalPath -split ';' | Where-Object { $_ -notmatch '(?i)matlab' }
    $env:PATH = ($runtimePaths + $otherPaths) -join ';'
    $env:MCR_CACHE_ROOT = Join-Path $Destination 'cache'
    $output = Join-Path $Destination 'gui_result'
    $process = Start-Process -FilePath $exe -ArgumentList @('--gui-smoke', ('"' + $output + '"')) `
        -WorkingDirectory $Destination -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $Destination 'stdout.log') `
        -RedirectStandardError (Join-Path $Destination 'stderr.log')
    $process.WaitForExit()
    Write-Output "RUNTIME_EXIT_CODE=$($process.ExitCode)"
    if ($process.ExitCode -ne 0) { throw 'Runtime process failed.' }
    $status = Get-Content -LiteralPath (Join-Path $output 'standalone_gui_status.txt') -Raw
    if ($status -notmatch '(?m)^outcome=complete\r?$') { throw 'GUI pipeline did not complete.' }
    if ($status -notmatch ('(?m)^version=' + [regex]::Escape($Version) + '\r?$')) { throw 'Unexpected executable version.' }
    Write-Output $status
} finally {
    $env:PATH = $originalPath
    $env:MCR_CACHE_ROOT = $originalCache
}
