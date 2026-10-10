param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$scenes = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'scenes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$audio = Join-Path $OutputDirectory 'audio'
New-Item -ItemType Directory -Path $audio -Force | Out-Null
$voice = New-Object -ComObject SAPI.SpVoice
$voices = $voice.GetVoices('Name=Microsoft Zira Desktop')
if ($voices.Count -eq 0) { throw 'English narration voice is not installed.' }
$voice.Voice = $voices.Item(0)
$voice.Rate = 1
$voice.Volume = 100
for ($i=0; $i -lt $scenes.Count; $i++) {
    $stream = New-Object -ComObject SAPI.SpFileStream
    $stream.Format.Type = 22
    $stream.Open((Join-Path $audio ('{0:D2}.wav' -f ($i+1))),3,$false)
    $voice.AudioOutputStream = $stream
    [void]$voice.Speak($scenes[$i].text)
    $stream.Close()
    Write-Output ('VOICE={0:D2}' -f ($i+1))
}
