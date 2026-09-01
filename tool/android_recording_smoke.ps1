[CmdletBinding()]
param(
    [string] $Serial,
    [string] $EvidenceDirectory,
    [ValidateRange(20, 300)]
    [int] $RecordSeconds = 45,
    [ValidateSet('bilibili', 'douyu', 'huya', 'douyin', 'kuaishou')]
    [string] $Platform = 'bilibili',
    [string] $Package = 'com.mystyle.purelive',
    [string] $Activity = '.MainActivity'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$evidence = if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
    Join-Path $repo (
        'local-artifacts\diagnostics\android-recording-smoke-{0}' -f
        [DateTime]::Now.ToString('yyyyMMddTHHmmssfff')
    )
} else {
    $candidate = if ([IO.Path]::IsPathRooted($EvidenceDirectory)) {
        $EvidenceDirectory
    } else {
        Join-Path $repo $EvidenceDirectory
    }
    [IO.Path]::GetFullPath($candidate)
}
[IO.Directory]::CreateDirectory($evidence) | Out-Null

$adbCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
    'adb.exe'
)
$adb = $adbCandidates | Where-Object {
    if ([IO.Path]::IsPathRooted($_)) { Test-Path -LiteralPath $_ -PathType Leaf }
    else { [bool](Get-Command $_ -ErrorAction SilentlyContinue) }
} | Select-Object -First 1
if (-not $adb) { throw 'ADB executable was not found.' }

$platformLabels = @{
    bilibili = '哔哩哔哩'
    douyu = '斗鱼'
    huya = '虎牙'
    douyin = '抖音'
    kuaishou = '快手'
}
$platformLabel = $platformLabels[$Platform]

function Start-AdbServer {
    $output = & $adb start-server 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb start-server failed ($LASTEXITCODE):`n$($output -join "`n")"
    }
}

