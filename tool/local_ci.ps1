[CmdletBinding()]
param(
    [ValidateSet('Focused', 'Full')]
    [string] $Scope = 'Focused',
    [string[]] $TestPath = @(),
    [switch] $Analyze,
    [switch] $OfflinePub,
    [switch] $SkipPubGet,
    [switch] $SkipInterfaces,
    [switch] $SkipTestAssets,
    [switch] $IncludeRepositoryChecks,
    [ValidateRange(1, 20)]
    [int] $TestConcurrency = 12
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterw = Join-Path $PSScriptRoot 'flutterw.ps1'
. (Join-Path $PSScriptRoot 'build_resource_guard.ps1')

$shouldAnalyze = $Analyze.IsPresent -or $Scope -eq 'Full'
$runRepositoryChecks = $Scope -eq 'Full' -or $IncludeRepositoryChecks.IsPresent
$resolvedTests = @($TestPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
if ($Scope -eq 'Focused' -and $resolvedTests.Count -eq 0 -and -not $shouldAnalyze) {
    throw 'Focused validation requires -TestPath and/or -Analyze.'
}
if ($Scope -eq 'Full' -and $SkipPubGet) {
    throw 'Full validation must resolve the locked dependency graph.'
}
foreach ($path in $resolvedTests) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $path))) {
        throw "Focused test path does not exist: $path"
    }
}

function Assert-PureLiveCommandSucceeded {
    param([Parameter(Mandatory = $true)][string] $Label)
    if ($LASTEXITCODE -ne 0) { throw "$Label exited with code $LASTEXITCODE." }
}

$taskName = "quality-$($Scope.ToLowerInvariant())"
$commandDescription = if ($Scope -eq 'Full') {
    ".\tool\local_ci.ps1 -Scope Full -TestConcurrency $TestConcurrency"
} else {
    ".\tool\local_ci.ps1 -Scope Focused -TestPath $($resolvedTests -join ',')" +
        $(if ($shouldAnalyze) { ' -Analyze' } else { '' }) +
        $(if ($OfflinePub) { ' -OfflinePub' } else { '' }) +
        $(if ($SkipPubGet) { ' -SkipPubGet' } else { '' }) +
        $(if ($SkipTestAssets) { ' -SkipTestAssets' } else { '' }) +
        $(if ($IncludeRepositoryChecks) { ' -IncludeRepositoryChecks' } else { '' })
}
$startedAt = [DateTime]::UtcNow
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$lease = $null
$monitor = $null
$resourceSummary = $null
$remainingHeavyProcesses = $null
$status = 'failed'
$failureMessage = $null
$analyzeInvocationCount = 0
$leaseWaitSeconds = $null
$phaseSeconds = [ordered]@{}
$repositoryAuditPath = Join-Path $repoRoot "local-artifacts\repository-audits\$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))-$($Scope.ToLowerInvariant()).json"

