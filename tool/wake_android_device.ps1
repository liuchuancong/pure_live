[CmdletBinding()]
param([string]$Serial)

$ErrorActionPreference = 'Stop'
$adbCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
    'adb.exe'
)
$adb = $adbCandidates | Where-Object {
    if ([IO.Path]::IsPathRooted($_)) { Test-Path -LiteralPath $_ -PathType Leaf }
    else { [bool](Get-Command $_ -ErrorAction SilentlyContinue) }
} | Select-Object -First 1
if (-not $adb) { throw 'ADB executable was not found.' }

$rows = @(
    & $adb devices | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -match '^([^\s]+)\s+(device|offline|unauthorized)\b') {
            [pscustomobject]@{ Serial = $Matches[1]; State = $Matches[2] }
        }
    }
)
if ([string]::IsNullOrWhiteSpace($Serial)) {
    $ready = @($rows | Where-Object State -eq 'device')
    $ipv4 = @($ready | Where-Object Serial -Match '^\d{1,3}(?:\.\d{1,3}){3}:\d+$')
    if ($ipv4.Count -eq 1) { $Serial = $ipv4[0].Serial }
    elseif ($ready.Count -eq 1) { $Serial = $ready[0].Serial }
    else { throw "Expected one ready Android target (prefer one IPv4 target), found $($ready.Count)." }
}
if (-not ($rows | Where-Object { $_.Serial -eq $Serial -and $_.State -eq 'device' })) {
    throw "Android target is not ready: $Serial"
}

function Invoke-TargetAdb([string[]]$Arguments) {
    $output = & $adb -s $Serial @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed ($LASTEXITCODE): $($Arguments -join ' ')`n$($output -join "`n")"
    }
    @($output)
}

Invoke-TargetAdb -Arguments @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP') | Out-Null
Invoke-TargetAdb -Arguments @('shell', 'wm', 'dismiss-keyguard') | Out-Null
Start-Sleep -Milliseconds 250
$policy = (Invoke-TargetAdb -Arguments @('shell', 'dumpsys', 'window', 'policy')) -join "`n"
$locked = $policy -match '(?im)(?:mShowingLockscreen|mKeyguardShowing|isKeyguardShowing|keyguardShowing|mDreamingLockscreen|isStatusBarKeyguard)\s*=\s*true'
if ($locked) {
    $size = (Invoke-TargetAdb -Arguments @('shell', 'wm', 'size')) -join "`n"
    if ($size -notmatch '(\d+)x(\d+)') { throw "Unexpected device size output: $size" }
    $width = [int]$Matches[1]
    $height = [int]$Matches[2]
    Invoke-TargetAdb -Arguments @(
        'shell', 'input', 'swipe',
        [math]::Round($width * 0.5), [math]::Round($height * 0.84),
        [math]::Round($width * 0.5), [math]::Round($height * 0.24), '350'
    ) | Out-Null
    Start-Sleep -Milliseconds 350
    Invoke-TargetAdb -Arguments @('shell', 'wm', 'dismiss-keyguard') | Out-Null
}

$finalPolicy = (Invoke-TargetAdb -Arguments @('shell', 'dumpsys', 'window', 'policy')) -join "`n"
$stillLocked = $finalPolicy -match '(?im)(?:mShowingLockscreen|mKeyguardShowing|isKeyguardShowing|keyguardShowing|mDreamingLockscreen|isStatusBarKeyguard)\s*=\s*true'
if ($stillLocked) { throw "Android target remained keyguard-locked after wake: $Serial" }

[pscustomobject]@{ Serial = $Serial; Awake = $true; KeyguardDismissed = $true } | ConvertTo-Json -Compress