function Invoke-Adb {
    param([Parameter(Mandatory = $true)][string[]] $AdbArguments)
    $output = & $adb -s $script:serial @AdbArguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = $output -join "`n"
    if ($exitCode -ne 0 -and $text -match '(?i)cannot connect to daemon|daemon still not running') {
        Start-AdbServer
        Start-Sleep -Milliseconds 350
        $output = & $adb -s $script:serial @AdbArguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    if ($exitCode -ne 0) {
        throw "adb failed ($exitCode): $($AdbArguments -join ' ')`n$($output -join "`n")"
    }
    $output
}

function Save-Text {
    param([string] $Name, [object] $Value)
    $Value | Out-File -LiteralPath (Join-Path $evidence $Name) -Encoding utf8 -Width 4096
}

function Save-UiDump {
    param([string] $Name)
    $remote = "/sdcard/purelive-record-$PID-$Name.xml"
    $local = Join-Path $evidence "$Name.xml"
    $failures = [Collections.Generic.List[string]]::new()
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            $dumpOutput = Invoke-Adb -AdbArguments @('shell', 'uiautomator', 'dump', '--compressed', $remote)
            $dumpText = $dumpOutput -join "`n"
            if ($dumpText -match '(?i)error|exception') { throw $dumpText }
            Invoke-Adb -AdbArguments @('pull', $remote, $local) | Out-Null
            if ((Test-Path -LiteralPath $local -PathType Leaf) -and (Get-Item -LiteralPath $local).Length -gt 0) {
                return
            }
            throw 'UI dump was empty.'
        } catch {
            $failures.Add("attempt ${attempt}: $($_.Exception.Message)")
            Start-Sleep -Milliseconds (350 * $attempt)
        } finally {
            try { Invoke-Adb -AdbArguments @('shell', 'rm', '-f', $remote) | Out-Null } catch {}
        }
    }
    throw "UI dump '$Name' failed after 4 attempts:`n$($failures -join "`n")"
}

function Save-Screenshot {
    param([string] $Name)
    $remote = "/sdcard/purelive-record-$PID-$Name.png"
    try {
        Invoke-Adb -AdbArguments @('shell', 'screencap', '-p', $remote) | Out-Null
        Invoke-Adb -AdbArguments @('pull', $remote, (Join-Path $evidence "$Name.png")) | Out-Null
    } finally {
        Invoke-Adb -AdbArguments @('shell', 'rm', '-f', $remote) | Out-Null
    }
}

function Wait-UiPattern {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Pattern,
        [int] $TimeoutSeconds = 20
    )
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        Save-UiDump $Name
        $xml = Get-Content -LiteralPath (Join-Path $evidence "$Name.xml") -Raw -Encoding UTF8
        if ($xml -match $Pattern) {
            return [pscustomobject]@{ Xml = $xml; ElapsedMs = $timer.ElapsedMilliseconds }
        }
        Start-Sleep -Milliseconds 600
    } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    throw "UI pattern did not settle within $TimeoutSeconds seconds: $Pattern"
}

function Test-UiSemanticEnabled {
    param(
        [Parameter(Mandatory = $true)][string] $Xml,
        [Parameter(Mandatory = $true)][string] $Semantic
    )
    try {
        [xml]$document = $Xml
        $matches = @(
            $document.SelectNodes('//node') | Where-Object {
                ($_.GetAttribute('text') -eq $Semantic -or $_.GetAttribute('content-desc') -eq $Semantic) -and
                $_.GetAttribute('enabled') -eq 'true' -and
                $_.GetAttribute('clickable') -eq 'true'
            }
        )
        return $matches.Count -gt 0
    } catch {
        return $false
    }
}

function Get-UiLabels {
    param([Parameter(Mandatory = $true)][string] $Xml)
    [xml]$document = $Xml
    @(
        $document.SelectNodes('//node') | ForEach-Object {
            @($_.GetAttribute('text'), $_.GetAttribute('content-desc'))
        } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
    )
}

function Wait-UiSemanticEnabled {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Semantic,
        [int] $TimeoutSeconds = 20
    )
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        Save-UiDump $Name
        $xml = Get-Content -LiteralPath (Join-Path $evidence "$Name.xml") -Raw -Encoding UTF8
        if (Test-UiSemanticEnabled -Xml $xml -Semantic $Semantic) {
            return [pscustomobject]@{ Xml = $xml; ElapsedMs = $timer.ElapsedMilliseconds }
        }
        Start-Sleep -Milliseconds 700
    } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    throw "Enabled UI semantic did not settle within $TimeoutSeconds seconds: $Semantic"
}

function Get-Foreground {
    $line = Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'activity', 'activities') |
        Select-String 'topResumedActivity|mResumedActivity' |
        Select-Object -First 1
    if ($line) { return $line.Line.Trim() }
    ''
}

function Wake-AndDismissKeyguard {
    Invoke-Adb -AdbArguments @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP') | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'wm', 'dismiss-keyguard') | Out-Null
    Start-Sleep -Milliseconds 250
    $policy = (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'window', 'policy')) -join "`n"
    $locked = $policy -match '(?im)(?:mShowingLockscreen|mKeyguardShowing|isKeyguardShowing|keyguardShowing|mDreamingLockscreen|isStatusBarKeyguard)\s*=\s*true'
    if (-not $locked) { return }

    $size = (Invoke-Adb -AdbArguments @('shell', 'wm', 'size')) -join "`n"
    if ($size -notmatch '(\d+)x(\d+)') { throw "Unexpected device size output: $size" }
    $width = [int]$Matches[1]
    $height = [int]$Matches[2]
    Invoke-Adb -AdbArguments @(
        'shell', 'input', 'swipe',
        [math]::Round($width * 0.5),
        [math]::Round($height * 0.84),
        [math]::Round($width * 0.5),
        [math]::Round($height * 0.24),
        '350'
    ) | Out-Null
    Start-Sleep -Milliseconds 350
    Invoke-Adb -AdbArguments @('shell', 'wm', 'dismiss-keyguard') | Out-Null
}

