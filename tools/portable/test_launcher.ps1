[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$LauncherStaging)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$source = (Resolve-Path -LiteralPath $LauncherStaging).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('LEOTherm portable test ' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testRoot
$passed = 0
function Check([bool]$condition, [string]$name) {
    if (!$condition) { throw "FAIL: $name" }
    $script:passed++
    Write-Output "PASS: $name"
}
function Diagnose([string]$directory, [string]$output) {
    $process = Start-Process -FilePath (Join-Path $directory 'Start_LEOTherm.exe') `
        -ArgumentList @('--diagnose', ('"' + $output + '"')) -Wait -PassThru -WindowStyle Hidden
    return $process.ExitCode
}
Copy-Item -LiteralPath (Join-Path $source 'Start_LEOTherm.exe') -Destination $testRoot
Copy-Item -LiteralPath (Join-Path $source 'portable_manifest.json') -Destination $testRoot
$before = [Environment]::GetEnvironmentVariable('PATH', 'User')
$missingOutput = Join-Path $testRoot 'missing.json'
$exit = Diagnose $testRoot $missingOutput
Check ($exit -eq 1) 'Missing Runtime gives nonzero exit'
Check ((Get-Content -LiteralPath $missingOutput -Raw | ConvertFrom-Json).outcome -eq 'failed') 'Missing Runtime gives diagnostic JSON'
Check ([Environment]::GetEnvironmentVariable('PATH', 'User') -ceq $before) 'User PATH is unchanged'
$manifest = Get-Content -LiteralPath (Join-Path $source 'portable_manifest.json') -Raw | ConvertFrom-Json
$manifest.schema = 'unsupported'
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $testRoot 'portable_manifest.json') -Encoding UTF8
$badSchema = Join-Path $testRoot 'schema.json'
Check ((Diagnose $testRoot $badSchema) -eq 1) 'Unknown package format is rejected'
Check ((Get-Content -LiteralPath $badSchema -Raw | ConvertFrom-Json).message -eq 'Unknown portable package format.') 'Unknown format has a specific error'

# This miniature Runtime is a launcher fixture, NOT a functioning MATLAB Runtime.
$manifest.schema = 'leotherm.portable.v1'
$runtime = Join-Path $testRoot 'runtime\v911'
$null = New-Item -ItemType Directory -Path (Join-Path $testRoot 'app')
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:exe /platform:x64 "/out:$(Join-Path $testRoot 'app\LEOTherm.exe')" (Join-Path $PSScriptRoot 'SmokeProbe.cs')
if ($LASTEXITCODE -ne 0) { throw 'Probe compilation failed.' }
foreach ($relative in @('runtime\win64\mclmcrrt9_11.dll', 'bin\win64\MATLABWindow.exe',
    'sys\java\jre\win64\jre\bin\java.dll', 'bin\win64\vcruntime140.dll', 'bin\win64\msvcp140.dll', 'MCR_license.txt')) {
    $path = Join-Path $runtime $relative
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
    [IO.File]::WriteAllText($path, 'Launcher test fixture only')
}
[IO.File]::WriteAllText((Join-Path $runtime 'VersionInfo.xml'),
    '<MathWorks_version_info><release>R2021b</release><version>9.11.0.1</version></MathWorks_version_info>')
$manifest.appSha256 = (Get-FileHash -LiteralPath (Join-Path $testRoot 'app\LEOTherm.exe')).Hash
$manifest.runtimeDllSha256 = (Get-FileHash -LiteralPath (Join-Path $runtime 'runtime\win64\mclmcrrt9_11.dll')).Hash
$manifest.runtimeLicenseSha256 = (Get-FileHash -LiteralPath (Join-Path $runtime 'MCR_license.txt')).Hash
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $testRoot 'portable_manifest.json') -Encoding UTF8
$valid = Join-Path $testRoot 'ready.json'
Check ((Diagnose $testRoot $valid) -eq 0) 'Valid fixture passes critical-file preflight'
Check ((Get-Content -LiteralPath $valid -Raw | ConvertFrom-Json).runtimeRoot -eq $runtime) 'Runtime root follows relocated launcher directory with spaces'
$output = Join-Path $testRoot 'result with spaces\'
$process = Start-Process -FilePath (Join-Path $testRoot 'Start_LEOTherm.exe') `
    -ArgumentList @('--smoke', ('"' + $output.TrimEnd('\') + '\\"')) -Wait -PassThru -WindowStyle Hidden
Check ($process.ExitCode -eq 0) 'Child succeeds with a spaced output path and trailing separator'
$probe = Get-Content -LiteralPath (Join-Path $output 'probe.txt')
Check ($probe[1] -eq $runtime) 'Child receives bundle-local Runtime root'
Check ($probe[3].StartsWith((Join-Path $runtime 'runtime\win64') + ';')) 'Bundle Runtime is first on child PATH'
Check ([Environment]::GetEnvironmentVariable('PATH', 'User') -ceq $before) 'Running child does not modify persistent user PATH'
$process = Start-Process -FilePath (Join-Path $testRoot 'Start_LEOTherm.exe') `
    -ArgumentList @('--smoke', ('"' + (Join-Path $testRoot 'exit17') + '"')) -Wait -PassThru -WindowStyle Hidden
Check ($process.ExitCode -eq 17) 'Nonzero application exit code is propagated'
[IO.File]::AppendAllText((Join-Path $runtime 'runtime\win64\mclmcrrt9_11.dll'), 'tampered')
$tampered = Join-Path $testRoot 'tampered.json'
Check ((Diagnose $testRoot $tampered) -eq 1) 'Tampered critical DLL is rejected'
Check ((Get-Content -LiteralPath $tampered -Raw | ConvertFrom-Json).message.Contains('damaged')) 'Integrity error identifies damaged file'
[IO.File]::WriteAllText((Join-Path $runtime 'VersionInfo.xml'),
    '<MathWorks_version_info><release>R2022a</release><version>9.12.0.1</version></MathWorks_version_info>')
$wrong = Join-Path $testRoot 'wrong_version.json'
Check ((Diagnose $testRoot $wrong) -eq 1) 'Wrong Runtime release is rejected'
Check ((Get-Content -LiteralPath $wrong -Raw | ConvertFrom-Json).message.Contains('not R2021b')) 'Runtime version error is specific'
Write-Output "LAUNCHER_TESTS_PASSED=$passed"
Write-Output "TEST_EVIDENCE=$testRoot"
