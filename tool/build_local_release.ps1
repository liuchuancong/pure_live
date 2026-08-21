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
if ($RequireReleaseSigning -and -not $hasReleaseSigning) {
    throw 'Android release signing was required, but android/key.properties is missing or incomplete.'
}

if (-not $SkipAndroid) {
    Get-ChildItem $output -File -Filter '*.apk' -ErrorAction SilentlyContinue | Remove-Item -Force
}
if (-not $SkipWindows) {
    Get-ChildItem $output -File -ErrorAction SilentlyContinue |
        Where-Object Name -Like '*windows-x64*' |
        Remove-Item -Force
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
        # Flutter does not expose Gradle's daemon/worker switches.  Pass their
        # system-property equivalents through the wrapper so local/self-hosted
        # release builds cannot inherit a stale composite-build daemon.  Four
        # workers is faster than the single-worker fallback while avoiding the
        # included-build controller deadlock seen on high-core-count machines.
        $stableGradleOpts = @(
            '-Dorg.gradle.daemon=false',
            '-Dorg.gradle.parallel=false',
            '-Dorg.gradle.workers.max=4',
            '-Dorg.gradle.vfs.watch=false'
        )
        $env:GRADLE_OPTS = (@($previousGradleOpts) + $stableGradleOpts |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' '
        if ($RequireReleaseSigning) {
            $env:GRADLE_OPTS = (@($env:GRADLE_OPTS, '-Dorg.gradle.project.pureLiveRequireReleaseSigning=true') |
                Where-Object { $_ }) -join ' '
        }
        $java = if ($env:JAVA_HOME) {
            Join-Path $env:JAVA_HOME 'bin\java.exe'
        } else {
            (Get-Command java.exe -ErrorAction SilentlyContinue).Source
        }
        if ($java -and (Test-Path -LiteralPath $java -PathType Leaf)) {
            Write-Host "Stopping stale Gradle daemons before the deterministic Android build..."
            & (Join-Path $repoRoot 'android\gradlew.bat') --stop
            if ($LASTEXITCODE) { exit $LASTEXITCODE }
        } else {
            Write-Host 'Java is resolved by flutterw after this point; no reusable daemon is permitted by GRADLE_OPTS.'
        }
        & (Join-Path $PSScriptRoot 'prefetch_android_native.ps1')
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
        & $flutterw build apk --release --split-per-abi --target-platform android-arm64 --dart-define=PURELIVE_BUILD_SOURCE=local
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
        $arm64Apk = Get-Item 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
        $signingLabel = if ($hasReleaseSigning) { '' } else { 'debug-signed-' }
        Copy-Item $arm64Apk.FullName (Join-Path $output "PureLive-$artifactVersion-${signingLabel}arm64-v8a-release.apk") -Force
    }

    if (-not $SkipWindows) {
        $windowsSource = Join-Path $repoRoot 'build\windows\x64\runner\Release'
        $expectedPrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\') + '\'
        $windowsSourceFull = [IO.Path]::GetFullPath($windowsSource)
        if (-not $windowsSourceFull.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Windows build output escaped the repository: $windowsSourceFull"
        }
        if (Test-Path -LiteralPath $windowsSourceFull) {
            Remove-Item -LiteralPath $windowsSourceFull -Recurse -Force
        }
        & $flutterw build windows --release --dart-define=PURELIVE_BUILD_SOURCE=local
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
        $runtimeState = @(
            Join-Path $windowsSource 'AppData'
            Join-Path $windowsSource 'IPTV_CACHE'
        ) | Where-Object { Test-Path -LiteralPath $_ }
        if ($runtimeState) {
            throw "Runtime state appeared in the clean Windows bundle: $($runtimeState -join ', ')"
        }
        # Flutter/CMake may leave import libraries and linker metadata beside
        # the runtime DLLs. They are useful only for native development and
        # previously added tens of megabytes to every portable/setup package.
        $windowsPackage = Join-Path $repoRoot '.local-build\windows-package'
        $windowsPackageFull = [IO.Path]::GetFullPath($windowsPackage)
        if (-not $windowsPackageFull.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Windows package staging escaped the repository: $windowsPackageFull"
        }
        if (Test-Path -LiteralPath $windowsPackageFull) {
            Remove-Item -LiteralPath $windowsPackageFull -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $windowsPackageFull | Out-Null
        $developmentExtensions = @('.exp', '.ilk', '.lib', '.pdb')
        Get-ChildItem -LiteralPath $windowsSourceFull -Force |
            Where-Object { $_.PSIsContainer -or $_.Extension.ToLowerInvariant() -notin $developmentExtensions } |
            Copy-Item -Destination $windowsPackageFull -Recurse -Force
        if (-not (Test-Path -LiteralPath (Join-Path $windowsPackageFull 'pure_live.exe') -PathType Leaf)) {
            throw 'The staged Windows package does not contain pure_live.exe.'
        }
        $developmentFiles = Get-ChildItem -LiteralPath $windowsPackageFull -Recurse -File |
            Where-Object Extension -In $developmentExtensions
        if ($developmentFiles) {
            throw "Development-only files appeared in the Windows package: $($developmentFiles.FullName -join ', ')"
        }
        $zipPath = Join-Path $output "PureLive-$artifactVersion-windows-x64-portable.zip"
        Compress-Archive -Path (Join-Path $windowsPackageFull '*') -DestinationPath $zipPath -Force

        if (-not $SkipInstaller) {
            $iscc = @(
                'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
                (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
            ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if ($iscc) {
                $iss = Join-Path $repoRoot 'windows\packaging\exe\local_release.iss'
                & $iscc "/DSourceDir=$windowsPackageFull" "/DAppVersion=$displayVersion" "/DOutputDir=$output" $iss
                if ($LASTEXITCODE) { exit $LASTEXITCODE }
            } else {
                Write-Warning 'Inno Setup 6 was not found; portable ZIP was still created.'
            }
        }
    }

    $sourceCommit = (git rev-parse HEAD).Trim()
    $trackedDirty = [bool](git status --porcelain --untracked-files=no)
    $apks = Get-ChildItem $output -File -Filter '*.apk'
    $androidSigning = if (-not $apks) {
        'not-built'
    } elseif ($apks | Where-Object Name -Like '*debug-signed*') {
        'debug'
    } else {
        'release'
    }
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
        android_package = if ($androidSigning -eq 'not-built') { $null } else { 'com.mystyle.purelive' }
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