function Invoke-Ui {
    param(
        [ValidateSet('Tap', 'TapSemantic', 'Sequence')]
        [string] $Action,
        [string] $Value
    )
    $parameters = @{
        Serial = $script:serial
        CaptureOnFailure = $true
    }
    $parameters[$Action] = $Value
    & (Join-Path $repo 'tool\android_ui.ps1') @parameters |
        Out-File -LiteralPath (Join-Path $evidence ("ui-{0}-{1}.txt" -f $Action, ([Guid]::NewGuid().ToString('N')))) -Encoding utf8
}

function Get-PrivateRecordingFiles {
    $files = @(
        Invoke-Adb -AdbArguments @('shell', 'run-as', $Package, 'find', '.', '-type', 'f') |
            ForEach-Object { ([string]$_).Trim() } |
            Where-Object {
                $_ -match '(?i)[\\/]RECORDS[\\/].+\.(?:mp4|ts|flv|mkv)$'
            }
    )
    @($files | Sort-Object -Unique)
}

function ConvertTo-PosixLiteral {
    param([Parameter(Mandatory = $true)][string] $Value)
    "'" + $Value.Replace("'", "'\''") + "'"
}

function Get-PrivateFileInfo {
    param([Parameter(Mandatory = $true)][string] $Path)
    $literalPath = ConvertTo-PosixLiteral $Path
    $bytes = (Invoke-Adb -AdbArguments @('shell', 'run-as', $Package, 'stat', '-c', '%s', $literalPath)) -join ''
    $modified = (Invoke-Adb -AdbArguments @('shell', 'run-as', $Package, 'stat', '-c', '%Y', $literalPath)) -join ''
    if ($bytes -notmatch '^\d+$' -or $modified -notmatch '^\d+$') {
        throw "Unexpected stat output for ${Path}: bytes=$bytes modified=$modified"
    }
    [pscustomobject]@{
        Path = $Path
        Bytes = [long]$bytes
        ModifiedEpoch = [long]$modified
    }
}

function Wait-RecordingFileGrowth {
    param(
        [Parameter(Mandatory = $true)][string[]] $BeforeFiles,
        [int] $TimeoutSeconds = 30
    )
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $previousBytes = @{}
    do {
        $currentFiles = @(Get-PrivateRecordingFiles)
        foreach ($path in $currentFiles) {
            if ($path -in $BeforeFiles) { continue }
            $info = Get-PrivateFileInfo $path
            if ($previousBytes.ContainsKey($path)) {
                $earlierBytes = [long]$previousBytes[$path]
                if ($earlierBytes -gt 0 -and $info.Bytes -gt $earlierBytes) {
                    return [pscustomobject]@{
                        Path = $path
                        InitialBytes = $earlierBytes
                        FinalBytes = $info.Bytes
                        ElapsedMs = $timer.ElapsedMilliseconds
                    }
                }
            }
            $previousBytes[$path] = $info.Bytes
        }
        Start-Sleep -Seconds 2
    } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    throw 'The active recording file did not show positive byte growth.'
}

function Copy-PrivateFile {
    param(
        [Parameter(Mandatory = $true)][string] $Source,
        [Parameter(Mandatory = $true)][string] $Destination
    )
    $sourceLiteral = ConvertTo-PosixLiteral $Source
    $stagingPath = "./cache/purelive-recording-smoke-$PID.mp4"
    $stagingLiteral = ConvertTo-PosixLiteral $stagingPath
    Invoke-Adb -AdbArguments @('shell', 'run-as', $Package, 'mkdir', '-p', './cache') | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'run-as', $Package, 'cp', '--', $sourceLiteral, $stagingLiteral) | Out-Null

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $adb
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @(
        '-s', $script:serial,
        'exec-out', 'run-as', $Package, 'cat', '--', $stagingPath
    )) {
        $startInfo.ArgumentList.Add([string]$argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $destinationStream = $null
    try {
        if (-not $process.Start()) { throw 'Failed to start adb exec-out.' }
        $destinationStream = [IO.File]::Create($Destination)
        $process.StandardOutput.BaseStream.CopyTo($destinationStream)
        $destinationStream.Flush()
        $destinationStream.Dispose()
        $destinationStream = $null
        $errorText = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "adb exec-out failed ($($process.ExitCode)): $errorText"
        }
    } finally {
        if ($destinationStream) { $destinationStream.Dispose() }
        $process.Dispose()
        try { Invoke-Adb -AdbArguments @('shell', 'run-as', $Package, 'rm', '-f', $stagingLiteral) | Out-Null } catch {}
    }
}

