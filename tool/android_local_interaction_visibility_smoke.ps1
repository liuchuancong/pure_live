[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ApkPath,
    [string] $Serial,
    [string] $EvidenceDirectory,
    [string] $Package = 'com.mystyle.purelive'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$apk = (Resolve-Path $ApkPath).Path
$evidence = if ($EvidenceDirectory) {
    [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($EvidenceDirectory)) { $EvidenceDirectory } else { Join-Path $repo $EvidenceDirectory }))
} else {
    Join-Path $repo ("local-artifacts\diagnostics\android-local-interaction-{0}" -f (Get-Date -Format 'yyyyMMddTHHmmssfff'))
}
[IO.Directory]::CreateDirectory($evidence) | Out-Null

$adb = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
    'adb.exe'
) | Where-Object {
    if ([IO.Path]::IsPathRooted($_)) { Test-Path -LiteralPath $_ }
    else { [bool](Get-Command $_ -ErrorAction SilentlyContinue) }
} | Select-Object -First 1
if (-not $adb) { throw 'ADB executable was not found.' }

$adbServerRecoveries = 0
function Start-AdbServer {
    $serverResult = & $adb start-server 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb start-server failed ($LASTEXITCODE):`n$($serverResult -join "`n")"
    }
}

Start-AdbServer

$deviceRows = & $adb devices -l
if (-not $Serial) {
    $devices = @($deviceRows | ForEach-Object { if ($_ -match '^(\S+)\s+device(?:\s|$)') { $Matches[1] } })
    $network = @($devices | Where-Object { $_ -match '^(?:\d{1,3}\.){3}\d{1,3}:\d+$' })
    if ($devices.Count -eq 1) { $Serial = $devices[0] }
    elseif ($network.Count -eq 1) { $Serial = $network[0] }
    else { throw "Specify -Serial; devices=$($devices.Count), network=$($network.Count)." }
}

