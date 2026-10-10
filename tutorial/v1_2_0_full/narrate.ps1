param([string]$CaptureDirectory)
$ErrorActionPreference = 'Stop'
$scenes = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'scenes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$audio = Join-Path $CaptureDirectory 'audio'
New-Item -ItemType Directory -Force -Path $audio | Out-Null
$voice = New-Object -ComObject SAPI.SpVoice
$available = $voice.GetVoices('Name=Microsoft Huihui Desktop')
if ($available.Count -eq 0) { throw 'Chinese voice unavailable.' }
$voice.Voice = $available.Item(0)
$voice.Rate = 3
$voice.Volume = 100
for ($i=0; $i -lt $scenes.Count; $i++) {
    $path = Join-Path $audio ('{0:D2}.wav' -f ($i+1))
    $stream = New-Object -ComObject SAPI.SpFileStream
    $stream.Open($path,3,$false)
    $voice.AudioOutputStream = $stream
    [void]$voice.Speak($scenes[$i].text)
    $stream.Close()
    Write-Output ('VOICE={0:D2}' -f ($i+1))
}