Start-AdbServer
$deviceRows = & $adb devices -l
if ([string]::IsNullOrWhiteSpace($Serial)) {
    $devices = @(
        $deviceRows | ForEach-Object {
            if ($_ -match '^(\S+)\s+device(?:\s|$)') { $Matches[1] }
        }
    )
    $wireless = @($devices | Where-Object { $_ -match '^(?:\d{1,3}\.){3}\d{1,3}:\d+$' })
    if ($devices.Count -eq 1) { $script:serial = $devices[0] }
    elseif ($wireless.Count -eq 1) { $script:serial = $wireless[0] }
    else { throw 'Specify -Serial when a unique network ADB transport cannot be selected.' }
} else {
    $matched = @(
        $deviceRows | ForEach-Object {
            if ($_ -match '^(\S+)\s+device(?:\s|$)' -and $Matches[1] -eq $Serial) { $Matches[1] }
        }
    )
    if ($matched.Count -ne 1) { throw "Requested ADB serial '$Serial' is not online." }
    $script:serial = $Serial
}

$result = [ordered]@{
    schemaVersion = 1
    startedAt = [DateTime]::Now.ToString('o')
    serial = $script:serial
    package = $Package
    platform = $Platform
    platformLabel = $platformLabel
    requestedRecordSeconds = $RecordSeconds
    checks = [ordered]@{}
}
$monitorRemoved = $false
$recordingWallTimer = $null

