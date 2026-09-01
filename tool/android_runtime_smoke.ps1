[CmdletBinding()]
param(
    [string] $Serial,
    [string] $EvidenceDirectory,
    [string] $Package = 'com.mystyle.purelive',
    [string] $Activity = '.MainActivity'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$evidence = if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
    Join-Path $repo ("local-artifacts\diagnostics\android-runtime-smoke-{0}" -f ([DateTime]::Now.ToString('yyyyMMddTHHmmssfff')))
} else {
    $candidateEvidence = if ([System.IO.Path]::IsPathRooted($EvidenceDirectory)) {
        $EvidenceDirectory
    } else {
        Join-Path $repo $EvidenceDirectory
    }
    [System.IO.Path]::GetFullPath($candidateEvidence)
}
[System.IO.Directory]::CreateDirectory($evidence) | Out-Null
$package = $Package
$activity = $Activity
$adbCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
    'adb.exe'
)
$adb = $adbCandidates | Where-Object {
    if ([System.IO.Path]::IsPathRooted($_)) { Test-Path -LiteralPath $_ }
    else { [bool](Get-Command $_ -ErrorAction SilentlyContinue) }
} | Select-Object -First 1
if (-not $adb) { throw 'ADB executable was not found.' }

function Start-AdbServer {
    $serverResult = & $adb start-server 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb start-server failed ($LASTEXITCODE):`n$($serverResult -join "`n")"
    }
}

Start-AdbServer

$deviceRows = & $adb devices -l
if ([string]::IsNullOrWhiteSpace($Serial)) {
    $deviceCandidates = @(
        $deviceRows | ForEach-Object {
            if ($_ -match '^(\S+)\s+device(?:\s|$)') { $Matches[1] }
        }
    )
    $wirelessCandidates = @(
        $deviceCandidates | Where-Object {
            $_ -match '^(?:\d{1,3}\.){3}\d{1,3}:\d+$'
        }
    )
    if ($deviceCandidates.Count -eq 1) {
        $serial = $deviceCandidates[0]
    } elseif ($wirelessCandidates.Count -eq 1) {
        # A single phone can appear as both USB and wireless ADB. This workflow
        # deliberately prefers the unique network transport requested by the
        # project while still rejecting two different network targets.
        $serial = $wirelessCandidates[0]
    } else {
        throw "Specify -Serial when a unique device or network transport cannot be selected; devices=$($deviceCandidates.Count), network=$($wirelessCandidates.Count)."
    }
} else {
    $matchingDevice = @(
        $deviceRows | ForEach-Object {
            if ($_ -match '^(\S+)\s+device(?:\s|$)' -and $Matches[1] -eq $Serial) { $Matches[1] }
        }
    )
    if ($matchingDevice.Count -ne 1) {
        throw "Requested ADB serial '$Serial' is not connected in device state."
    }
    $serial = $Serial
}

