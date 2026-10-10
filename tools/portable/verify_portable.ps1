[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BundleRoot,
    [Parameter(Mandatory = $true)][string]$EvidenceRoot
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$BundleRoot = (Resolve-Path -LiteralPath $BundleRoot).Path
if (Test-Path -LiteralPath $EvidenceRoot) { throw 'Use a new evidence directory.' }
$null = New-Item -ItemType Directory -Path $EvidenceRoot
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
$machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
$launcher = Join-Path $BundleRoot 'Start_LEOTherm.exe'
$diagnostic = Join-Path $EvidenceRoot 'diagnostic.json'
$p = Start-Process -FilePath $launcher -ArgumentList @('--diagnose', ('"' + $diagnostic + '"')) `
    -PassThru -Wait -WindowStyle Hidden
if ($p.ExitCode -ne 0) { throw 'Portable diagnosis failed.' }
$diagnosis = Get-Content -LiteralPath $diagnostic -Raw | ConvertFrom-Json
if ($diagnosis.runtimeRoot -ne (Join-Path $BundleRoot 'runtime\v911')) { throw 'Wrong Runtime root.' }
$tests = @()
foreach ($mode in @('--smoke', '--gui-smoke')) {
    $output = Join-Path $EvidenceRoot ($mode.TrimStart('-') + ' result')
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $launcher
    $info.Arguments = $mode + ' "' + $output + '"'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WorkingDirectory = $EvidenceRoot
    # Exclude installed MATLAB/Runtime from the inherited PATH without changing the user's settings.
    $info.EnvironmentVariables['PATH'] = "$env:WINDIR\System32;$env:WINDIR"
    $process = [Diagnostics.Process]::Start($info)
    $modules = New-Object 'Collections.Generic.HashSet[string]'
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $timeout = $false
    while (!$process.HasExited) {
        if ($timer.Elapsed.TotalSeconds -gt 300) {
            $timeout = $true
            # Only terminate this test's process tree; do not touch any existing MATLAB session.
            & "$env:WINDIR\System32\taskkill.exe" /PID $process.Id /T /F | Out-Null
            break
        }
        foreach ($child in @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($process.Id)")) {
            if ($child.Name -ne 'LEOTherm.exe') { continue }
            try {
                foreach ($module in (Get-Process -Id $child.ProcessId -ErrorAction Stop).Modules) {
                    $null = $modules.Add($module.FileName)
                }
            } catch { }
        }
        Start-Sleep -Milliseconds 200
        $process.Refresh()
    }
    $process.WaitForExit()
    $timer.Stop()
    $modulePaths = @($modules | Sort-Object)
    $modulePaths | Set-Content -LiteralPath (Join-Path $EvidenceRoot ($mode.TrimStart('-') + '_modules.txt')) -Encoding UTF8
    $runtimeDll = Join-Path $BundleRoot 'runtime\v911\runtime\win64\mclmcrrt9_11.dll'
    if (!($modulePaths -contains $runtimeDll)) { throw "Bundled Runtime DLL was not observed for $mode." }
    if (@($modulePaths | Where-Object {
        $_ -like '*LEOAssessment_Deployment_Cache\InstalledRuntime\*' -or $_ -like '*Matlab R2021b*'
    }).Count -ne 0) { throw 'An original MATLAB/Runtime installation was used.' }
    $statusFile = if ($mode -eq '--smoke') { 'standalone_smoke_status.txt' } else { 'standalone_gui_status.txt' }
    if ($timeout -or $process.ExitCode -ne 0 -or !(Test-Path -LiteralPath (Join-Path $output $statusFile))) {
        throw "Portable $mode failed or timed out (exit $($process.ExitCode))."
    }
    $status = Get-Content -LiteralPath (Join-Path $output $statusFile) -Raw
    if (!$status.Contains('outcome=complete')) { throw 'Pipeline smoke did not complete.' }
    $pdf = Join-Path $output 'report\thermal_report_en.pdf'
    if (!(Test-Path -LiteralPath $pdf) -or (Get-Item -LiteralPath $pdf).Length -lt 1000) { throw 'No valid-sized PDF.' }
    $tests += [pscustomobject]@{mode=$mode;exitCode=$process.ExitCode;seconds=$timer.Elapsed.TotalSeconds;
        bundledRuntimeObserved=$true;pdf=$pdf;status=$status}
    Write-Output "PORTABLE_TEST_PASSED=$mode"
}
if ([Environment]::GetEnvironmentVariable('PATH', 'User') -cne $userPath -or
    [Environment]::GetEnvironmentVariable('PATH', 'Machine') -cne $machinePath) {
    throw 'Persistent PATH changed during verification.'
}
[ordered]@{outcome='complete';bundleRoot=$BundleRoot;tests=$tests;persistentPathUnchanged=$true;
    scope='Relocated bundle on development Windows host. Not an independent clean-machine certification.'} |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $EvidenceRoot 'verification.json') -Encoding UTF8
Write-Output 'PORTABLE_VERIFICATION_OK'
