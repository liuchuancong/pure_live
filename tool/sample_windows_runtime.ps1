[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 2147483647)]
    [int] $TargetProcessId,

    [ValidateRange(10, 43200)]
    [int] $DurationSeconds = 600,

    [ValidateRange(1, 300)]
    [int] $IntervalSeconds = 10,

    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$')]
    [string] $Scenario = 'runtime',

    [string] $OutputDirectory = 'local-artifacts\diagnostics\windows-regression',

    [switch] $IncludeGpu
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'windows_runtime_metrics.ps1')

function Get-Percentile {
    param(
        [double[]] $Values,
        [ValidateRange(0, 1)]
        [double] $Percentile
    )

    if ($Values.Count -eq 0) { return $null }
    $ordered = @($Values | Sort-Object)
    $index = [Math]::Ceiling($Percentile * $ordered.Count) - 1
    $index = [Math]::Max(0, [Math]::Min($index, $ordered.Count - 1))
    return [double]$ordered[$index]
}

function Get-LinearSlopePerMinute {
    param(
        [object[]] $Samples,
        [string] $Property
    )

    if ($Samples.Count -lt 2) { return $null }
    $count = [double]$Samples.Count
    $sumX = 0.0
    $sumY = 0.0
    $sumXY = 0.0
    $sumXX = 0.0
    foreach ($sample in $Samples) {
        $x = [double]$sample.elapsed_seconds
        $y = [double]$sample.$Property
        $sumX += $x
        $sumY += $y
        $sumXY += $x * $y
        $sumXX += $x * $x
    }
    $denominator = ($count * $sumXX) - ($sumX * $sumX)
    if ([Math]::Abs($denominator) -lt 0.000001) { return 0.0 }
    return ((($count * $sumXY) - ($sumX * $sumY)) / $denominator) * 60.0
}

function Get-MetricSummary {
    param(
        [object[]] $Samples,
        [string] $Property
    )

    $usableSamples = @($Samples | Where-Object { $null -ne $_.$Property })
    $values = @($usableSamples | ForEach-Object { [double]$_.$Property })
    if ($values.Count -eq 0) { return $null }
    return [ordered]@{
        first = $values[0]
        last = $values[-1]
        minimum = [double](($values | Measure-Object -Minimum).Minimum)
        maximum = [double](($values | Measure-Object -Maximum).Maximum)
        average = [Math]::Round([double](($values | Measure-Object -Average).Average), 4)
        p95 = [Math]::Round((Get-Percentile -Values $values -Percentile 0.95), 4)
        slope_per_minute = [Math]::Round((Get-LinearSlopePerMinute -Samples $usableSamples -Property $Property), 4)
    }
}

