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

    [string] $OutputDirectory = 'local-artifacts\diagnostics\windows-regression'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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

    $values = @($Samples | ForEach-Object { [double]$_.$Property })
    if ($values.Count -eq 0) { return $null }
    return [ordered]@{
        first = $values[0]
        last = $values[-1]
        minimum = [double](($values | Measure-Object -Minimum).Minimum)
        maximum = [double](($values | Measure-Object -Maximum).Maximum)
        average = [Math]::Round([double](($values | Measure-Object -Average).Average), 4)
        p95 = [Math]::Round((Get-Percentile -Values $values -Percentile 0.95), 4)
        slope_per_minute = [Math]::Round((Get-LinearSlopePerMinute -Samples $Samples -Property $Property), 4)
    }
}

$initialProcess = Get-Process -Id $TargetProcessId -ErrorAction Stop
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
$previousCpuSeconds = [double]$initialProcess.CPU
$previousElapsed = 0.0
$processExitObserved = $false
$plannedSampleCount = [Math]::Floor($DurationSeconds / $IntervalSeconds) + 1

for ($sampleIndex = 0; $sampleIndex -lt $plannedSampleCount; $sampleIndex++) {
    if ($sampleIndex -gt 0) {
        $targetElapsedMilliseconds = $sampleIndex * $IntervalSeconds * 1000.0
        $remainingMilliseconds = $targetElapsedMilliseconds - $stopwatch.Elapsed.TotalMilliseconds
        if ($remainingMilliseconds -gt 0) {
            Start-Sleep -Milliseconds ([Math]::Ceiling($remainingMilliseconds))
        }
    }

    $process = Get-Process -Id $TargetProcessId -ErrorAction SilentlyContinue
    if (-not $process) {
        $processExitObserved = $true
        break
    }

    $elapsed = $stopwatch.Elapsed.TotalSeconds
    $cpuSeconds = [double]$process.CPU
    $processCounters = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $TargetProcessId" -ErrorAction SilentlyContinue
    $readTransferCount = if ($processCounters) { [double]$processCounters.ReadTransferCount } else { 0.0 }
    $writeTransferCount = if ($processCounters) { [double]$processCounters.WriteTransferCount } else { 0.0 }
    $elapsedDelta = $elapsed - $previousElapsed
    $cpuPercent = if ($elapsedDelta -gt 0) {
        (($cpuSeconds - $previousCpuSeconds) / $elapsedDelta / $logicalProcessors) * 100.0
    } else {
        0.0
    }

    $samples.Add([pscustomobject][ordered]@{
        timestamp_utc = [DateTime]::UtcNow.ToString('o')
        elapsed_seconds = [Math]::Round($elapsed, 3)
        scenario = $Scenario
        process_id = $TargetProcessId
        responding = [bool]$process.Responding
        cpu_percent = [Math]::Round([Math]::Max(0.0, $cpuPercent), 4)
        working_set_mib = [Math]::Round($process.WorkingSet64 / 1MB, 4)
        private_bytes_mib = [Math]::Round($process.PrivateMemorySize64 / 1MB, 4)
        handles = [int]$process.HandleCount
        threads = [int]$process.Threads.Count
        io_read_mib = [Math]::Round($readTransferCount / 1MB, 4)
        io_write_mib = [Math]::Round($writeTransferCount / 1MB, 4)
    })

    $previousCpuSeconds = $cpuSeconds
    $previousElapsed = $elapsed
}

$stopwatch.Stop()
if ($samples.Count -eq 0) {
    throw "Process $TargetProcessId exited before the first sample."
}

$samples | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
$allResponding = -not [bool]($samples | Where-Object { -not $_.responding } | Select-Object -First 1)
$summary = [ordered]@{
    schema = 1
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    scenario = $Scenario
    process_id = $TargetProcessId
    process_name = $initialProcess.ProcessName
    executable = $initialProcess.Path
    file_version = $initialProcess.MainModule.FileVersionInfo.FileVersion
    product_version = $initialProcess.MainModule.FileVersionInfo.ProductVersion
    requested_duration_seconds = $DurationSeconds
    actual_duration_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
    interval_seconds = $IntervalSeconds
    sample_count = $samples.Count
    logical_processors = $logicalProcessors
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