function Invoke-Adb {
    param([Parameter(Mandatory = $true)][string[]] $AdbArguments)
    $result = & $adb -s $serial @AdbArguments 2>&1
    $exitCode = $LASTEXITCODE
    $output = $result -join "`n"
    if ($exitCode -ne 0 -and $output -match '(?i)cannot connect to daemon|daemon still not running') {
        Start-AdbServer
        Start-Sleep -Milliseconds 350
        $result = & $adb -s $serial @AdbArguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    if ($exitCode -ne 0) {
        throw "adb failed ($exitCode): $($AdbArguments -join ' ')`n$($result -join "`n")"
    }
    $result
}

function Wake-AndDismissKeyguard {
    Invoke-Adb -AdbArguments @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP') | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'wm', 'dismiss-keyguard') | Out-Null
    Start-Sleep -Milliseconds 250
    $policyText = (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'window', 'policy')) -join "`n"
    $stillLocked = $policyText -match '(?im)(?:mShowingLockscreen|mKeyguardShowing|isKeyguardShowing|keyguardShowing|mDreamingLockscreen|isStatusBarKeyguard)\s*=\s*true'
    if ($stillLocked) {
        $sizeText = ((Invoke-Adb -AdbArguments @('shell', 'wm', 'size')) -join "`n")
        if ($sizeText -notmatch '(\d+)x(\d+)') { throw "Unexpected device size output: $sizeText" }
        $width = [int]$Matches[1]
        $height = [int]$Matches[2]
        $x = [math]::Round($width * 0.5)
        $startY = [math]::Round($height * 0.84)
        $endY = [math]::Round($height * 0.24)
        Invoke-Adb -AdbArguments @('shell', 'input', 'swipe', $x, $startY, $x, $endY, '350') | Out-Null
        Start-Sleep -Milliseconds 350
        Invoke-Adb -AdbArguments @('shell', 'wm', 'dismiss-keyguard') | Out-Null
    }
}

function Save-Text {
    param([string] $Name, [object] $Value)
    $Value | Out-File -LiteralPath (Join-Path $evidence $Name) -Encoding utf8 -Width 4096
}

function Save-UiDump {
    param([string] $Name)
    $remote = "/sdcard/purelive-$PID-$Name.xml"
    try {
        Invoke-Adb -AdbArguments @('shell', 'uiautomator', 'dump', '--compressed', $remote) | Out-Null
        Invoke-Adb -AdbArguments @('pull', $remote, (Join-Path $evidence "$Name.xml")) | Out-Null
    } finally {
        Invoke-Adb -AdbArguments @('shell', 'rm', '-f', $remote) | Out-Null
    }
}

function Save-Screenshot {
    param([string] $Name)
    $remote = "/sdcard/purelive-$PID-$Name.png"
    try {
        Invoke-Adb -AdbArguments @('shell', 'screencap', '-p', $remote) | Out-Null
        Invoke-Adb -AdbArguments @('pull', $remote, (Join-Path $evidence "$Name.png")) | Out-Null
    } finally {
        Invoke-Adb -AdbArguments @('shell', 'rm', '-f', $remote) | Out-Null
    }
}

function Wait-UiTextState {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Needle,
        [Parameter(Mandatory = $true)][bool] $Present,
        [int] $TimeoutSeconds = 10
    )
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        Save-UiDump $Name
        $xmlText = Get-Content -LiteralPath (Join-Path $evidence "$Name.xml") -Raw -Encoding UTF8
        if ($xmlText.Contains($Needle) -eq $Present) {
            return [pscustomobject]@{ Xml = $xmlText; ElapsedMs = $timer.ElapsedMilliseconds }
        }
        Start-Sleep -Milliseconds 500
    } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    throw "UI state '$Needle' present=$Present did not settle within $TimeoutSeconds seconds."
}

function Get-Foreground {
    $line = Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'activity', 'activities') | Select-String 'topResumedActivity|mResumedActivity' | Select-Object -First 1
    if ($line) { return $line.Line.Trim() }
    ''
}

$result = [ordered]@{
    schemaVersion = 1
    startedAt = [DateTime]::Now.ToString('o')
    serial = $serial
    package = $package
    checks = [ordered]@{}
}

