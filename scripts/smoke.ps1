param([Parameter(Mandatory)][string]$Bin)
$ErrorActionPreference = 'Stop'
$ffmpeg = (Resolve-Path (Join-Path $Bin 'ffmpeg.exe')).Path
$ffprobe = (Resolve-Path (Join-Path $Bin 'ffprobe.exe')).Path
$output = Join-Path ([IO.Path]::GetTempPath()) ('demodesk-ffmpeg-' + [guid]::NewGuid())
New-Item -ItemType Directory $output | Out-Null
function Run([string[]]$Arguments) {
    & $ffmpeg -hide_banner -loglevel error -y @Arguments
    if ($LASTEXITCODE -ne 0) { throw "FFmpeg failed: $Arguments" }
}
Push-Location $output
try {
    $encoders = (& $ffmpeg -hide_banner -encoders 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot load FFmpeg' }
    foreach ($codec in 'libx264', 'libx265', 'libsvtav1', 'h264_nvenc', 'hevc_nvenc', 'av1_nvenc') {
        if ($encoders -notmatch "\b$codec\b") { throw "Missing encoder: $codec" }
    }
    # HLAE adds setsar itself, so file-to-file encoding alone cannot validate capture compatibility.
    Run @('-f','lavfi','-i','testsrc2=size=320x180:rate=30','-t','1','-pix_fmt','bgr24','-c:v','rawvideo','-f','rawvideo','capture.raw')
    $capture = [Diagnostics.Process]::new()
    $capture.StartInfo.FileName = $ffmpeg
    $capture.StartInfo.UseShellExecute = $false
    $capture.StartInfo.CreateNoWindow = $true
    $capture.StartInfo.RedirectStandardInput = $true
    $capture.StartInfo.RedirectStandardError = $true
    foreach ($argument in @('-y','-f','rawvideo','-pixel_format','bgr24','-loglevel','error','-framerate','30',
        '-video_size','320x180','-i','pipe:0','-vf','setsar=sar=1/1','-c:v','libx264','-pix_fmt','yuv420p','capture.mp4')) {
        $capture.StartInfo.ArgumentList.Add($argument)
    }
    $capture.StartInfo.WorkingDirectory = $output
    try {
        if (-not $capture.Start()) { throw 'Could not start HLAE capture check' }
        $stderr = $capture.StandardError.ReadToEndAsync()
        $inputFile = [IO.File]::OpenRead((Join-Path $output 'capture.raw'))
        $writeError = $null
        try { $inputFile.CopyTo($capture.StandardInput.BaseStream) }
        catch { $writeError = $_ }
        finally { $inputFile.Dispose(); $capture.StandardInput.Close() }
        if (-not $capture.WaitForExit(30000)) { $capture.Kill($true); throw 'HLAE capture check timed out' }
        $errors = $stderr.GetAwaiter().GetResult()
        if ($capture.ExitCode -ne 0) { throw "HLAE capture pipeline failed: $errors" }
        if ($writeError) { throw $writeError }
    } finally { $capture.Dispose() }
    Run @('-i','capture.mp4','-f','null','NUL')
    Run @('-f','lavfi','-i','testsrc2=size=640x360:rate=30','-t','1','-c:v','rawvideo','-f','rawvideo','input.raw')
    Run @('-f','rawvideo','-pixel_format','yuv420p','-video_size','640x360','-framerate','30','-i','input.raw',
        '-f','lavfi','-i','sine=frequency=440:sample_rate=44100','-t','1','-c:v','libx264','-c:a','aac','input.mp4')
    Run @('-i','input.mp4','-vn','-c:a','pcm_s16le','audio.wav')
    $configs = @(
        @{ Name='libx264'; Preset='medium'; Pixel='yuv420p' },
        @{ Name='libx265'; Preset='medium'; Pixel='yuv420p10le' },
        @{ Name='libsvtav1'; Preset='8'; Pixel='yuv420p10le' }
    )
    foreach ($config in $configs) {
        $name = $config.Name
        $common = @('-i','input.mp4','-vf','scale=320:180,fps=24','-c:v',$name,
            '-preset',$config.Preset,'-pix_fmt',$config.Pixel,'-b:v','500k')
        foreach ($pass in 1,2) {
            $args = $common.Clone()
            if ($name -eq 'libx265') { $args += @('-x265-params',"pass=${pass}:stats=$name.log") }
            else { $args += @('-pass',"$pass",'-passlogfile',"$name.log") }
            if ($pass -eq 1) { Run ($args + @('-an','-f','null','NUL')) }
            else { Run ($args + @('-c:a','aac','-ar','48000','-ac','2','-movflags','+faststart',"$name.mp4")) }
        }
        Run @('-i',"$name.mp4",'-f','null','NUL')
        $json = & $ffprobe -v error -show_streams -show_format -of json "$name.mp4"
        if ($LASTEXITCODE -ne 0) { throw 'ffprobe failed' }
        $info = $json | ConvertFrom-Json
        $video = @($info.streams | Where-Object codec_type -eq 'video')
        $audio = @($info.streams | Where-Object codec_type -eq 'audio')
        if ($video.Count -ne 1 -or $video[0].width -ne 320 -or $audio.Count -ne 1) { throw "Invalid output: $name" }
        if ([double]$info.format.duration -lt 0.9) { throw "Truncated output: $name" }
    }
    Set-Content -Path concat.txt -Value "file 'libx264.mp4'`nfile 'libx264.mp4'" -Encoding utf8NoBOM
    Run @('-f','concat','-safe','0','-i','concat.txt','-c','copy','-movflags','+faststart','joined.mp4')
    Run @('-i','joined.mp4','-i','audio.wav','-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-shortest','remux.mp4')
    Run @('-f','lavfi','-i','color=size=320x180:rate=30','-frames:v','3','-c:v','libx264','-f','null','NUL')
    Write-Host "HLAE pipe capture, CPU encoding, two-pass, decoding, audio and concat passed. Logs: $output"
    Write-Host 'NVENC encoders are present; actual GPU encoding remains a hardware integration check.'
} finally {
    Pop-Location
}