try {
    $result.checks.deviceState = ((Invoke-Adb -AdbArguments @('get-state')) -join '').Trim()
    $runAsIdentity = (Invoke-Adb -AdbArguments @('shell', 'run-as', $Package, 'id')) -join "`n"
    Save-Text 'run-as.txt' $runAsIdentity
    $result.checks.runAsAvailable = $runAsIdentity -match 'uid=\d+'

    Wake-AndDismissKeyguard
    Save-Text 'keyguard-after-wake.txt' (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'window', 'policy'))
    Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $Package) | Out-Null
    Save-Text 'cold-start.txt' (
        Invoke-Adb -AdbArguments @('shell', 'am', 'start', '-W', '-n', "$Package/$Activity")
    )
    Start-Sleep -Seconds 7

    $beforeFiles = @(Get-PrivateRecordingFiles)
    Save-Text 'record-files-before.txt' $beforeFiles

    Invoke-Ui -Action TapSemantic -Value '热门'
    Start-Sleep -Milliseconds 1200
    Invoke-Ui -Action TapSemantic -Value $platformLabel
    Start-Sleep -Seconds 8
    Invoke-Ui -Action Tap -Value 'home.first_left_room'
    Start-Sleep -Seconds 12
    $result.checks.roomForeground = Get-Foreground
    Save-UiDump 'room-before-record'
    Save-Screenshot 'room-before-record'
    $roomXml = Get-Content -LiteralPath (Join-Path $evidence 'room-before-record.xml') -Raw -Encoding UTF8
    $result.checks.roomUiAlive = $roomXml.Contains('弹幕列表') -and $roomXml.Contains('弹幕设置')
    if (-not $result.checks.roomUiAlive) { throw "A live $Platform room did not open." }
    $visibleDanmakuLines = @(
        Get-UiLabels -Xml $roomXml | Where-Object { $_ -match '^.{1,48}[:：]\s*.+$' }
    )
    Save-Text 'visible-danmaku-lines.txt' $visibleDanmakuLines
    $result.checks.visibleDanmakuLineCount = $visibleDanmakuLines.Count
    $result.checks.liveDanmakuVisible = $visibleDanmakuLines.Count -ge 3

    Invoke-Ui -Action Tap -Value 'live.quality'
    $qualityState = Wait-UiPattern `
        -Name 'quality-before-record' `
        -Pattern '原画|蓝光|超清|高清|标清|流畅|省流|自动|origin|uhd|hd|sd|ld' `
        -TimeoutSeconds 12
    Save-Screenshot 'quality-before-record'
    $qualityOptions = @(
        Get-UiLabels -Xml $qualityState.Xml | Where-Object {
            $_ -match '^(?:原画.*|蓝光.*|超清.*|高清.*|标清.*|流畅.*|省流.*|自动.*|origin|uhd|hd|sd|ld)$'
        }
    )
    $result.checks.qualityOptions = $qualityOptions
    $result.checks.qualitySheetVisible = $qualityOptions.Count -gt 0
    Invoke-Adb -AdbArguments @('shell', 'input', 'keyevent', '4') | Out-Null
    Wait-UiPattern -Name 'room-after-quality-check' -Pattern '弹幕列表' -TimeoutSeconds 12 | Out-Null

    Invoke-Ui -Action Tap -Value 'live.line'
    $lineState = Wait-UiPattern `
        -Name 'line-before-record' `
        -Pattern '线路\s*\d+|主线路|备用线路|播放线路' `
        -TimeoutSeconds 12
    Save-Screenshot 'line-before-record'
    $lineOptions = @(
        Get-UiLabels -Xml $lineState.Xml | Where-Object {
            $_ -match '^(?:线路\s*\d+|主线路|备用线路|播放线路.*)$'
        }
    )
    $result.checks.lineOptions = $lineOptions
    $result.checks.lineSheetVisible = $lineOptions.Count -gt 0
    Invoke-Adb -AdbArguments @('shell', 'input', 'keyevent', '4') | Out-Null
    Wait-UiPattern -Name 'room-after-line-check' -Pattern '弹幕列表' -TimeoutSeconds 12 | Out-Null

    Invoke-Ui -Action Tap -Value 'live.record'
    $preflightDialog = Wait-UiPattern `
        -Name 'record-dialog-preflight' `
        -Pattern '立即启动录制|停止录制|取消监控' `
        -TimeoutSeconds 10
    if (Test-UiSemanticEnabled -Xml $preflightDialog.Xml -Semantic '停止录制') {
        Invoke-Ui -Action TapSemantic -Value '停止录制'
        $preflightDialog = Wait-UiSemanticEnabled `
            -Name 'record-dialog-after-preflight-stop' `
            -Semantic '取消监控' `
            -TimeoutSeconds 60
    }
    if (Test-UiSemanticEnabled -Xml $preflightDialog.Xml -Semantic '取消监控') {
        Invoke-Ui -Action TapSemantic -Value '取消监控'
        Wait-UiPattern -Name 'room-after-preflight-cleanup' -Pattern '弹幕列表' -TimeoutSeconds 12 | Out-Null
        Start-Sleep -Seconds 2
        Invoke-Ui -Action Tap -Value 'live.record'
        $preflightDialog = Wait-UiSemanticEnabled `
            -Name 'record-dialog-before-start' `
            -Semantic '立即启动录制' `
            -TimeoutSeconds 10
    }
    if (-not (Test-UiSemanticEnabled -Xml $preflightDialog.Xml -Semantic '立即启动录制')) {
        throw 'The record action did not reach the one-shot start state.'
    }
    Invoke-Ui -Action TapSemantic -Value '立即启动录制'
    $runningState = Wait-UiPattern -Name 'room-recording' -Pattern '录制中' -TimeoutSeconds 30
    $recordingWallTimer = [Diagnostics.Stopwatch]::StartNew()
    $result.checks.recordStartMs = $runningState.ElapsedMs
    Save-Screenshot 'room-recording'

    Start-Sleep -Seconds ([math]::Min(15, $RecordSeconds))
    Invoke-Ui -Action Tap -Value 'live.record'
    Wait-UiSemanticEnabled -Name 'record-dialog-running' -Semantic '进入录制中心' -TimeoutSeconds 10 | Out-Null
    Invoke-Ui -Action TapSemantic -Value '进入录制中心'
    Start-Sleep -Seconds 4
    Save-Screenshot 'record-center-running'
    $recordCenterScreenshot = Join-Path $evidence 'record-center-running.png'
    $result.checks.recordingCenterScreenshotCaptured =
        (Test-Path -LiteralPath $recordCenterScreenshot -PathType Leaf) -and
        (Get-Item -LiteralPath $recordCenterScreenshot).Length -gt 0
    # The shell uiautomator command hard-codes a one-second quiet window. A
    # recorder page that legitimately publishes time/size every second may
    # never become idle, so use two real private-file samples for the machine
    # gate and keep the screenshot for visual UI verification.
    $growth = Wait-RecordingFileGrowth -BeforeFiles $beforeFiles -TimeoutSeconds 30
    $result.checks.runningFileGrowthObserved = $growth.FinalBytes -gt $growth.InitialBytes
    $result.checks.runningFilePath = $growth.Path
    $result.checks.runningFileInitialBytes = $growth.InitialBytes
    $result.checks.runningFileFinalBytes = $growth.FinalBytes
    $result.checks.runningFileGrowthMs = $growth.ElapsedMs

    $remainingSeconds = [math]::Max(
        0,
        [math]::Ceiling($RecordSeconds - $recordingWallTimer.Elapsed.TotalSeconds)
    )
    if ($remainingSeconds -gt 0) { Start-Sleep -Seconds $remainingSeconds }

    Invoke-Adb -AdbArguments @('shell', 'input', 'keyevent', '4') | Out-Null
    Wait-UiPattern -Name 'room-before-stop' -Pattern '弹幕列表' -TimeoutSeconds 15 | Out-Null
    Invoke-Ui -Action Tap -Value 'live.record'
    Wait-UiSemanticEnabled -Name 'record-dialog-before-stop' -Semantic '停止录制' -TimeoutSeconds 10 | Out-Null
    Invoke-Ui -Action TapSemantic -Value '停止录制'
    $recordingWallTimer.Stop()
    $result.checks.recordingWallSeconds = [math]::Round($recordingWallTimer.Elapsed.TotalSeconds, 3)
    $stoppedHeader = Wait-UiPattern -Name 'room-record-stopped' -Pattern '已监控|录制任务' -TimeoutSeconds 60
    $result.checks.stopFinalizeMs = $stoppedHeader.ElapsedMs
    Save-Screenshot 'room-record-stopped'

    Invoke-Ui -Action Tap -Value 'live.record'
    Wait-UiPattern -Name 'record-dialog-after-stop' -Pattern '进入录制中心' -TimeoutSeconds 10 | Out-Null
    Invoke-Ui -Action TapSemantic -Value '进入录制中心'
    $finalCenter = Wait-UiPattern -Name 'record-center-stopped' -Pattern '已停止' -TimeoutSeconds 20
    Save-Screenshot 'record-center-stopped'
    $result.checks.stoppedStatusVisible = $finalCenter.Xml.Contains('已停止')
    $result.checks.failureAbsent = -not ($finalCenter.Xml -match '录制失败|最近失败|输入的直播流地址格式有误')

    $afterFiles = @(Get-PrivateRecordingFiles)
    Save-Text 'record-files-after.txt' $afterFiles
    $newFinalFiles = @(
        $afterFiles | Where-Object {
            $_ -notin $beforeFiles -and $_ -match '(?i)\.mp4$'
        }
    )
    $newFileInfo = @($newFinalFiles | ForEach-Object { Get-PrivateFileInfo $_ })
    $newest = $newFileInfo | Sort-Object ModifiedEpoch -Descending | Select-Object -First 1
    if (-not $newest) { throw 'The stopped recording did not create a new MP4 file.' }
    $result.checks.recordingPath = $newest.Path
    $result.checks.recordingBytes = $newest.Bytes
    $result.checks.recordingFileNonEmpty = $newest.Bytes -gt 100000

    $localRecording = Join-Path $evidence 'recording.mp4'
    Copy-PrivateFile -Source $newest.Path -Destination $localRecording
    $localHash = (Get-FileHash -LiteralPath $localRecording -Algorithm SHA256).Hash
    $result.checks.recordingSha256 = $localHash

    $ffprobe = Get-Command ffprobe.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $ffprobe) { throw 'ffprobe.exe is required for the Android recording smoke.' }
    $probeOutput = & $ffprobe.Source -v error -show_format -show_streams -of json $localRecording 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ffprobe failed:`n$($probeOutput -join "`n")" }
    $probeText = $probeOutput -join "`n"
    Save-Text 'recording-ffprobe.json' $probeText
    $probe = $probeText | ConvertFrom-Json
    $durationSeconds = [double]::Parse(
        [string]$probe.format.duration,
        [Globalization.CultureInfo]::InvariantCulture
    )
    $result.checks.mediaDurationSeconds = $durationSeconds
    $recordingWallSeconds = [double]$result.checks.recordingWallSeconds
    $result.checks.mediaDurationPlausible =
        $durationSeconds -ge ([math]::Max(8, $recordingWallSeconds - 12)) -and
        $durationSeconds -le ($recordingWallSeconds + 12)
    $result.checks.hasVideoStream = @($probe.streams | Where-Object codec_type -eq 'video').Count -gt 0
    $result.checks.hasAudioStream = @($probe.streams | Where-Object codec_type -eq 'audio').Count -gt 0

    # Remove only the scheduler entry created by this smoke; retain the MP4 as
    # evidence. This prevents the next device turn from inheriting a monitor.
    Invoke-Adb -AdbArguments @('shell', 'input', 'keyevent', '4') | Out-Null
    Wait-UiPattern -Name 'room-before-monitor-cleanup' -Pattern '弹幕列表' -TimeoutSeconds 15 | Out-Null
    Invoke-Ui -Action Tap -Value 'live.record'
    Wait-UiSemanticEnabled -Name 'record-dialog-cleanup' -Semantic '取消监控' -TimeoutSeconds 10 | Out-Null
    Invoke-Ui -Action TapSemantic -Value '取消监控'
    $cleanupState = Wait-UiPattern -Name 'room-after-monitor-cleanup' -Pattern '录制' -TimeoutSeconds 10
    $monitorRemoved = -not ($cleanupState.Xml -match '已监控|录制中')
    $result.checks.monitorRemoved = $monitorRemoved

    $appPid = ((Invoke-Adb -AdbArguments @('shell', 'pidof', $Package)) -join '').Trim().Split(' ')[0]
    if ($appPid -match '^\d+$') {
        Save-Text 'logcat-tail.txt' (
            Invoke-Adb -AdbArguments @('logcat', '-d', '-v', 'threadtime', "--pid=$appPid", '-t', '3000')
        )
    } else {
        Save-Text 'logcat-tail.txt' ''
    }
    $logText = Get-Content -LiteralPath (Join-Path $evidence 'logcat-tail.txt') -Raw -Encoding UTF8
    $result.checks.noFatal = -not ($logText -match 'FATAL EXCEPTION|ANR in com\.mystyle\.purelive')
} finally {
    try { Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $Package) | Out-Null } catch {}
    Start-Sleep -Seconds 2
    $processAfterStop = & $adb -s $script:serial shell pidof $Package 2>&1
    $processAfterStopExitCode = $LASTEXITCODE
    Save-Text 'process-after-stop.txt' @(
        "exitCode=$processAfterStopExitCode"
        $processAfterStop
    )
    $result.checks.processGoneAfterStop =
        $processAfterStopExitCode -ne 0 -or [string]::IsNullOrWhiteSpace(($processAfterStop -join ''))
    try {
        $powerAfterStop = Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'power')
        Save-Text 'wake-locks-after-stop.txt' $powerAfterStop
        # dumpsys power also contains historical wake-lock events. Restrict the
        # assertion to the current "Wake Locks" section so an earlier ACQ/REL
        # event for Pure Live does not turn a clean shutdown into a false fail.
        $powerText = $powerAfterStop -join "`n"
        $activeWakeLockMatch = [regex]::Match(
            $powerText,
            '(?ms)^Wake Locks:\s*size=\d+\s*\r?\n.*?(?=^Suspend Blockers:)'
        )
        $activeWakeLockText = if ($activeWakeLockMatch.Success) {
            $activeWakeLockMatch.Value.TrimEnd()
        } else {
            ''
        }
        Save-Text 'active-wake-locks-after-stop.txt' $activeWakeLockText
        $result.checks.activeWakeLockSectionParsed = $activeWakeLockMatch.Success
        $result.checks.wakeLockGoneAfterStop =
            $activeWakeLockMatch.Success -and
            -not ($activeWakeLockText -match [regex]::Escape($Package))
    } catch {
        $result.checks.activeWakeLockSectionParsed = $false
        $result.checks.wakeLockGoneAfterStop = $false
    }
    $result.completedAt = [DateTime]::Now.ToString('o')
    $result.monitorRemoved = $monitorRemoved
    $result | ConvertTo-Json -Depth 10 | Out-File -LiteralPath (Join-Path $evidence 'summary.json') -Encoding utf8
}