try {
    $result.checks.deviceState = ((Invoke-Adb -AdbArguments @('get-state')) -join '').Trim()
    $result.checks.model = ((Invoke-Adb -AdbArguments @('shell', 'getprop', 'ro.product.model')) -join '').Trim()
    $result.checks.android = ((Invoke-Adb -AdbArguments @('shell', 'getprop', 'ro.build.version.release')) -join '').Trim()
    $result.checks.sdk = ((Invoke-Adb -AdbArguments @('shell', 'getprop', 'ro.build.version.sdk')) -join '').Trim()
    Save-Text 'device.txt' (Invoke-Adb -AdbArguments @('shell', 'getprop'))
    Save-Text 'package.txt' (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'package', $package))
    Save-Text 'display-before.txt' (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'display'))
    Save-Text 'foreground-before.txt' (Get-Foreground)

    & (Join-Path $repo 'tool\android_ui.ps1') -Validate -Serial $serial | Out-File -LiteralPath (Join-Path $evidence 'ui-map-validation.txt') -Encoding utf8

    # A previous lane may finish with the display asleep or keyguard showing.
    # Restore an interactive surface inside this lease before any coordinate
    # action; this touches no package data and is recorded for diagnosis.
    Wake-AndDismissKeyguard
    Start-Sleep -Milliseconds 750
    Save-Text 'keyguard-after-wake.txt' (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'window', 'policy'))

    Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $package) | Out-Null
    $start = Invoke-Adb -AdbArguments @('shell', 'am', 'start', '-W', '-n', "$package/$activity")
    Save-Text 'cold-start.txt' $start
    Start-Sleep -Seconds 7
    $result.checks.coldStartForeground = Get-Foreground
    Save-UiDump 'home-cold'
    Save-Screenshot 'home-cold'

    & (Join-Path $repo 'tool\android_ui.ps1') -Sequence refresh_home -Serial $serial -CaptureOnFailure |
        Out-File -LiteralPath (Join-Path $evidence 'refresh-home.txt') -Encoding utf8
    Start-Sleep -Seconds 5
    Save-UiDump 'home-refreshed'
    Save-Screenshot 'home-refreshed'

    & (Join-Path $repo 'tool\android_ui.ps1') -Sequence enter_first_bilibili_room -Serial $serial -CaptureOnFailure |
        Out-File -LiteralPath (Join-Path $evidence 'enter-room.txt') -Encoding utf8
    Start-Sleep -Seconds 12
    $result.checks.roomForeground = Get-Foreground
    Save-UiDump 'room-playing'
    Save-Screenshot 'room-playing'
    $roomXml = Get-Content -LiteralPath (Join-Path $evidence 'room-playing.xml') -Raw -Encoding UTF8
    $result.checks.roomUiAlive = $roomXml.Contains('弹幕列表') -and $roomXml.Contains('弹幕设置')
    $result.checks.danmakuConnected = $roomXml.Contains('弹幕服务器连接正常')
    $result.checks.hasQuality = $roomXml.Contains('原画') -or $roomXml.Contains('清晰度')
    $result.checks.hasLine = $roomXml.Contains('线路')
    if (-not $result.checks.roomUiAlive) {
        throw 'Popular-feed navigation did not open a live-room UI; stopping before mode/PiP coordinates.'
    }

    & (Join-Path $repo 'tool\android_ui.ps1') -Sequence toggle_audio -Serial $serial -CaptureOnFailure |
        Out-File -LiteralPath (Join-Path $evidence 'audio-on.txt') -Encoding utf8
    $audioState = Wait-UiTextState -Name 'room-audio' -Needle '纯音频模式' -Present $true -TimeoutSeconds 10
    $result.checks.audioModeActive = $true
    $result.checks.audioSwitchMs = $audioState.ElapsedMs
    Save-Screenshot 'room-audio'

    & (Join-Path $repo 'tool\android_ui.ps1') -Sequence toggle_audio -Serial $serial -CaptureOnFailure |
        Out-File -LiteralPath (Join-Path $evidence 'audio-off.txt') -Encoding utf8
    $videoState = Wait-UiTextState -Name 'room-video-restored' -Needle '纯音频模式' -Present $false -TimeoutSeconds 10
    Save-Screenshot 'room-video-restored'
    $result.checks.videoModeRestored = $videoState.Xml.Contains('弹幕列表')
    $result.checks.videoSwitchMs = $videoState.ElapsedMs
    Start-Sleep -Seconds 4
    Save-Screenshot 'room-video-settled'

    & (Join-Path $repo 'tool\android_ui.ps1') -Sequence enter_pip -Serial $serial -CaptureOnFailure |
        Out-File -LiteralPath (Join-Path $evidence 'enter-pip.txt') -Encoding utf8
    Start-Sleep -Seconds 4
    Save-Text 'pip-activity.txt' (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'activity', 'activities'))
    Save-Screenshot 'system-pip'
    $pipState = Get-Content -LiteralPath (Join-Path $evidence 'pip-activity.txt') -Raw -Encoding UTF8
    $result.checks.pipReported = $pipState -match 'pictureInPicture|mLastReportedPictureInPictureMode=true|supportsPictureInPicture'

    Invoke-Adb -AdbArguments @('shell', 'am', 'start', '-W', '-n', "$package/$activity") | Out-Null
    Start-Sleep -Seconds 7
    Save-UiDump 'room-after-pip'
    Save-Screenshot 'room-after-pip'
    $afterPipXml = Get-Content -LiteralPath (Join-Path $evidence 'room-after-pip.xml') -Raw -Encoding UTF8
    $result.checks.afterPipForeground = Get-Foreground
    $result.checks.afterPipDanmakuUiAlive = $afterPipXml.Contains('弹幕列表') -and $afterPipXml.Contains('弹幕设置')

    $memInfo = Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'meminfo', $package)
    Save-Text 'meminfo-playing.txt' $memInfo
    $memText = $memInfo -join "`n"
    if ($memText -match 'TOTAL PSS:\s+(\d+).*?TOTAL RSS:\s+(\d+).*?TOTAL SWAP PSS:\s+(\d+)') {
        $result.checks.totalPssKb = [long]$Matches[1]
        $result.checks.totalRssKb = [long]$Matches[2]
        $result.checks.totalSwapPssKb = [long]$Matches[3]
    }

    $gfxInfo = Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'gfxinfo', $package)
    Save-Text 'gfxinfo-playing.txt' $gfxInfo
    $gfxText = $gfxInfo -join "`n"
    if ($gfxText -match 'Total frames rendered:\s+(\d+)') {
        $result.checks.totalFramesRendered = [long]$Matches[1]
    }
    if ($gfxText -match 'Janky frames:\s+(\d+)\s+\(([\d.]+)%\)') {
        $result.checks.jankyFrames = [long]$Matches[1]
        $result.checks.jankyPercent = [double]::Parse($Matches[2], [Globalization.CultureInfo]::InvariantCulture)
    }
    foreach ($percentile in @(50, 90, 95, 99)) {
        if ($gfxText -match ("{0}th percentile:\s+(\d+)ms" -f $percentile)) {
            $result.checks["frameP${percentile}Ms"] = [long]$Matches[1]
        }
    }
    Save-Text 'surfaceflinger-playing.txt' (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'SurfaceFlinger'))
    $appPid = ((Invoke-Adb -AdbArguments @('shell', 'pidof', $package)) -join '').Trim().Split(' ')[0]
    if ($appPid -match '^\d+$') {
        $processStatus = Invoke-Adb -AdbArguments @('shell', 'cat', "/proc/$appPid/status")
        Save-Text 'process-status-playing.txt' $processStatus
        $processStatusText = $processStatus -join "`n"
        if ($processStatusText -match '(?m)^Threads:\s+(\d+)') {
            $result.checks.processThreads = [long]$Matches[1]
        }
        $cpuInfo = Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'cpuinfo', $package)
        Save-Text 'cpuinfo-playing.txt' $cpuInfo
        $cpuText = $cpuInfo -join "`n"
        if ($cpuText -match ("([\d.]+)%\s+\d+/{0}(?:\s|:|$)" -f [regex]::Escape($package))) {
            $result.checks.processCpuPercent = [double]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture)
        }
        Save-Text 'logcat-tail.txt' (Invoke-Adb -AdbArguments @('logcat', '-d', '-v', 'threadtime', "--pid=$appPid", '-t', '2500'))
    } else {
        Save-Text 'logcat-tail.txt' ''
    }
    $logText = Get-Content -LiteralPath (Join-Path $evidence 'logcat-tail.txt') -Raw -Encoding UTF8
    $result.checks.noFatal = -not ($logText -match 'FATAL EXCEPTION|ANR in com\.mystyle\.purelive')

    Invoke-Adb -AdbArguments @('shell', 'input', 'keyevent', '4') | Out-Null
    Start-Sleep -Seconds 3
    Save-UiDump 'home-after-room'
    $result.checks.returnedForeground = Get-Foreground
} finally {
    try { Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $package) | Out-Null } catch {}
    Start-Sleep -Seconds 2
    try { Save-Text 'process-after-stop.txt' (Invoke-Adb -AdbArguments @('shell', 'pidof', $package)) } catch {}
    try { Save-Text 'wake-locks-after-stop.txt' (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'power')) } catch {}
    $result.completedAt = [DateTime]::Now.ToString('o')
    $result | ConvertTo-Json -Depth 8 | Out-File -LiteralPath (Join-Path $evidence 'summary.json') -Encoding utf8
}

