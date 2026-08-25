[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $FlutterArgs
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedVersion = ((Get-Content (Join-Path $repoRoot '.fvmrc') -Raw | ConvertFrom-Json).flutter)
$candidates = @(
    $env:PURE_LIVE_FLUTTER,
    (Join-Path $repoRoot '.fvm\flutter_sdk\bin\flutter.bat'),
    (Join-Path $env:LOCALAPPDATA "Codex\flutter\sdk-$expectedVersion\flutter\bin\flutter.bat")
) | Where-Object { $_ }

$flutter = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $flutter) {
    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if ($command) { $flutter = $command.Source }
}
if (-not $flutter) {
    throw "Flutter $expectedVersion was not found. Set PURE_LIVE_FLUTTER to flutter.bat."
}

if (-not $env:ANDROID_HOME) {
    $localSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    if (Test-Path -LiteralPath $localSdk) {
        $env:ANDROID_HOME = $localSdk
        $env:ANDROID_SDK_ROOT = $localSdk
    }
}
if (-not $env:JAVA_HOME) {
    $localTemurin = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Codex\java\temurin-17*\jdk-17*') -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
    $javaCandidates = @($env:PURE_LIVE_JAVA_HOME, 'C:\Program Files\Android\Android Studio\jbr', $localTemurin) |
        Where-Object { $_ }
    $javaHome = $javaCandidates | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'bin\java.exe') } | Select-Object -First 1
    if ($javaHome) { $env:JAVA_HOME = $javaHome }
}
if ($env:JAVA_HOME) {
    $env:PATH = "$(Join-Path $env:JAVA_HOME 'bin');$env:PATH"
}
if ($env:GRADLE_OPTS -notmatch '(?:^|\s)--enable-native-access=ALL-UNNAMED(?:\s|$)') {
    $env:GRADLE_OPTS = (@($env:GRADLE_OPTS, '--enable-native-access=ALL-UNNAMED') |
        Where-Object { $_ }) -join ' '
}
$localNuGet = Join-Path $env:LOCALAPPDATA 'Codex\nuget\nuget.exe'
if (-not (Get-Command nuget.exe -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $localNuGet)) {
    $env:PATH = "$(Split-Path -Parent $localNuGet);$env:PATH"
}

$flutterRoot = Split-Path -Parent (Split-Path -Parent $flutter)
$dart = Join-Path $flutterRoot 'bin\dart.bat'
$executable = $flutter
if ($FlutterArgs.Count -gt 0 -and $FlutterArgs[0] -eq 'dart') {
    $executable = $dart
    $FlutterArgs = @($FlutterArgs | Select-Object -Skip 1)
}
if ($executable -eq $flutter -and $env:JAVA_HOME -and $FlutterArgs[0] -notin @('config', 'upgrade')) {
    # Windows PowerShell converts a native process' stderr into non-terminating
    # ErrorRecord objects. With the wrapper-wide Stop preference, an ordinary
    # Gradle warning would otherwise terminate the wrapper before its exit code
    # can be inspected.
    $previousErrorActionPreference = $ErrorActionPreference
    $nativePreferenceVariable = Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
    $previousNativeCommandPreference = if ($nativePreferenceVariable) {
        $PSNativeCommandUseErrorActionPreference
    } else {
        $null
    }
    try {
        $ErrorActionPreference = 'Continue'
        if ($nativePreferenceVariable) { $PSNativeCommandUseErrorActionPreference = $false }
        & $flutter config --jdk-dir=$env:JAVA_HOME *> $null
        $configExitCode = $LASTEXITCODE
    } finally {
        if ($nativePreferenceVariable) {
            $PSNativeCommandUseErrorActionPreference = $previousNativeCommandPreference
        }
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($configExitCode -ne 0) { throw 'Flutter JDK configuration failed.' }
}

$workDir = $repoRoot
$shortPathReady = $false

if ($repoRoot.Length -gt 80) {
    # Keep the short project path on the same drive as the Pub cache. Kotlin's
    # incremental compiler cannot relativize plugin sources when a SUBST drive
    # (for example P:) and the default C: Pub cache are mixed, so it discards
    # its cache and recompiles every Kotlin plugin. A stable junction preserves
    # short paths without changing the drive root seen by the compiler.
    try {
        $normalizedRepoRoot = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\').ToLowerInvariant()
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalizedRepoRoot))
        } finally {
            $sha256.Dispose()
        }
        $repoHash = -join ($digest[0..5] | ForEach-Object { $_.ToString('x2') })
        $junctionParent = Join-Path $env:LOCALAPPDATA 'Codex\workspaces'
        $junctionPath = Join-Path $junctionParent "pure-live-$repoHash"
        New-Item -ItemType Directory -Force -Path $junctionParent | Out-Null

        if (Test-Path -LiteralPath $junctionPath) {
            $junction = Get-Item -LiteralPath $junctionPath -Force
            $junctionTarget = @($junction.Target) | Select-Object -First 1
            if ($junctionTarget -and
                [IO.Path]::GetFullPath($junctionTarget).TrimEnd('\').Equals(
                    [IO.Path]::GetFullPath($repoRoot).TrimEnd('\'),
                    [StringComparison]::OrdinalIgnoreCase)) {
                $workDir = $junctionPath
                $shortPathReady = $true
            }
        } else {
            New-Item -ItemType Junction -Path $junctionPath -Target $repoRoot | Out-Null
            $workDir = $junctionPath
            $shortPathReady = $true
        }
    } catch {
        # SUBST remains a compatibility fallback when junction creation is restricted.
    }
}