$assertions = [ordered]@{
    deviceReady = ($result.checks.deviceState -eq 'device')
    runAsAvailable = [bool]$result.checks.runAsAvailable
    roomForeground = ($result.checks.roomForeground -match $Package)
    roomUiAlive = [bool]$result.checks.roomUiAlive
    liveDanmakuVisible = [bool]$result.checks.liveDanmakuVisible
    qualitySheetVisible = [bool]$result.checks.qualitySheetVisible
    lineSheetVisible = [bool]$result.checks.lineSheetVisible
    recordingCenterScreenshotCaptured = [bool]$result.checks.recordingCenterScreenshotCaptured
    runningFileGrowthObserved = [bool]$result.checks.runningFileGrowthObserved
    stoppedStatusVisible = [bool]$result.checks.stoppedStatusVisible
    failureAbsent = [bool]$result.checks.failureAbsent
    recordingFileNonEmpty = [bool]$result.checks.recordingFileNonEmpty
    mediaDurationPlausible = [bool]$result.checks.mediaDurationPlausible
    hasVideoStream = [bool]$result.checks.hasVideoStream
    hasAudioStream = [bool]$result.checks.hasAudioStream
    monitorRemoved = [bool]$result.checks.monitorRemoved
    noFatal = [bool]$result.checks.noFatal
    processGoneAfterStop = [bool]$result.checks.processGoneAfterStop
    activeWakeLockSectionParsed = [bool]$result.checks.activeWakeLockSectionParsed
    wakeLockGoneAfterStop = [bool]$result.checks.wakeLockGoneAfterStop
}
$result.assertions = $assertions
$result | ConvertTo-Json -Depth 10 | Out-File -LiteralPath (Join-Path $evidence 'summary.json') -Encoding utf8
$failed = @($assertions.GetEnumerator() | Where-Object { -not [bool]$_.Value })
if ($failed.Count -gt 0) {
    throw "Android recording smoke assertions failed: $((@($failed | ForEach-Object Key)) -join ', '). See $evidence\summary.json"
}

Write-Output (Join-Path $evidence 'summary.json')
