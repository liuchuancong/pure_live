[CmdletBinding()]
param(
    [switch] $SkipQuality,
    [switch] $SkipAndroid,
    [switch] $SkipWindows,
    [switch] $SkipInstaller,
    [switch] $UseOfficialRepositories,
    [switch] $RequireReleaseSigning
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterw = Join-Path $PSScriptRoot 'flutterw.ps1'
$versionLine = Select-String -Path (Join-Path $repoRoot 'pubspec.yaml') -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $versionLine) { throw 'pubspec.yaml version was not found.' }
$fullVersion = $versionLine.Matches[0].Groups[1].Value
$displayVersion = $fullVersion.Split('+')[0]
$artifactVersion = $fullVersion.Replace('+', '-')
$output = Join-Path $repoRoot "local-artifacts\$artifactVersion"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$temporaryGradleInit = $null
$previousGradleOpts = [Environment]::GetEnvironmentVariable('GRADLE_OPTS', 'Process')

function Test-AndroidReleaseSigning {
    $propertiesPath = Join-Path $repoRoot 'android\key.properties'
    if (-not (Test-Path -LiteralPath $propertiesPath)) { return $false }

    $properties = @{}
    foreach ($line in Get-Content -LiteralPath $propertiesPath) {
        if ($line -match '^\s*([^#!][^=]*?)\s*=\s*(.*)\s*$') {
            $properties[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    foreach ($key in @('storeFile', 'storePassword', 'keyPassword', 'keyAlias')) {
        if ([string]::IsNullOrWhiteSpace($properties[$key])) { return $false }
    }

    $storeFile = $properties['storeFile']
    if (-not [IO.Path]::IsPathRooted($storeFile)) {
        $storeFile = Join-Path (Join-Path $repoRoot 'android\app') $storeFile
    }
    return Test-Path -LiteralPath $storeFile -PathType Leaf
}

$hasReleaseSigning = Test-AndroidReleaseSigning
$androidSigning = if ($SkipAndroid) { 'not-built' } elseif ($hasReleaseSigning) { 'release' } else { 'qa-debug' }
if ($RequireReleaseSigning -and -not $hasReleaseSigning) {
    throw 'Android release signing was required, but android/key.properties is missing or incomplete.'
}

Push-Location $repoRoot
try {
    if (-not $UseOfficialRepositories) {
        $env:PURE_LIVE_USE_CN_MIRRORS = '1'
        $initScript = Join-Path $PSScriptRoot 'gradle-cn-mirrors.init.gradle'
        $gradleInitDirectory = Join-Path $env:USERPROFILE '.gradle\init.d'
        New-Item -ItemType Directory -Force -Path $gradleInitDirectory | Out-Null
        $temporaryGradleInit = Join-Path $gradleInitDirectory "pure-live-cn-mirrors-$PID.gradle"
        Copy-Item -LiteralPath $initScript -Destination $temporaryGradleInit -Force
    }
    if (-not $SkipQuality) {
        & (Join-Path $PSScriptRoot 'local_ci.ps1')
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    }

    if (-not $SkipAndroid) {
        if ($hasReleaseSigning) {
            $env:GRADLE_OPTS = $previousGradleOpts
        } else {
            $env:GRADLE_OPTS = (@($previousGradleOpts, '-Dorg.gradle.project.pureLiveQaBuild=true') |
                Where-Object { $_ }) -join ' '
        }
        if ($RequireReleaseSigning) {
            $env:GRADLE_OPTS = (@($env:GRADLE_OPTS, '-Dorg.gradle.project.pureLiveRequireReleaseSigning=true') |
                Where-Object { $_ }) -join ' '
        }
        & (Join-Path $PSScriptRoot 'prefetch_android_native.ps1')
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
        & $flutterw build apk --release --split-per-abi --dart-define=PURELIVE_BUILD_SOURCE=local
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
        Get-ChildItem 'build\app\outputs\flutter-apk\*-release.apk' | ForEach-Object {
            $signingLabel = if ($hasReleaseSigning) { '' } else { 'qa-debug-signed-' }
            Copy-Item $_.FullName (Join-Path $output ("PureLive-$artifactVersion-$signingLabel" + $_.Name.Substring(4))) -Force
        }
    }

    if (-not $SkipWindows) {
        & $flutterw build windows --release --dart-define=PURELIVE_BUILD_SOURCE=local
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
        $windowsSource = Join-Path $repoRoot 'build\windows\x64\runner\Release'
        $zipPath = Join-Path $output "PureLive-$artifactVersion-windows-x64-portable.zip"
        Compress-Archive -Path (Join-Path $windowsSource '*') -DestinationPath $zipPath -Force

        if (-not $SkipInstaller) {
            $iscc = @(
                'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
                (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
            ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if ($iscc) {
                $iss = Join-Path $repoRoot 'windows\packaging\exe\local_release.iss'
                & $iscc "/DSourceDir=$windowsSource" "/DAppVersion=$displayVersion" "/DOutputDir=$output" $iss
                if ($LASTEXITCODE) { exit $LASTEXITCODE }
            } else {
                Write-Warning 'Inno Setup 6 was not found; portable ZIP was still created.'
            }
        }
    }

    $sourceCommit = (git rev-parse HEAD).Trim()
    $trackedDirty = [bool](git status --porcelain --untracked-files=no)
    $setupExecutable = Get-ChildItem $output -File -Filter '*windows-x64-setup.exe' | Select-Object -First 1
    $windowsPortable = Get-ChildItem $output -File -Filter '*windows-x64-portable.zip' | Select-Object -First 1
    $windowsSigning = if ($setupExecutable -and (Get-AuthenticodeSignature -LiteralPath $setupExecutable.FullName).Status -eq 'Valid') {
        'authenticode'
    } elseif ($setupExecutable -or $windowsPortable) {
        'unsigned'
    } else {
        'not-built'
    }
    [ordered]@{
        version = $fullVersion
        built_at_utc = [DateTime]::UtcNow.ToString('o')
        source_commit = $sourceCommit
        tracked_files_dirty = $trackedDirty
        android_package = if ($SkipAndroid) { $null } elseif ($hasReleaseSigning) { 'com.mystyle.purelive' } else { 'com.mystyle.purelive.qa' }
        android_signing = $androidSigning
        windows_signing = $windowsSigning
        build_source = 'local'
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'BUILD_METADATA.json') -Encoding utf8

    Get-ChildItem $output -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object {
        $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
        '{0} *{1}' -f $hash.Hash.ToLowerInvariant(), $_.Name
    } | Set-Content -Path (Join-Path $output 'SHA256SUMS.txt') -Encoding ascii
    Get-ChildItem $output -File | Select-Object Name, Length, LastWriteTime
} finally {
    if ($temporaryGradleInit -and (Test-Path -LiteralPath $temporaryGradleInit)) {
        Remove-Item -LiteralPath $temporaryGradleInit -Force
    }
    if ($null -eq $previousGradleOpts) { Remove-Item Env:GRADLE_OPTS -ErrorAction SilentlyContinue }
    else { $env:GRADLE_OPTS = $previousGradleOpts }
    Pop-Location
}