function Get-GpuSnapshot {
    param(
        [Parameter(Mandatory = $true)][int] $ProcessId,
        [Parameter(Mandatory = $true)][string] $EngineCounterPath,
        [string[]] $MemoryCounterPaths = @()
    )

    $result = [ordered]@{
        EngineSumPercent = $null
        ThreeDPercent = $null
        VideoDecodePercent = $null
        VideoProcessingPercent = $null
        CopyPercent = $null
        DedicatedMiB = $null
        SharedMiB = $null
    }
    try {
        $engineSamples = @(
            (Get-Counter -Counter $EngineCounterPath -ErrorAction Stop).CounterSamples |
                Where-Object { $_.InstanceName -match "^pid_${ProcessId}_" }
        )
        if ($engineSamples.Count -gt 0) {
            $sum = {
                param([object[]] $Items)
                if ($Items.Count -eq 0) { return 0.0 }
                return [double](($Items | Measure-Object -Property CookedValue -Sum).Sum)
            }
            $result.EngineSumPercent = & $sum $engineSamples
            $result.ThreeDPercent = & $sum @($engineSamples | Where-Object { $_.InstanceName -match '_engtype_3d$' })
            $result.VideoDecodePercent = & $sum @(
                $engineSamples | Where-Object { $_.InstanceName -match '_engtype_(videodecode|video codec)$' }
            )
            $result.VideoProcessingPercent = & $sum @(
                $engineSamples | Where-Object { $_.InstanceName -match '_engtype_videoprocessing$' }
            )
            $result.CopyPercent = & $sum @($engineSamples | Where-Object { $_.InstanceName -match '_engtype_copy$' })
        }

        if ($MemoryCounterPaths.Count -gt 0) {
            $memorySamples = @(
                (Get-Counter -Counter $MemoryCounterPaths -ErrorAction Stop).CounterSamples |
                    Where-Object { $_.InstanceName -match "^pid_${ProcessId}_" }
            )
            $dedicated = @($memorySamples | Where-Object { $_.Path -match '\\Dedicated Usage$' })
            $shared = @($memorySamples | Where-Object { $_.Path -match '\\Shared Usage$' })
            if ($dedicated.Count -gt 0) {
                $result.DedicatedMiB = [double](($dedicated | Measure-Object -Property CookedValue -Sum).Sum) / 1MB
            }
            if ($shared.Count -gt 0) {
                $result.SharedMiB = [double](($shared | Measure-Object -Property CookedValue -Sum).Sum) / 1MB
            }
        }
    } catch {
        # GPU counters are optional diagnostic evidence. Preserve the CPU/RAM
        # run and record the missing samples instead of fabricating zero load.
    }
    return [pscustomobject]$result
}