$substDrive = $null
$substMappingFile = Join-Path $repoRoot '.dart_tool\pure_live_subst_drive.txt'
if ($repoRoot.Length -gt 80 -and -not $shortPathReady) {
    $repoParent = Split-Path -Parent $repoRoot
    $repoLeaf = Split-Path -Leaf $repoRoot
    $savedDrive = if (Test-Path -LiteralPath $substMappingFile) {
        (Get-Content -LiteralPath $substMappingFile -Raw).Trim()
    }
    $driveCandidates = @($savedDrive, 'P:', 'Q:', 'R:', 'S:', 'T:', 'U:', 'V:', 'W:') |
        Where-Object { $_ } |
        Select-Object -Unique
    foreach ($candidate in $driveCandidates) {
        $existingTarget = (& subst.exe) |
            Where-Object { $_ -match "^$([Regex]::Escape($candidate))\\:\s*=>\s*(.+)$" } |
            ForEach-Object { $Matches[1].Trim() } |
            Select-Object -First 1
        if ($existingTarget -and
            -not ([IO.Path]::GetFullPath($existingTarget).Equals([IO.Path]::GetFullPath($repoParent), [StringComparison]::OrdinalIgnoreCase))) {
            continue
        }
        if (-not $existingTarget) {
            & subst.exe $candidate $repoParent
            if ($LASTEXITCODE -ne 0) { continue }
        }
        $substDrive = $candidate
        $workDir = "$candidate\$repoLeaf"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $substMappingFile) | Out-Null
        Set-Content -LiteralPath $substMappingFile -Value $candidate -NoNewline -Encoding ascii
        break
    }
    if (-not $substDrive) {
        throw 'No stable subst drive was available for the long repository path.'
    }
}

Push-Location $workDir
$flutterExitCode = 0
$previousErrorActionPreference = $ErrorActionPreference
$nativePreferenceVariable = Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
$previousNativeCommandPreference = if ($nativePreferenceVariable) {
    $PSNativeCommandUseErrorActionPreference
} else {
    $null
}
try {
    # Preserve native stderr in the caller's log and use the process exit code
    # as the single source of truth for command success.
    $ErrorActionPreference = 'Continue'
    if ($nativePreferenceVariable) { $PSNativeCommandUseErrorActionPreference = $false }
    & $executable @FlutterArgs
    $flutterExitCode = $LASTEXITCODE
} finally {
    if ($nativePreferenceVariable) {
        $PSNativeCommandUseErrorActionPreference = $previousNativeCommandPreference
    }
    $ErrorActionPreference = $previousErrorActionPreference
    Pop-Location
}
$global:LASTEXITCODE = $flutterExitCode
if ($flutterExitCode -ne 0) {
    exit $flutterExitCode
}
