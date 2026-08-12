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
    $javaCandidates = @($env:PURE_LIVE_JAVA_HOME, $localTemurin, 'C:\Program Files\Android\Android Studio\jbr') |
        Where-Object { $_ }
    $javaHome = $javaCandidates | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'bin\java.exe') } | Select-Object -First 1
    if ($javaHome) { $env:JAVA_HOME = $javaHome }
}
if ($env:JAVA_HOME) {
    $env:PATH = "$(Join-Path $env:JAVA_HOME 'bin');$env:PATH"
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
    & $flutter config --jdk-dir=$env:JAVA_HOME *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Flutter JDK configuration failed.' }
}

$workDir = $repoRoot
$substDrive = $null
if ($repoRoot.Length -gt 80) {
    $repoParent = Split-Path -Parent $repoRoot
    $repoLeaf = Split-Path -Leaf $repoRoot
    foreach ($letter in 'P','Q','R','S') {
        $candidate = "${letter}:"
        if (-not (Test-Path "$candidate\")) {
            & subst.exe $candidate $repoParent
            if ($LASTEXITCODE -eq 0) {
                $substDrive = $candidate
                $workDir = "$candidate\$repoLeaf"
                break
            }
        }
    }
}

Push-Location $workDir
$flutterExitCode = 0
try {
    & $executable @FlutterArgs
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
    if ($substDrive) {
        & subst.exe $substDrive /d | Out-Null
    }
}
$global:LASTEXITCODE = $flutterExitCode
if ($flutterExitCode -ne 0) {
    exit $flutterExitCode
}
