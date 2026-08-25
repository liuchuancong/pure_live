[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('AndroidArm64', 'WindowsX64')]
    [string] $Target,
    [Parameter(Mandatory = $true)]
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration,
    [switch] $FullRegression,
    [switch] $SkipQuality,
    [switch] $SkipInstaller,
    [switch] $UseOfficialRepositories,
    [switch] $RequireReleaseSigning,
    [switch] $DedicatedBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterw = Join-Path $PSScriptRoot 'flutterw.ps1'
. (Join-Path $PSScriptRoot 'build_resource_guard.ps1')

if ($FullRegression.IsPresent -eq $SkipQuality.IsPresent) {
    throw 'Choose exactly one quality mode: -FullRegression or -SkipQuality.'
}
if ($RequireReleaseSigning -and ($Target -ne 'AndroidArm64' -or $Configuration -ne 'Release')) {
    throw '-RequireReleaseSigning applies only to AndroidArm64 Release.'
}

$gradleWorkers = if ($DedicatedBuild) { 20 } else { 16 }
$configurationLower = $Configuration.ToLowerInvariant()
$configurationDirectory = if ($Configuration -eq 'Release') { 'Release' } else { 'Debug' }
$versionLine = Select-String -Path (Join-Path $repoRoot 'pubspec.yaml') -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $versionLine) { throw 'pubspec.yaml version was not found.' }
$fullVersion = $versionLine.Matches[0].Groups[1].Value
$displayVersion = $fullVersion.Split('+')[0]
$artifactVersion = $fullVersion.Replace('+', '-')
$output = Join-Path $repoRoot "local-artifacts\$artifactVersion"
$recordDirectory = Join-Path $repoRoot 'local-artifacts\build-records'
New-Item -ItemType Directory -Force -Path $output, $recordDirectory | Out-Null

$temporaryGradleInit = $null
$previousGradleOpts = [Environment]::GetEnvironmentVariable('GRADLE_OPTS', 'Process')
$previousMirrorSetting = [Environment]::GetEnvironmentVariable('PURE_LIVE_USE_CN_MIRRORS', 'Process')
$lease = $null
$monitor = $null
$resourceSummary = $null
$remainingHeavyProcesses = $null
$startedAt = [DateTime]::UtcNow
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$status = 'failed'
$failureMessage = $null
$artifactPaths = @()
$commandLog = Join-Path $recordDirectory "$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))-$($Target.ToLowerInvariant())-$configurationLower.log"
Set-Content -LiteralPath $commandLog -Value '' -Encoding utf8
$incrementalStateBefore = if ($Target -eq 'AndroidArm64') {
    (Test-Path -LiteralPath (Join-Path $repoRoot 'build\app')) -or
        (Test-Path -LiteralPath (Join-Path $repoRoot 'android\.gradle'))
} else {
    Test-Path -LiteralPath (Join-Path $repoRoot 'build\windows\x64')
}

function Assert-PureLiveCommandSucceeded {
    param(
        [Parameter(Mandatory = $true)][string] $Label,
        [Parameter(Mandatory = $true)][int] $ExitCode
    )
    if ($ExitCode -ne 0) { throw "$Label exited with code $ExitCode." }
}

function Invoke-PureLiveLoggedFlutter {
    param(
        [Parameter(Mandatory = $true)][string[]] $Arguments,
        [Parameter(Mandatory = $true)][string] $LogPath
    )

    # A native warning written to stderr is diagnostic output, not a PowerShell
    # failure. Keep it visible and logged, then decide success from LASTEXITCODE.
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
        & $flutterw @Arguments 2>&1 | Tee-Object -FilePath $LogPath | Out-Host
        $exitCode = $LASTEXITCODE
    } finally {
        if ($nativePreferenceVariable) {
            $PSNativeCommandUseErrorActionPreference = $previousNativeCommandPreference
        }
        $ErrorActionPreference = $previousErrorActionPreference
    }
    return $exitCode
}

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