function Invoke-Adb {
    param([Parameter(Mandatory = $true)][string[]] $AdbArguments)
    $result = & $adb -s $Serial @AdbArguments 2>&1
    $exitCode = $LASTEXITCODE
    $output = $result -join "`n"
    if ($exitCode -ne 0 -and $output -match '(?i)cannot connect to daemon|daemon still not running') {
        Start-AdbServer
        $script:adbServerRecoveries++
        Start-Sleep -Milliseconds 350
        $result = & $adb -s $Serial @AdbArguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    if ($exitCode -ne 0) {
        throw "adb failed ($exitCode): $($AdbArguments -join ' ')`n$($result -join "`n")"
    }
    $result
}

function Save-UiDump {
    param([Parameter(Mandatory = $true)][string] $Name)
    $remote = "/sdcard/purelive-$PID-$Name.xml"
    $local = Join-Path $evidence "$Name.xml"
    try {
        Invoke-Adb -AdbArguments @('shell', 'timeout', '10', 'uiautomator', 'dump', '--compressed', $remote) | Out-Null
        Invoke-Adb -AdbArguments @('pull', $remote, $local) | Out-Null
    } finally {
        try { Invoke-Adb -AdbArguments @('shell', 'rm', '-f', $remote) | Out-Null } catch {}
    }
    [xml](Get-Content -LiteralPath $local -Raw -Encoding UTF8)
}

function Save-Screenshot {
    param([Parameter(Mandatory = $true)][string] $Name)
    $remote = "/sdcard/purelive-$PID-$Name.png"
    try {
        Invoke-Adb -AdbArguments @('shell', 'screencap', '-p', $remote) | Out-Null
        Invoke-Adb -AdbArguments @('pull', $remote, (Join-Path $evidence "$Name.png")) | Out-Null
    } finally {
        try { Invoke-Adb -AdbArguments @('shell', 'rm', '-f', $remote) | Out-Null } catch {}
    }
}

function Dismiss-DebugCompatibilityDialog {
    param([Parameter(Mandatory = $true)][string] $EvidenceName)
    $document = Save-UiDump $EvidenceName
    $button = $document.SelectNodes('//node') | Where-Object {
        [string]$_.text -eq '确定' -and [string]$_.clickable -eq 'true'
    } | Select-Object -First 1
    if (-not $button) { return }
    $bounds = [string]$button.bounds
    if ($bounds -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {
        throw "Unexpected compatibility-dialog bounds: $bounds"
    }
    $x = [math]::Floor(([int]$Matches[1] + [int]$Matches[3]) / 2)
    $y = [math]::Floor(([int]$Matches[2] + [int]$Matches[4]) / 2)
    Invoke-Adb -AdbArguments @('shell', 'input', 'tap', $x, $y) | Out-Null
    Start-Sleep -Milliseconds 800
}

function Get-LocalInteractionSwitchState {
    param([Parameter(Mandatory = $true)][xml] $Document)
    $nodes = @($Document.SelectNodes('//node') | Where-Object {
        ([string]$_.'content-desc').Contains('启用本地互动体验') -or ([string]$_.text).Contains('启用本地互动体验')
    })
    $switch = $nodes | Where-Object { [string]$_.checkable -eq 'true' } | Select-Object -First 1
    if (-not $switch) { throw 'The local interaction switch was not exposed by UIAutomator.' }
    [string]$switch.checked -eq 'true'
}

function Open-LocalInteractionSettings {
    Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $Package) | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP') | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'wm', 'dismiss-keyguard') | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'am', 'start', '-W', '-n', "$Package/.MainActivity") | Out-Null
    Start-Sleep -Seconds 6
    Dismiss-DebugCompatibilityDialog 'debug-compatibility-settings'
    & (Join-Path $repo 'tool\android_ui.ps1') -Sequence open_local_interaction_settings -Serial $Serial -CaptureOnFailure
    if ($LASTEXITCODE -ne 0) { throw 'Opening local interaction settings failed.' }
    Start-Sleep -Seconds 1
}

function Set-LocalInteractionState {
    param([Parameter(Mandatory = $true)][bool] $Enabled, [Parameter(Mandatory = $true)][string] $EvidenceName)
    $document = Save-UiDump "$EvidenceName-before"
    $current = Get-LocalInteractionSwitchState $document
    if ($current -ne $Enabled) {
        & (Join-Path $repo 'tool\android_ui.ps1') -TapSemantic '启用本地互动体验' -Serial $Serial -CaptureOnFailure
        if ($LASTEXITCODE -ne 0) { throw 'Toggling local interaction failed.' }
        Start-Sleep -Milliseconds 700
    }
    $after = Save-UiDump "$EvidenceName-after"
    if ((Get-LocalInteractionSwitchState $after) -ne $Enabled) {
        throw "Local interaction did not settle to enabled=$Enabled."
    }
}

$result = [ordered]@{
    schemaVersion = 1
    startedAt = (Get-Date).ToString('o')
    serial = $Serial
    apk = $apk
    checks = [ordered]@{}
}
$originalEnabled = $null
$failure = $null
try {
    $install = Invoke-Adb -AdbArguments @('install', '-r', '-t', $apk)
    $result.checks.install = ($install -join "`n").Trim()
    $result.checks.pageSizeBytes = [int](((Invoke-Adb -AdbArguments @('shell', 'getconf', 'PAGE_SIZE')) -join '').Trim())
    Open-LocalInteractionSettings
    $initial = Save-UiDump 'local-settings-initial'
    $originalEnabled = Get-LocalInteractionSwitchState $initial
    $result.checks.originalEnabled = $originalEnabled
    Set-LocalInteractionState -Enabled $false -EvidenceName 'local-settings-disabled'

    Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $Package) | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'am', 'start', '-W', '-n', "$Package/.MainActivity") | Out-Null
    Start-Sleep -Seconds 6
    Dismiss-DebugCompatibilityDialog 'debug-compatibility-room'
    & (Join-Path $repo 'tool\android_ui.ps1') -Sequence enter_first_bilibili_room -Serial $Serial -CaptureOnFailure
    if ($LASTEXITCODE -ne 0) { throw 'Entering the Bilibili room failed.' }
    Start-Sleep -Seconds 12
    $room = Save-UiDump 'room-before-fullscreen'
    $roomText = $room.OuterXml
    if (-not ($roomText.Contains('弹幕列表') -and $roomText.Contains('弹幕设置'))) {
        throw 'The selected card did not reach a live-room UI.'
    }

    & (Join-Path $repo 'tool\android_ui.ps1') -Tap live.show_controls -Serial $Serial -CaptureOnFailure
    & (Join-Path $repo 'tool\android_ui.ps1') -TapSemantic '横屏全屏' -Serial $Serial -CaptureOnFailure
    if ($LASTEXITCODE -ne 0) { throw 'Entering landscape fullscreen failed.' }
    Start-Sleep -Seconds 2
    $fullscreen = Save-UiDump 'fullscreen-local-disabled'
    Save-Screenshot 'fullscreen-local-disabled'
    $fullscreenText = $fullscreen.OuterXml
    $largestBounds = $fullscreen.SelectNodes('//node') | ForEach-Object {
        if ([string]$_.bounds -match '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {
            $width = [int]$Matches[3] - [int]$Matches[1]
            $height = [int]$Matches[4] - [int]$Matches[2]
            [pscustomobject]@{ Width = $width; Height = $height; Area = $width * $height }
        }
    } | Sort-Object Area -Descending | Select-Object -First 1
    $result.checks.fullscreenWidth = if ($largestBounds) { $largestBounds.Width } else { 0 }
    $result.checks.fullscreenHeight = if ($largestBounds) { $largestBounds.Height } else { 0 }
    # Fullscreen chrome auto-hides before UIAutomator finishes dumping a live
    # Flutter surface. Use the observed landscape viewport as the durable state
    # assertion; visible control labels are deliberately transient.
    $result.checks.fullscreenEntered = $largestBounds -and $largestBounds.Width -gt $largestBounds.Height
    $result.checks.enablePromptHidden = -not $fullscreenText.Contains('启用本地互动体验')
    if (-not $result.checks.fullscreenEntered) { throw 'The player did not settle in a landscape fullscreen viewport.' }
    if (-not $result.checks.enablePromptHidden) { throw 'Disabled local interaction still occupies fullscreen.' }
} catch {
    $failure = $_
    $result.error = $_.Exception.Message
} finally {
    if ($null -ne $originalEnabled) {
        try {
            Open-LocalInteractionSettings
            Set-LocalInteractionState -Enabled ([bool]$originalEnabled) -EvidenceName 'local-settings-restored'
            $result.checks.originalStateRestored = $true
        } catch {
            $result.checks.originalStateRestored = $false
            if (-not $failure) { $failure = $_; $result.error = $_.Exception.Message }
        }
    }
    try { Invoke-Adb -AdbArguments @('shell', 'am', 'force-stop', $Package) | Out-Null } catch {}
    $result.checks.adbServerRecoveries = $adbServerRecoveries
    $result.completedAt = (Get-Date).ToString('o')
    $result | ConvertTo-Json -Depth 8 | Out-File -LiteralPath (Join-Path $evidence 'summary.json') -Encoding utf8
}

Write-Output (Join-Path $evidence 'summary.json')
if ($failure) { throw $failure }