$initialProcess = Get-Process -Id $TargetProcessId -ErrorAction Stop
$initialProcessName = $initialProcess.ProcessName
$initialExecutable = $initialProcess.Path
$initialFileVersion = $null
$initialProductVersion = $null
if ($initialExecutable -and (Test-Path -LiteralPath $initialExecutable)) {
    $versionInfo = (Get-Item -LiteralPath $initialExecutable).VersionInfo
    $initialFileVersion = $versionInfo.FileVersion
    $initialProductVersion = $versionInfo.ProductVersion
}
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) {
    [IO.Path]::GetFullPath($OutputDirectory)
} else {
    [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
}
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$baseName = "$stamp-$Scenario-pid$TargetProcessId"
$csvPath = Join-Path $resolvedOutput "$baseName.csv"
$summaryPath = Join-Path $resolvedOutput "$baseName-summary.json"
$logicalProcessors = [Math]::Max(1, [Environment]::ProcessorCount)
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
$samples = [Collections.Generic.List[object]]::new()
$previousCpuSeconds = $null
$previousElapsed = 0.0
$processExitObserved = $false
$nextSampleElapsed = 0.0
$gpuEngineCounterPath = $null
[string[]] $gpuMemoryCounterPaths = @()
if ($IncludeGpu) {
    try {
        $gpuEngineCounterPath = (Get-Counter -ListSet 'GPU Engine' -ErrorAction Stop).Paths |
            Where-Object { $_ -match '\\Utilization Percentage$' } |
            Select-Object -First 1
        $gpuMemoryCounterPaths = @(
            (Get-Counter -ListSet 'GPU Process Memory' -ErrorAction Stop).Paths |
                Where-Object { $_ -match '\\(Dedicated|Shared) Usage$' }
        )
    } catch {
        $gpuEngineCounterPath = $null
        $gpuMemoryCounterPaths = @()
    }
}
$displayAdapters = @(
    Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
        ForEach-Object {
            [ordered]@{
                name = $_.Name
                driver_version = $_.DriverVersion
                current_width = $_.CurrentHorizontalResolution
                current_height = $_.CurrentVerticalResolution
                current_refresh_hz = $_.CurrentRefreshRate
                video_mode = $_.VideoModeDescription
            }
        }
)

while ($true) {
    # Sampling a busy GPU can take longer than the requested interval. Use the
    # wall-clock deadline rather than a fixed iteration count, and skip missed
    # slots instead of extending a 35-minute run to 45+ minutes.
    if ($samples.Count -gt 0 -and $stopwatch.Elapsed.TotalSeconds -ge $DurationSeconds) { break }
    if ($nextSampleElapsed -gt $DurationSeconds) { break }
    $remainingMilliseconds = ($nextSampleElapsed - $stopwatch.Elapsed.TotalSeconds) * 1000.0
    if ($remainingMilliseconds -gt 0) {
        Start-Sleep -Milliseconds ([Math]::Ceiling($remainingMilliseconds))
    }
    if ($samples.Count -gt 0 -and $stopwatch.Elapsed.TotalSeconds -ge $DurationSeconds) { break }

    $process = Get-Process -Id $TargetProcessId -ErrorAction SilentlyContinue
    if (-not $process) {
        $processExitObserved = $true
        break
    }

    try {
        $elapsed = $stopwatch.Elapsed.TotalSeconds
        $cpuSeconds = [double]$process.CPU
        $processCounters = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $TargetProcessId" -ErrorAction SilentlyContinue
        $readTransferCount = if ($processCounters) { [double]$processCounters.ReadTransferCount } else { 0.0 }
        $writeTransferCount = if ($processCounters) { [double]$processCounters.WriteTransferCount } else { 0.0 }
        $elapsedDelta = $elapsed - $previousElapsed
        $cpuPercent = Get-PureLiveIntervalCpuPercent -CurrentCpuSeconds $cpuSeconds `
            -PreviousCpuSeconds $previousCpuSeconds -ElapsedSeconds $elapsedDelta `
            -LogicalProcessors $logicalProcessors

        $gpu = if ($IncludeGpu -and $gpuEngineCounterPath) {
            Get-GpuSnapshot `
                -ProcessId $TargetProcessId `
                -EngineCounterPath $gpuEngineCounterPath `
                -MemoryCounterPaths $gpuMemoryCounterPaths
        } else {
            $null
        }

        $sample = [pscustomobject][ordered]@{
            timestamp_utc = [DateTime]::UtcNow.ToString('o')
            elapsed_seconds = [Math]::Round($elapsed, 3)
            scenario = $Scenario
            process_id = $TargetProcessId
            responding = [bool]$process.Responding
            cpu_percent = $cpuPercent
            working_set_mib = [Math]::Round($process.WorkingSet64 / 1MB, 4)
            private_bytes_mib = [Math]::Round($process.PrivateMemorySize64 / 1MB, 4)
            handles = [int]$process.HandleCount
            threads = [int]$process.Threads.Count
            io_read_mib = [Math]::Round($readTransferCount / 1MB, 4)
            io_write_mib = [Math]::Round($writeTransferCount / 1MB, 4)
            gpu_engine_sum_percent = if ($null -ne $gpu -and $null -ne $gpu.EngineSumPercent) { [Math]::Round($gpu.EngineSumPercent, 4) } else { $null }
            gpu_3d_percent = if ($null -ne $gpu -and $null -ne $gpu.ThreeDPercent) { [Math]::Round($gpu.ThreeDPercent, 4) } else { $null }
            gpu_video_decode_percent = if ($null -ne $gpu -and $null -ne $gpu.VideoDecodePercent) { [Math]::Round($gpu.VideoDecodePercent, 4) } else { $null }
            gpu_video_processing_percent = if ($null -ne $gpu -and $null -ne $gpu.VideoProcessingPercent) { [Math]::Round($gpu.VideoProcessingPercent, 4) } else { $null }
            gpu_copy_percent = if ($null -ne $gpu -and $null -ne $gpu.CopyPercent) { [Math]::Round($gpu.CopyPercent, 4) } else { $null }
            gpu_dedicated_mib = if ($null -ne $gpu -and $null -ne $gpu.DedicatedMiB) { [Math]::Round($gpu.DedicatedMiB, 4) } else { $null }
            gpu_shared_mib = if ($null -ne $gpu -and $null -ne $gpu.SharedMiB) { [Math]::Round($gpu.SharedMiB, 4) } else { $null }
        }
    } catch {
        # A process may exit between Get-Process and a later property getter.
        # Preserve completed rows instead of mistaking that race for a sampler failure.
        if (-not (Get-Process -Id $TargetProcessId -ErrorAction SilentlyContinue)) {
            $processExitObserved = $true
            break
        }
        throw
    }

    $samples.Add($sample)
    # Keep long-soak evidence durable even when the target crashes or this
    # sampler encounters a later error. The final summary is written below.
    $sample | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8 -Append

    $previousCpuSeconds = $cpuSeconds
    $previousElapsed = $elapsed
    $nextSampleElapsed = ([Math]::Floor($stopwatch.Elapsed.TotalSeconds / $IntervalSeconds) + 1) * $IntervalSeconds
}

$stopwatch.Stop()
if ($samples.Count -eq 0) {
    throw "Process $TargetProcessId exited before the first sample."
}

$allResponding = -not [bool]($samples | Where-Object { -not $_.responding } | Select-Object -First 1)
$summary = [ordered]@{
    schema = 1
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    scenario = $Scenario
    process_id = $TargetProcessId
    process_name = $initialProcessName
    executable = $initialExecutable
    file_version = $initialFileVersion
    product_version = $initialProductVersion
    requested_duration_seconds = $DurationSeconds
    actual_duration_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
    interval_seconds = $IntervalSeconds
    sample_count = $samples.Count
    cpu_sample_count = @($samples | Where-Object { $null -ne $_.cpu_percent }).Count
    cpu_baseline_policy = 'exclude-first-and-invalid-intervals'
    logical_processors = $logicalProcessors
    display_adapters = $displayAdapters
    gpu_sampling_requested = [bool]$IncludeGpu
    gpu_counter_available = [bool]$gpuEngineCounterPath
    all_samples_responding = $allResponding
    process_exit_observed = $processExitObserved
    metrics = [ordered]@{
        cpu_percent = Get-MetricSummary -Samples $samples -Property 'cpu_percent'
        working_set_mib = Get-MetricSummary -Samples $samples -Property 'working_set_mib'
        private_bytes_mib = Get-MetricSummary -Samples $samples -Property 'private_bytes_mib'
        handles = Get-MetricSummary -Samples $samples -Property 'handles'
        threads = Get-MetricSummary -Samples $samples -Property 'threads'
        io_read_mib = Get-MetricSummary -Samples $samples -Property 'io_read_mib'
        io_write_mib = Get-MetricSummary -Samples $samples -Property 'io_write_mib'
        gpu_engine_sum_percent = Get-MetricSummary -Samples $samples -Property 'gpu_engine_sum_percent'
        gpu_3d_percent = Get-MetricSummary -Samples $samples -Property 'gpu_3d_percent'
        gpu_video_decode_percent = Get-MetricSummary -Samples $samples -Property 'gpu_video_decode_percent'
        gpu_video_processing_percent = Get-MetricSummary -Samples $samples -Property 'gpu_video_processing_percent'
        gpu_copy_percent = Get-MetricSummary -Samples $samples -Property 'gpu_copy_percent'
        gpu_dedicated_mib = Get-MetricSummary -Samples $samples -Property 'gpu_dedicated_mib'
        gpu_shared_mib = Get-MetricSummary -Samples $samples -Property 'gpu_shared_mib'
    }
    csv_path = [IO.Path]::GetFullPath($csvPath)
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding utf8

Write-Output ([pscustomobject]@{
    CsvPath = [IO.Path]::GetFullPath($csvPath)
    SummaryPath = [IO.Path]::GetFullPath($summaryPath)
    Samples = $samples.Count
    AllResponding = $allResponding
    ProcessExitObserved = $processExitObserved
})
