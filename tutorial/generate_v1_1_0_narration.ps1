param(
    [string]$CaptureDirectory = 'H:\paper\leo-gnss-thermal-simulator\results\tutorial_v1_1_0_capture_final'
)

$ErrorActionPreference = 'Stop'
$audioDirectory = Join-Path $CaptureDirectory 'audio'
if (-not (Test-Path -LiteralPath $audioDirectory)) {
    New-Item -ItemType Directory -Path $audioDirectory | Out-Null
}
$scenes = @(
    [pscustomobject]@{ Image='01_quick_start.png'; Caption='新版软件从一个任务开始'; Narration='这是低轨卫星热仿真工作台一点一版。画面来自真实图形界面和本次实际生成的报告。我们先看最常用的一条任务流水线。' },
    [pscustomobject]@{ Image='02_all_optional_off.png'; Caption='四个附加阶段默认关闭'; Narration='进入仿真页，参数扫描、三维耦合、遥测对比和设备标定都是可选项。四项都不勾选，基础节点热仿真仍可直接运行。' },
    [pscustomobject]@{ Image='03_sweep_selected.png'; Caption='需要扫描时再勾选'; Narration='勾选参数扫描后，它会成为同一次任务中的一个阶段。没有勾选的阶段不需要填写配置，也不会在后台偷偷运行。' },
    [pscustomobject]@{ Image='04_telemetry_requires_data.png'; Caption='缺少遥测时，预检阻止运行'; Narration='如果勾选遥测对比，却还没有导入数据，界面会用中文提示需要的数据，并禁用运行按钮。取消勾选即可跳过。' },
    [pscustomobject]@{ Image='05_geometry_requires_mesh.png'; Caption='三维耦合需要有效网格'; Narration='三维耦合也一样。勾选之后必须提供表面和体网格；没有网格时不会假装完成三维计算。' },
    [pscustomobject]@{ Image='06_calibration_requires_data.png'; Caption='标定需要设备数据和日划分'; Narration='设备标定需要遥测、设备参数，以及训练、验证和测试日的划分。没有这些输入就不能运行标定。本视频不把合成数据当作真实验证。' },
    [pscustomobject]@{ Image='07_first_project_ready.png'; Caption='打开示例项目，检查后运行'; Narration='现在打开第一个示例项目。检查场景和热网络后，运行统一任务。软件先保存输入快照，再冻结模型，然后求解温度和热滞后指标。' },
    [pscustomobject]@{ Image='08_base_results.png'; Caption='基础任务完成，报告可直接打开'; Narration='基础任务已完成。结果页同时给出数值指标、任务编号、每个阶段的状态，以及打开本次报告的入口。' },
    [pscustomobject]@{ Image='12_base_pdf-1.png'; Caption='PDF 首页说明输入和主要发现'; Narration='报告首页记录软件版本、任务名称、时长、步长、热网络和主要结果。这里的码偏差是半仿真量，不是实测的卫星误差。' },
    [pscustomobject]@{ Image='13_base_pdf-3.png'; Caption='报告内保留带图例的时序图'; Narration='下一页是本次实际计算的日照、外部热流、节点温度和温度诱导码偏差图。图例和坐标轴跟随中文界面。' },
    [pscustomobject]@{ Image='13_base_pdf-4.png'; Caption='验收页明确标出完成与跳过'; Narration='验收页是最重要的。它把扫描、三维、遥测和标定明确标为跳过，同时说明数值通过不等于真实物理验证通过。' },
    [pscustomobject]@{ Image='09_scan_project_ready.png'; Caption='第二次任务只开启一个扫描工况'; Narration='再看一个可选功能。这里把扫描缩小为一个高度和一个贝塔角工况，只勾选参数扫描，其余附加阶段仍然关闭。' },
    [pscustomobject]@{ Image='11_scan_chart.png'; Caption='扫描结果进入同一任务'; Narration='这一次扫描结果和基础仿真放在同一个任务里。可以在扫描页查看图表，不必另开一条互不相干的流程。' },
    [pscustomobject]@{ Image='10_scan_results.png'; Caption='结果页汇总任务阶段'; Narration='结果页显示第二次任务的指标和阶段记录。参数扫描为完成，三维、遥测与标定为跳过。报告按钮打开的也是这一次任务的文件。' },
    [pscustomobject]@{ Image='15_sweep_pdf-5.png'; Caption='扫描完成，其余阶段如实跳过'; Narration='最后看扫描任务的报告。参数扫描显示完成，其他未选功能显示跳过。整条使用流程从配置、预检、运行到报告验收已经闭合。' }
)

$voice = New-Object -ComObject SAPI.SpVoice
$voices = $voice.GetVoices('Name=Microsoft Huihui Desktop')
if ($voices.Count -eq 0) { throw 'Chinese SAPI voice is unavailable.' }
$voice.Voice = $voices.Item(0)
$voice.Rate = 0
$voice.Volume = 100

for ($i = 0; $i -lt $scenes.Count; $i++) {
    $imagePath = Join-Path (Join-Path $CaptureDirectory 'frames') $scenes[$i].Image
    if (-not (Test-Path -LiteralPath $imagePath)) { throw "Missing frame: $imagePath" }
    $audioName = '{0:D2}.wav' -f ($i + 1)
    $audioPath = Join-Path $audioDirectory $audioName
    if (Test-Path -LiteralPath $audioPath) { throw "Audio already exists: $audioPath" }
    $stream = New-Object -ComObject SAPI.SpFileStream
    $stream.Open($audioPath, 3, $false)
    $voice.AudioOutputStream = $stream
    [void]$voice.Speak($scenes[$i].Narration)
    $stream.Close()
    $scenes[$i] | Add-Member -NotePropertyName Audio -NotePropertyValue $audioName
}

$manifest = [pscustomobject]@{
    Version = '1.1.0'
    Source = 'Actual GUI and task-report captures; scripted GUI actions'
    Scenes = $scenes
}
$json = $manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Join-Path $CaptureDirectory 'video_scenes.json'), $json, [System.Text.UTF8Encoding]::new($false))
Write-Output "NARRATION_SCENES=$($scenes.Count)"
