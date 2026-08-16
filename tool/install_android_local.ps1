[CmdletBinding()]
param(
    [string] $ApkPath,
    [string] $Device
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sdkRoot = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
$aapt = Get-ChildItem (Join-Path $sdkRoot 'build-tools') -Directory -ErrorAction SilentlyContinue |
    Sort-Object { [version]$_.Name } -Descending |
    ForEach-Object { Join-Path $_.FullName 'aapt.exe' } |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1
if (-not (Test-Path -LiteralPath $adb)) { throw "adb.exe was not found under $sdkRoot." }
if (-not $aapt) { throw "aapt.exe was not found under $sdkRoot\build-tools." }

$onlineDevices = & $adb devices | Select-String '^([^\s]+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value }
if ($Device) {
    if ($Device -notin $onlineDevices) { throw "Android device $Device is not online." }
} elseif ($onlineDevices.Count -eq 1) {
    $Device = $onlineDevices[0]
} elseif ($onlineDevices.Count -eq 0) {
    throw 'No online Android device was found.'
} else {
    throw "More than one Android device is online; pass -Device. Found: $($onlineDevices -join ', ')"
}

if (-not $ApkPath) {
    $abi = (& $adb -s $Device shell getprop ro.product.cpu.abi).Trim()
    $abiName = switch -Regex ($abi) {
        '^arm64' { 'arm64-v8a'; break }
        '^armeabi|^arm' { 'armeabi-v7a'; break }
        '^x86_64' { 'x86_64'; break }
        default { throw "Unsupported device ABI: $abi" }
    }
    $ApkPath = Get-ChildItem (Join-Path $repoRoot 'local-artifacts') -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*debug-signed-$abiName-release.apk" -or $_.Name -like "*-$abiName-release.apk" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ApkPath -or -not (Test-Path -LiteralPath $ApkPath)) { throw 'A matching local APK was not found. Run tool/build_local_release.ps1 first.' }

$badging = & $aapt dump badging $ApkPath
if ($LASTEXITCODE -or ($badging -join "`n") -notmatch "package: name='com\.mystyle\.purelive'") {
    throw 'The selected APK does not use the formal Pure Live package id.'
}

& $adb -s $Device install -r $ApkPath
if ($LASTEXITCODE) { throw 'adb install failed.' }
& $adb -s $Device shell monkey -p com.mystyle.purelive -c android.intent.category.LAUNCHER 1 | Out-Host
if ($LASTEXITCODE) { throw 'The Pure Live launcher activity did not start.' }
Start-Sleep -Seconds 3
$packageState = & $adb -s $Device shell dumpsys package com.mystyle.purelive
$versionMatch = [regex]::Match(($packageState -join "`n"), 'versionName=([^\s]+)')
if (-not $versionMatch.Success) { throw 'The installed Pure Live package was not found after launch.' }
[pscustomobject]@{
    Device = $Device
    Apk = (Resolve-Path -LiteralPath $ApkPath).Path
    Package = 'com.mystyle.purelive'
    Version = $versionMatch.Groups[1].Value
    ProcessId = (& $adb -s $Device shell pidof com.mystyle.purelive).Trim()
}
