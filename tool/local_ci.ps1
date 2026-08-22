[CmdletBinding()]
param(
    [ValidateSet('Focused', 'Full')]
    [string] $Scope = 'Focused',
    [string[]] $TestPath = @(),
    [switch] $Analyze,
    [switch] $SkipInterfaces,
    [ValidateRange(1, 20)]
    [int] $TestConcurrency = 12
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterw = Join-Path $PSScriptRoot 'flutterw.ps1'
. (Join-Path $PSScriptRoot 'build_resource_guard.ps1')

$shouldAnalyze = $Analyze.IsPresent -or $Scope -eq 'Full'
$resolvedTests = @($TestPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
if ($Scope -eq 'Focused' -and $resolvedTests.Count -eq 0 -and -not $shouldAnalyze) {
    throw 'Focused validation requires -TestPath and/or -Analyze.'
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
        $(if ($shouldAnalyze) { ' -Analyze' } else { '' })
}
$startedAt = [DateTime]::UtcNow
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$lease = $null
$monitor = $null
$resourceSummary = $null
$remainingHeavyProcesses = $null
$status = 'failed'
$failureMessage = $null

Push-Location $repoRoot
try {
    $lease = Enter-PureLiveHeavyTaskSlot -TaskName $taskName
    $monitor = Start-PureLiveResourceMonitor

    & (Join-Path $PSScriptRoot 'validate_build_policy.ps1')

    python (Join-Path $PSScriptRoot 'validate_device_ui_map.py')
    Assert-PureLiveCommandSucceeded 'Device UI map validation'

    & $flutterw pub get --enforce-lockfile
    Assert-PureLiveCommandSucceeded 'Locked dependency resolution'

    # Native Assets hooks share the persistent verified Windows cache. Android
    # media stays cold until an explicitly targeted Android build.
    & (Join-Path $PSScriptRoot 'prefetch_android_native.ps1') -SkipAndroidMedia
    Assert-PureLiveCommandSucceeded 'Native dependency prefetch'

    python (Join-Path $PSScriptRoot 'audit_built_in_kotlin.py')
    Assert-PureLiveCommandSucceeded 'Built-in Kotlin audit'

    # This file vendors JavaScript in raw Dart strings and stays outside format.
    $formatExclusions = @('lib/core/scripts/douyin_sign.dart')
    [string[]] $dartFiles = @(
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
    if ($dartFiles.Count -gt 0) {
        & $flutterw dart format --output=none --set-exit-if-changed @dartFiles
        Assert-PureLiveCommandSucceeded 'Changed Dart file format check'
    }

    # Analyze is deliberately a single end-of-edit invocation.
    if ($shouldAnalyze) {
        & $flutterw analyze --no-pub --no-fatal-infos --no-fatal-warnings
        Assert-PureLiveCommandSucceeded 'Flutter Analyze'
    }

    if ($Scope -eq 'Full') {
        & $flutterw test --no-pub "--concurrency=$TestConcurrency"
        Assert-PureLiveCommandSucceeded 'Full Flutter test suite'
    } elseif ($resolvedTests.Count -gt 0) {
        # Keep all affected files in one test process so concurrency is bounded once.
        & $flutterw test --no-pub "--concurrency=$TestConcurrency" @resolvedTests
        Assert-PureLiveCommandSucceeded 'Focused Flutter tests'
    }

    if ($Scope -eq 'Full' -and -not $SkipInterfaces) {
        python (Join-Path $PSScriptRoot 'interface_probe.py')
        Assert-PureLiveCommandSucceeded 'Public interface probes'
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
        analyze_invocations = if ($shouldAnalyze) { 1 } else { 0 }
        test_concurrency = $TestConcurrency
        test_paths = if ($Scope -eq 'Full') { @('test/') } else { $resolvedTests }
        cache = [ordered]@{
            gradle_build_cache = 'enabled'
            configuration_cache = 'enabled'
            observation = 'not-applicable-to-flutter-quality-gate'
        }
        peak_resources = $resourceSummary
        active_heavy_processes_after = $remainingHeavyProcesses
        outputs = @()
        automatic_follow_up = $false
    }
    $recordPath = Write-PureLiveTaskRecord -RepoRoot $repoRoot -Record $record
    Write-Host "Quality record: $recordPath"
    Pop-Location
}