Push-Location $repoRoot
try {
    $phaseClock = [Diagnostics.Stopwatch]::StartNew()
    $lease = Enter-PureLiveHeavyTaskSlot -TaskName $taskName
    $phaseClock.Stop()
    $leaseWaitSeconds = [Math]::Round($phaseClock.Elapsed.TotalSeconds, 3)
    $monitor = Start-PureLiveResourceMonitor

    if ($runRepositoryChecks) {
        $phaseClock = [Diagnostics.Stopwatch]::StartNew()
        & (Join-Path $PSScriptRoot 'validate_build_policy.ps1')
        & (Join-Path $PSScriptRoot 'test_subst_path.ps1')
        & (Join-Path $PSScriptRoot 'test_android_recording_platforms.ps1')
        & (Join-Path $PSScriptRoot 'test_android_recording_guard.ps1')
        & (Join-Path $PSScriptRoot 'test_android_proxy_session.ps1')
        & (Join-Path $PSScriptRoot 'test_android_activity_state.ps1')
        & (Join-Path $PSScriptRoot 'test_android_surfaceflinger_timestats.ps1')
        & (Join-Path $PSScriptRoot 'test_android_process_resource_metrics.ps1')
        & (Join-Path $PSScriptRoot 'test_android_room_tag_assignment_smoke.ps1')
        & (Join-Path $PSScriptRoot 'test_android_share_intake_smoke.ps1')

        python (Join-Path $PSScriptRoot 'validate_device_ui_map.py')
        Assert-PureLiveCommandSucceeded 'Device UI map validation'
        $phaseClock.Stop()
        $phaseSeconds.repository_preflight = [Math]::Round($phaseClock.Elapsed.TotalSeconds, 3)
    }

    $phaseClock = [Diagnostics.Stopwatch]::StartNew()
    if ($SkipPubGet) {
        $packageConfig = Join-Path $repoRoot '.dart_tool\package_config.json'
        if (-not (Test-Path -LiteralPath $packageConfig)) {
            throw '-SkipPubGet requires an existing .dart_tool/package_config.json.'
        }
        [string[]] $dependencyChanges = @(
            git status --porcelain=v1 --untracked-files=all |
                ForEach-Object { if ($_.Length -gt 3) { $_.Substring(3).Trim('"') } } |
                Where-Object { $_ -match '(^|/)pubspec\.(yaml|lock)$' }
        )
        if ($dependencyChanges.Count -gt 0) {
            throw "-SkipPubGet is invalid because dependency manifests changed: $($dependencyChanges -join ', ')"
        }
        Write-Host 'Locked dependency resolution skipped: manifests unchanged and package_config is present.'
    }
    else {
        [string[]] $pubArgs = @('pub', 'get', '--enforce-lockfile')
        if ($OfflinePub) { $pubArgs += '--offline' }
        & $flutterw @pubArgs
        Assert-PureLiveCommandSucceeded 'Locked dependency resolution'
    }
    $phaseClock.Stop()
    $phaseSeconds.dependency_resolution = [Math]::Round($phaseClock.Elapsed.TotalSeconds, 3)

    if ($runRepositoryChecks) {
        $phaseClock = [Diagnostics.Stopwatch]::StartNew()
        python -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p test_repository_secret_audit.py
        Assert-PureLiveCommandSucceeded 'Repository secret audit regression tests'

        python -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p test_cc_interface_probe.py
        Assert-PureLiveCommandSucceeded 'CC interface probe regression tests'

        python -m unittest discover -s (Join-Path $PSScriptRoot 'tests') -p test_acceptance_status_alignment.py
        Assert-PureLiveCommandSucceeded 'Acceptance status alignment regression tests'

        python (Join-Path $PSScriptRoot 'audit_repository.py') --output $repositoryAuditPath
        Assert-PureLiveCommandSucceeded 'Whole repository integrity audit'

        python (Join-Path $PSScriptRoot 'audit_built_in_kotlin.py')
        Assert-PureLiveCommandSucceeded 'Built-in Kotlin audit'
        $phaseClock.Stop()
        $phaseSeconds.repository_audit = [Math]::Round($phaseClock.Elapsed.TotalSeconds, 3)
    }

    # Native Assets hooks share the persistent verified Windows cache. Android
    # media stays cold until an explicitly targeted Android build.
    $phaseClock = [Diagnostics.Stopwatch]::StartNew()
    & (Join-Path $PSScriptRoot 'prefetch_android_native.ps1') -SkipAndroidMedia
    Assert-PureLiveCommandSucceeded 'Native dependency prefetch'
    $phaseClock.Stop()
    $phaseSeconds.native_prefetch = [Math]::Round($phaseClock.Elapsed.TotalSeconds, 3)

    # This file vendors JavaScript in raw Dart strings and stays outside format.
    $formatExclusions = @('lib/core/scripts/douyin_sign.dart')
    # Wrap the complete pipeline in an array expression. With no changed Dart
    # files PowerShell otherwise assigns $null, which has no Count in strict mode.
    [string[]] $dartFiles = @(
        @(
            git diff --name-only --diff-filter=ACMR HEAD -- '*.dart'
            git ls-files --others --exclude-standard -- '*.dart'
        ) | Where-Object {
            $_ -and
            $_ -notin $formatExclusions -and
            -not $_.StartsWith('plugins/built_in_kotlin/', [StringComparison]::OrdinalIgnoreCase) -and
            -not $_.StartsWith('plugins/flv_lzc/', [StringComparison]::OrdinalIgnoreCase) -and
            -not $_.StartsWith('third_party/media_kit_video/', [StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $_)
        } | Sort-Object -Unique
    )
    if ($dartFiles.Count -gt 0) {
        & $flutterw dart format --output=none --set-exit-if-changed @dartFiles
        Assert-PureLiveCommandSucceeded 'Changed Dart file format check'
    }

    # Analyze is deliberately a single end-of-edit invocation.
    if ($shouldAnalyze) {
        $phaseClock = [Diagnostics.Stopwatch]::StartNew()
        $analyzeInvocationCount++
        & $flutterw analyze --no-pub --no-fatal-infos --no-fatal-warnings
        Assert-PureLiveCommandSucceeded 'Flutter Analyze'
        $phaseClock.Stop()
        $phaseSeconds.flutter_analyze = [Math]::Round($phaseClock.Elapsed.TotalSeconds, 3)
    }

    [string[]] $testAssetArgs = @()
    if ($SkipTestAssets) { $testAssetArgs = @('--no-test-assets') }
    $phaseClock = [Diagnostics.Stopwatch]::StartNew()
    if ($Scope -eq 'Full') {
        & $flutterw test --no-pub "--concurrency=$TestConcurrency" @testAssetArgs
        Assert-PureLiveCommandSucceeded 'Full Flutter test suite'
    } elseif ($resolvedTests.Count -gt 0) {
        # Keep all affected files in one test process so concurrency is bounded once.
        & $flutterw test --no-pub "--concurrency=$TestConcurrency" @testAssetArgs @resolvedTests
        Assert-PureLiveCommandSucceeded 'Focused Flutter tests'
    }
    $phaseClock.Stop()
    $phaseSeconds.flutter_tests = [Math]::Round($phaseClock.Elapsed.TotalSeconds, 3)

    if ($Scope -eq 'Full' -and -not $SkipInterfaces) {
        $phaseClock = [Diagnostics.Stopwatch]::StartNew()
        python (Join-Path $PSScriptRoot 'interface_probe.py')
        Assert-PureLiveCommandSucceeded 'Public interface probes'
        $phaseClock.Stop()
        $phaseSeconds.interface_probes = [Math]::Round($phaseClock.Elapsed.TotalSeconds, 3)
    }
    $status = 'succeeded'
} catch {
    $failureMessage = $_.Exception.Message
    throw
} finally {
    $stopwatch.Stop()
    if ($monitor) { $resourceSummary = Stop-PureLiveResourceMonitor -Job $monitor }
    if ($lease) {
        $remainingHeavyProcesses = Wait-PureLiveBackgroundCpuSettle
        Exit-PureLiveHeavyTaskSlot -Lease $lease
    }
    $sourceCommit = (git rev-parse HEAD).Trim()
    $record = [ordered]@{
        schema_version = 1
        task = $taskName
        command = $commandDescription
        source_commit = $sourceCommit
        started_at_utc = $startedAt.ToString('o')
        duration_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        status = $status
        failure = $failureMessage
        scope = $Scope
        analyze_invocations = $analyzeInvocationCount
        test_concurrency = $TestConcurrency
        test_assets = if ($SkipTestAssets) { 'skipped' } else { 'built' }
        test_paths = if ($Scope -eq 'Full') { @('test/') } else { $resolvedTests }
        repository_checks = $runRepositoryChecks
        lease_wait_seconds = $leaseWaitSeconds
        phase_seconds = $phaseSeconds
        cache = [ordered]@{
            gradle_build_cache = 'enabled'
            configuration_cache = 'enabled'
            observation = 'not-applicable-to-flutter-quality-gate'
        }
        peak_resources = $resourceSummary
        active_heavy_processes_after = $remainingHeavyProcesses
        outputs = @(
            if ($runRepositoryChecks) { $repositoryAuditPath }
        )
        automatic_follow_up = $false
    }
    $recordPath = Write-PureLiveTaskRecord -RepoRoot $repoRoot -Record $record
    Write-Host "Quality record: $recordPath"
    Pop-Location
}