$assertions = [ordered]@{
    deviceReady = ($result.checks.deviceState -eq 'device')
    coldStartForeground = ($result.checks.coldStartForeground -match $package)
    roomForeground = ($result.checks.roomForeground -match $package)
    roomUiAlive = [bool]$result.checks.roomUiAlive
    danmakuConnected = [bool]$result.checks.danmakuConnected
    hasQuality = [bool]$result.checks.hasQuality
    hasLine = [bool]$result.checks.hasLine
    audioModeActive = [bool]$result.checks.audioModeActive
    videoModeRestored = [bool]$result.checks.videoModeRestored
    pipReported = [bool]$result.checks.pipReported
    afterPipForeground = ($result.checks.afterPipForeground -match $package)
    afterPipDanmakuUiAlive = [bool]$result.checks.afterPipDanmakuUiAlive
    noFatal = [bool]$result.checks.noFatal
    returnedForeground = ($result.checks.returnedForeground -match $package)
}
$result.assertions = $assertions
$result | ConvertTo-Json -Depth 8 | Out-File -LiteralPath (Join-Path $evidence 'summary.json') -Encoding utf8
$failedAssertions = @($assertions.GetEnumerator() | Where-Object { -not [bool]$_.Value })
if ($failedAssertions.Count -gt 0) {
    $failedNames = $failedAssertions | ForEach-Object Key
    throw "Android smoke assertions failed: $($failedNames -join ', '). See $evidence\summary.json"
}

Write-Output (Join-Path $evidence 'summary.json')