Push-Location $repoRoot
try {
    if ($FullRegression) {
        & (Join-Path $PSScriptRoot 'local_ci.ps1') -Scope Full -TestConcurrency 12
    }

    if (-not $UseOfficialRepositories -and $Target -eq 'AndroidArm64') {
        $env:PURE_LIVE_USE_CN_MIRRORS = '1'
        $initScript = Join-Path $PSScriptRoot 'gradle-cn-mirrors.init.gradle'
        $gradleInitDirectory = Join-Path $env:USERPROFILE '.gradle\init.d'
        New-Item -ItemType Directory -Force -Path $gradleInitDirectory | Out-Null
        # A stable init-script path lets Gradle reuse configuration-cache entries.
        # The heavy-task mutex guarantees one local build owns it at a time.
        $temporaryGradleInit = Join-Path $gradleInitDirectory 'pure-live-cn-mirrors.gradle'
        Copy-Item -LiteralPath $initScript -Destination $temporaryGradleInit -Force
    }

    $taskName = "build-$($Target.ToLowerInvariant())-$configurationLower"
    $lease = Enter-PureLiveHeavyTaskSlot -TaskName $taskName
    $monitor = Start-PureLiveResourceMonitor

    if ($Target -eq 'AndroidArm64') {
        # Keep daemon, parallel execution, both Gradle caches and VFS watching.
        # The default interactive profile leaves eight logical processors free;
        # an explicitly dedicated build leaves four free.
        $baseGradleOpts = @($previousGradleOpts -split '\s+') | Where-Object {
            $_ -and $_ -notmatch '^-Dorg\.gradle\.(daemon|parallel|caching|configuration-cache|vfs\.watch|workers\.max)='
        }
        $resourceGradleOpts = @(
            '-Dorg.gradle.daemon=true',
            '-Dorg.gradle.parallel=true',
            '-Dorg.gradle.caching=true',
            '-Dorg.gradle.configuration-cache=true',
            '-Dorg.gradle.vfs.watch=true',
            "-Dorg.gradle.workers.max=$gradleWorkers"
        )
        $env:GRADLE_OPTS = (@($baseGradleOpts) + $resourceGradleOpts) -join ' '
        if ($RequireReleaseSigning) {
            $env:GRADLE_OPTS = "$env:GRADLE_OPTS -Dorg.gradle.project.pureLiveRequireReleaseSigning=true"
        }

        & (Join-Path $PSScriptRoot 'prefetch_android_native.ps1')

        $androidArgs = @(
            'build', 'apk', "--$configurationLower", '--split-per-abi',
            '--target-platform', 'android-arm64',
            '--dart-define=PURELIVE_BUILD_SOURCE=local'
        )
        $buildExitCode = Invoke-PureLiveLoggedFlutter -Arguments $androidArgs -LogPath $commandLog
        Assert-PureLiveCommandSucceeded 'Android arm64 build' -ExitCode $buildExitCode

        $apkSource = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-arm64-v8a-$configurationLower.apk"
        if (-not (Test-Path -LiteralPath $apkSource -PathType Leaf)) {
            throw "Expected Android artifact was not produced: $apkSource"
        }
        $artifactName = if ($Configuration -eq 'Debug') {
            "PureLive-$artifactVersion-android-arm64-v8a-debug.apk"
        } elseif ($hasReleaseSigning) {
            "PureLive-$artifactVersion-android-arm64-v8a-release.apk"
        } else {
            "PureLive-$artifactVersion-debug-signed-android-arm64-v8a-release.apk"
        }
        $artifactPath = Join-Path $output $artifactName
        Copy-Item -LiteralPath $apkSource -Destination $artifactPath -Force
        $artifactPaths += [IO.Path]::GetFullPath($artifactPath)
    } else {
        $pubGetExitCode = Invoke-PureLiveLoggedFlutter `
            -Arguments @('pub', 'get', '--enforce-lockfile') `
            -LogPath $commandLog
        Assert-PureLiveCommandSucceeded 'Windows locked dependency resolution' -ExitCode $pubGetExitCode
        & (Join-Path $PSScriptRoot 'prefetch_windows_native.ps1')

        $windowsArgs = @(
            'build', 'windows', "--$configurationLower",
            '--dart-define=PURELIVE_BUILD_SOURCE=local'
        )
        $buildExitCode = Invoke-PureLiveLoggedFlutter -Arguments $windowsArgs -LogPath $commandLog
        Assert-PureLiveCommandSucceeded 'Windows x64 build' -ExitCode $buildExitCode

        $windowsSource = Join-Path $repoRoot "build\windows\x64\runner\$configurationDirectory"
        $expectedPrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\') + '\'
        $windowsSourceFull = [IO.Path]::GetFullPath($windowsSource)
        if (-not $windowsSourceFull.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Windows build output escaped the repository: $windowsSourceFull"
        }
        $runtimeState = @(
            Join-Path $windowsSource 'AppData'
            Join-Path $windowsSource 'IPTV_CACHE'
        ) | Where-Object { Test-Path -LiteralPath $_ }
        if ($runtimeState) {
            throw "Runtime state appeared in the Windows bundle: $($runtimeState -join ', ')"
        }

        # Clean only the disposable packaging stage, never Flutter/CMake build state.
        $windowsPackage = Join-Path $repoRoot ".local-build\windows-package-$configurationLower"
        $windowsPackageFull = [IO.Path]::GetFullPath($windowsPackage)
        if (-not $windowsPackageFull.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Windows package staging escaped the repository: $windowsPackageFull"
        }
        if (Test-Path -LiteralPath $windowsPackageFull) {
            Remove-Item -LiteralPath $windowsPackageFull -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $windowsPackageFull | Out-Null
        $developmentExtensions = @('.exp', '.ilk', '.lib', '.pdb')
        $installManifest = Join-Path $repoRoot 'build\windows\x64\install_manifest.txt'
        if (-not (Test-Path -LiteralPath $installManifest -PathType Leaf)) {
            throw "Windows install manifest was not produced: $installManifest"
        }

        # Flutter/CMake incremental builds intentionally retain their output
        # directory. Plugins removed from pubspec can therefore leave obsolete
        # DLLs and asset folders behind. Package only the current CMake install
        # manifest instead of copying the whole Release directory.
        $manifestEntries = @(Get-Content -LiteralPath $installManifest | Where-Object { $_.Trim() })
        if ($manifestEntries.Count -eq 0) {
            throw 'Windows install manifest is empty.'
        }
        $windowsSourcePrefix = $windowsSourceFull.TrimEnd('\') + '\'
        $manifestSourceMarker = '\build\windows\x64\runner\Release\'
        foreach ($entry in $manifestEntries) {
            # Flutter may invoke CMake through its short/substituted P: path,
            # while this script runs from the long workspace path. Resolve the
            # manifest-relative suffix against our validated build directory.
            $normalizedEntry = $entry.Trim().Replace('/', '\')
            $markerIndex = $normalizedEntry.IndexOf($manifestSourceMarker, [StringComparison]::OrdinalIgnoreCase)
            if ($markerIndex -lt 0) {
                throw "Windows install manifest entry has an unexpected root: $normalizedEntry"
            }
            $relativePath = $normalizedEntry.Substring($markerIndex + $manifestSourceMarker.Length)
            if ([string]::IsNullOrWhiteSpace($relativePath)) {
                throw "Windows install manifest entry has no relative file: $normalizedEntry"
            }
            $sourceFile = [IO.Path]::GetFullPath((Join-Path $windowsSourceFull $relativePath))
            if (-not $sourceFile.StartsWith($windowsSourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Windows install manifest escaped the build output: $sourceFile"
            }
            if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
                throw "Windows install manifest entry is missing: $sourceFile"
            }
            if ([IO.Path]::GetExtension($sourceFile).ToLowerInvariant() -in $developmentExtensions) {
                continue
            }

            $destination = Join-Path $windowsPackageFull $relativePath
            $destinationParent = Split-Path -Parent $destination
            if ($destinationParent) {
                New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null
            }
            Copy-Item -LiteralPath $sourceFile -Destination $destination -Force
        }

        # Flutter's Windows runner executable is produced outside the CMake
        # install list. The in-app webview plugin also links the dynamic
        # WebView2 loader without adding it to that list. Keep this small,
        # reviewed runtime allowlist explicit rather than reopening the whole
        # incremental Release directory.
        foreach ($requiredRunnerFile in @('pure_live.exe', 'WebView2Loader.dll')) {
            $sourceFile = Join-Path $windowsSourceFull $requiredRunnerFile
            if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
                throw "Required Windows runner file is missing: $sourceFile"
            }
            Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $windowsPackageFull $requiredRunnerFile) -Force
        }
        if (-not (Test-Path -LiteralPath (Join-Path $windowsPackageFull 'pure_live.exe') -PathType Leaf)) {
            throw 'The staged Windows package does not contain pure_live.exe.'
        }
        $developmentFiles = Get-ChildItem -LiteralPath $windowsPackageFull -Recurse -File |
            Where-Object Extension -In $developmentExtensions
        if ($developmentFiles) {
            throw "Development-only files appeared in the Windows package: $($developmentFiles.FullName -join ', ')"
        }
        $obsoleteQuickJsFiles = Get-ChildItem -LiteralPath $windowsPackageFull -Recurse -File |
            Where-Object { $_.Name -in @('dart_quickjs.dll', 'flutter_js_plugin.dll', 'quickjs_c_bridge.dll') }
        if ($obsoleteQuickJsFiles) {
            throw "Retired QuickJS runtime files appeared in the Windows package: $($obsoleteQuickJsFiles.FullName -join ', ')"
        }

        $zipName = if ($Configuration -eq 'Release') {
            "PureLive-$artifactVersion-windows-x64-portable.zip"
        } else {
            "PureLive-$artifactVersion-windows-x64-debug.zip"
        }
        $zipPath = Join-Path $output $zipName
        Compress-Archive -Path (Join-Path $windowsPackageFull '*') -DestinationPath $zipPath -Force
        $artifactPaths += [IO.Path]::GetFullPath($zipPath)

        if ($Configuration -eq 'Release' -and -not $SkipInstaller) {
            $iscc = @(
                'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
                (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
            ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            if ($iscc) {
                $iss = Join-Path $repoRoot 'windows\packaging\exe\local_release.iss'
                & $iscc "/DSourceDir=$windowsPackageFull" "/DAppVersion=$displayVersion" `
                    "/DArtifactVersion=$artifactVersion" "/DOutputDir=$output" $iss
                $installerExitCode = $LASTEXITCODE
                Assert-PureLiveCommandSucceeded 'Windows installer packaging' -ExitCode $installerExitCode
                $setup = Get-ChildItem $output -File -Filter '*windows-x64-setup.exe' | Select-Object -First 1
                if ($setup) { $artifactPaths += $setup.FullName }
            } else {
                Write-Warning 'Inno Setup 6 was not found; the portable ZIP was created.'
            }
        }
    }
    $status = 'succeeded'
} catch {
    $failureMessage = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($failureMessage)) {
        $failureMessage = ($_ | Out-String).Trim()
    }
    throw
} finally {
    $stopwatch.Stop()
    if ($monitor) { $resourceSummary = Stop-PureLiveResourceMonitor -Job $monitor }
    if ($lease) {
        $remainingHeavyProcesses = Wait-PureLiveBackgroundCpuSettle
        Exit-PureLiveHeavyTaskSlot -Lease $lease
    }

    $logText = if (Test-Path -LiteralPath $commandLog) { Get-Content -LiteralPath $commandLog -Raw } else { '' }
    $cacheSummary = [ordered]@{
        gradle_daemon = if ($Target -eq 'AndroidArm64') { 'enabled' } else { 'not-applicable' }
        gradle_parallel = if ($Target -eq 'AndroidArm64') { 'enabled' } else { 'not-applicable' }
        gradle_build_cache = if ($Target -eq 'AndroidArm64') { 'enabled' } else { 'not-applicable' }
        configuration_cache = if ($Target -eq 'AndroidArm64') { 'enabled' } else { 'not-applicable' }
        vfs_watch = if ($Target -eq 'AndroidArm64') { 'enabled' } else { 'not-applicable' }
        incremental_state_present_before = $incrementalStateBefore
        from_cache_observations = ([regex]::Matches($logText, '(?im)\bFROM-CACHE\b')).Count
        up_to_date_observations = ([regex]::Matches($logText, '(?im)\bUP-TO-DATE\b')).Count
        configuration_cache_reused = [bool]($logText -match '(?im)configuration cache (entry )?reused|reusing configuration cache')
        command_log = [IO.Path]::GetFullPath($commandLog)
    }
    $sourceCommit = (git rev-parse HEAD).Trim()
    $record = [ordered]@{
        schema_version = 1
        task = "build-$($Target.ToLowerInvariant())-$configurationLower"
        command = ".\tool\build_local_release.ps1 -Target $Target -Configuration $Configuration" +
            $(if ($DedicatedBuild) { ' -DedicatedBuild' } else { '' }) +
            $(if ($FullRegression) { ' -FullRegression' } else { ' -SkipQuality' })
        source_commit = $sourceCommit
        started_at_utc = $startedAt.ToString('o')
        duration_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        status = $status
        failure = $failureMessage
        target = $Target
        configuration = $Configuration
        gradle_workers = if ($Target -eq 'AndroidArm64') { $gradleWorkers } else { $null }
        quality = if ($FullRegression) { 'full-in-this-invocation' } else { 'external-focused-or-existing-evidence' }
        cache = $cacheSummary
        peak_resources = $resourceSummary
        active_heavy_processes_after = $remainingHeavyProcesses
        outputs = $artifactPaths
        automatic_follow_up = $false
    }
    $recordPath = Write-PureLiveTaskRecord -RepoRoot $repoRoot -Record $record

    if ($status -eq 'succeeded') {
        $trackedDirty = [bool](git status --porcelain --untracked-files=no)
        $androidSigning = if ($Target -ne 'AndroidArm64') {
            'not-built'
        } elseif ($Configuration -eq 'Debug' -or -not $hasReleaseSigning) {
            'debug'
        } else {
            'release'
        }
        $setupExecutable = Get-ChildItem $output -File -Filter '*windows-x64-setup.exe' | Select-Object -First 1
        $windowsPortable = Get-ChildItem $output -File -Filter '*windows-x64-*.zip' | Select-Object -First 1
        $windowsSigning = if ($Target -ne 'WindowsX64') {
            'not-built'
        } elseif ($setupExecutable -and (Get-AuthenticodeSignature -LiteralPath $setupExecutable.FullName).Status -eq 'Valid') {
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
            requested_target = $Target
            configuration = $Configuration
            android_package = if ($Target -eq 'AndroidArm64') { 'com.mystyle.purelive' } else { $null }
            android_signing = $androidSigning
            windows_signing = $windowsSigning
            gradle_workers = if ($Target -eq 'AndroidArm64') { $gradleWorkers } else { $null }
            cache = $cacheSummary
            resource_record = [IO.Path]::GetFullPath($recordPath)
            build_source = 'local'
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'BUILD_METADATA.json') -Encoding utf8

        Get-ChildItem $output -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object {
            $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
            '{0} *{1}' -f $hash.Hash.ToLowerInvariant(), $_.Name
        } | Set-Content -Path (Join-Path $output 'SHA256SUMS.txt') -Encoding ascii
        Get-ChildItem $output -File | Select-Object Name, Length, LastWriteTime
    }
    Write-Host "Build record: $recordPath"

    if ($temporaryGradleInit -and (Test-Path -LiteralPath $temporaryGradleInit)) {
        Remove-Item -LiteralPath $temporaryGradleInit -Force
    }
    if ($null -eq $previousGradleOpts) { Remove-Item Env:GRADLE_OPTS -ErrorAction SilentlyContinue }
    else { $env:GRADLE_OPTS = $previousGradleOpts }
    if ($null -eq $previousMirrorSetting) { Remove-Item Env:PURE_LIVE_USE_CN_MIRRORS -ErrorAction SilentlyContinue }
    else { $env:PURE_LIVE_USE_CN_MIRRORS = $previousMirrorSetting }
    Pop-Location
}
