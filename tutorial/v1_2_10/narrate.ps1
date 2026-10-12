param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
foreach($language in @('zh','en')) {
    $scenes=Get-Content -LiteralPath (Join-Path $OutputDirectory "$language/scenes.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $audio=Join-Path $OutputDirectory "$language/audio"
    New-Item -ItemType Directory -Force -Path $audio | Out-Null
    $voice=New-Object -ComObject SAPI.SpVoice
    $name=if($language -eq 'zh'){'Microsoft Huihui Desktop'}else{'Microsoft Zira Desktop'}
    $available=$voice.GetVoices("Name=$name")
    if($available.Count -eq 0){throw "Voice unavailable: $name"}
    $voice.Voice=$available.Item(0); $voice.Rate=1; $voice.Volume=100
    for($i=0;$i -lt $scenes.Count;$i++) {
        $stream=New-Object -ComObject SAPI.SpFileStream
        $stream.Open((Join-Path $audio ('{0:D2}.wav' -f ($i+1))),3,$false)
        $voice.AudioOutputStream=$stream
        [void]$voice.Speak($scenes[$i].narration)
        $stream.Close()
    }
}
