[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'android_activity_state.ps1')

$target = "    * Hist  #0: ActivityRecord{123 u0 com.mystyle.purelive/.MainActivity t42}`n"
$other = "    * Hist #0: ActivityRecord{456 u0 example.other/.MainActivity t43}`n"
$cases = @(
    @{ Name = 'target-entered'; Dump = $target + 'mLastReportedPictureInPictureMode=true'; Expected = $true },
    @{ Name = 'capability-only'; Dump = $target + 'supportsPictureInPicture=true'; Expected = $false },
    @{ Name = 'target-not-entered'; Dump = $target + 'mLastReportedPictureInPictureMode=false'; Expected = $false },
    @{ Name = 'other-app-entered'; Dump = $target + "mLastReportedPictureInPictureMode=false`n" + $other + 'mLastReportedPictureInPictureMode=true'; Expected = $false },
    @{ Name = 'target-after-other'; Dump = $other + "mLastReportedPictureInPictureMode=false`n" + $target + 'mLastReportedPictureInPictureMode=true'; Expected = $true },
    @{ Name = 'package-prefix-is-not-target'; Dump = $target.Replace('com.mystyle.purelive/', 'com.mystyle.purelive.other/') + 'mLastReportedPictureInPictureMode=true'; Expected = $false },
    @{ Name = 'next-task-state-is-not-target'; Dump = $target + "mLastReportedPictureInPictureMode=false`n  * Task{other mode=pinned}`nmLastReportedPictureInPictureMode=true"; Expected = $false },
    @{ Name = 'missing-dump'; Dump = ''; Expected = $false }
)
foreach ($case in $cases) {
    $actual = Test-AndroidTargetPictureInPicture -ActivityDump $case.Dump
    if ($actual -ne $case.Expected) { throw "$($case.Name): expected $($case.Expected), got $actual" }
    Write-Output "PASS $($case.Name)"
}

foreach ($case in @(
    @{ Name = 'pidof-no-matches'; Code = 1; Text = ''; Expected = $true },
    @{ Name = 'pidof-vendor-empty-success'; Code = 0; Text = ''; Expected = $true },
    @{ Name = 'pidof-still-running'; Code = 0; Text = '1234'; Expected = $false },
    @{ Name = 'pidof-device-offline'; Code = 1; Text = 'error: device offline'; Expected = $false },
    @{ Name = 'pidof-command-missing'; Code = 127; Text = ''; Expected = $false }
)) {
    $actual = Test-AndroidPidAbsent -ExitCode $case.Code -Output $case.Text
    if ($actual -ne $case.Expected) { throw "$($case.Name): expected $($case.Expected), got $actual" }
    Write-Output "PASS $($case.Name)"
}

foreach ($case in @(
    @{ Name = 'foreground-target'; Text = 'topResumedActivity=ActivityRecord{1 u0 com.mystyle.purelive/.MainActivity t1}'; Expected = $true },
    @{ Name = 'foreground-miui-home'; Text = 'topResumedActivity=ActivityRecord{1 u0 com.miui.home/.launcher.Launcher t1}'; Expected = $true },
    @{ Name = 'foreground-other-app'; Text = 'topResumedActivity=ActivityRecord{1 u0 cn.kuwo.player/.MainActivity t1}'; Expected = $false },
    @{ Name = 'foreground-target-prefix'; Text = 'topResumedActivity=ActivityRecord{1 u0 com.mystyle.purelive.other/.MainActivity t1}'; Expected = $false },
    @{ Name = 'foreground-unknown'; Text = ''; Expected = $false }
)) {
    $actual = Test-AndroidForegroundAvailable -Foreground $case.Text
    if ($actual -ne $case.Expected) { throw "$($case.Name): expected $($case.Expected), got $actual" }
    Write-Output "PASS $($case.Name)"
}
