param(
    [string]$Matlab='E:\Matlab R2021b(1)\Matlab R2021b\bin\matlab.exe',
    [string]$Destination='H:\paper\leo-gnss-thermal-simulator\results\v1_5_startup_report_isolated'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if(Test-Path -LiteralPath $Destination){throw 'Use a new verification directory.'}
New-Item -ItemType Directory -Path $Destination | Out-Null
$names=@(
    'testScenarioRunExportsAuditablePdf',
    'testTelemetryOnlyRunCanExportReport',
    'testTelemetryResultAppearsInMainResults',
    'testStaleTelemetryCannotEnterReport',
    'testTelemetryTemplateUsesOptionalPipelineStage',
    'testOptionalStageChoicesPersistInProject',
    'testChineseOptionalStagePreflightGuidance'
)
foreach($name in $names){
    $script="cd('$($root.Replace("'","''"))'); addpath('src'); s=matlab.unittest.TestSuite.fromFile('tests/test_report_closure.m'); s=s(strcmp({s.Name},'test_report_closure/$name')); assert(numel(s)==1); r=run(s); assert(all([r.Passed])); fprintf('ISOLATED_REPORT_TEST_OK $name\n'); clear s r; close all force; drawnow;"
    $p=Start-Process -FilePath $Matlab -ArgumentList @('-batch',('"'+$script+'"'),'-logfile',('"'+(Join-Path $Destination ($name+'.log'))+'"')) `
        -WorkingDirectory $root -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $Destination ($name+'_stdout.log')) `
        -RedirectStandardError (Join-Path $Destination ($name+'_stderr.log'))
    $p.WaitForExit()
    if($p.ExitCode -ne 0){throw "Isolated report test failed: $name exit=$($p.ExitCode)"}
    Write-Output "ISOLATED_REPORT_TEST_OK $name exit=0"
}
Write-Output 'ISOLATED_REPORT_CLOSURE_OK passed=7 total=7'
