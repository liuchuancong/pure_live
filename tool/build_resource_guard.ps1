Set-StrictMode -Version Latest

$script:PureLiveHeavyProcessNames = @(
    'gradle',
    'java',
    'javaw',
    'dart',
    'dartaotruntime',
    'flutter',
    'rg'
)

function Get-PureLiveHeavyProcessSnapshot {
    $items = @(Get-Process -Name $script:PureLiveHeavyProcessNames -ErrorAction SilentlyContinue)
    $snapshot = @{}
    foreach ($item in $items) {
        $snapshot[$item.Id] = [pscustomobject]@{
            Id = $item.Id
            Name = $item.ProcessName
            CpuSeconds = if ($null -eq $item.CPU) { 0.0 } else { [double]$item.CPU }
            WorkingSetBytes = [long]$item.WorkingSet64
        }
    }
    return $snapshot
}

function Get-PureLiveActiveHeavyProcess {
    [CmdletBinding()]
    param(
        [int] $SampleMilliseconds = 750,
        [double] $CpuSecondsThreshold = 0.12
    )

    $before = Get-PureLiveHeavyProcessSnapshot
    Start-Sleep -Milliseconds $SampleMilliseconds
    $after = Get-PureLiveHeavyProcessSnapshot
    $active = @()
    foreach ($id in $after.Keys) {
        if (-not $before.ContainsKey($id)) { continue }
        $current = $after[$id]
        $cpuDelta = [Math]::Max(0.0, $current.CpuSeconds - $before[$id].CpuSeconds)
        $commandLine = $null
        try {
            $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $id" -ErrorAction Stop).CommandLine
        } catch {
            $commandLine = $null
        }
        $isLongLivedDaemon = $commandLine -match
            '(org\.gradle\.launcher\.daemon\.bootstrap\.GradleDaemon|org\.jetbrains\.kotlin\.daemon\.KotlinCompileDaemon|analysis_server\.dart\.snapshot)'
        $isBuildClient = $commandLine -match
            '(GradleWrapperMain|org\.gradle\.launcher\.GradleMain|GradleWorkerMain|flutter_tools\.snapshot.+\b(build|test|analyze|pub)\b|\bdart(?:\.exe)?.+\b(test|analyze|compile|run)\b)'

        # Gradle, Kotlin and Dart analysis daemons intentionally remain alive
        # between incremental builds. Their health checks and housekeeping can
        # cross the generic CPU threshold even when no build owns them. Keep
        # the cache-warm daemons, but only classify them as heavy when they are
        # doing sustained work; explicit build clients are active immediately.
        if ($isLongLivedDaemon -and $cpuDelta -lt 1.25) { continue }
        # `rg` without an explicit path can remain alive while waiting for
        # stdin. Treat it like every other tool and require measurable work;
        # otherwise one idle search process can block all builds indefinitely.
        if ($cpuDelta -lt $CpuSecondsThreshold -and -not $isBuildClient) { continue }

        $active += [pscustomobject]@{
            Id = $id
            Name = $current.Name
            CpuDeltaSeconds = [Math]::Round($cpuDelta, 3)
            WorkingSetBytes = $current.WorkingSetBytes
            CommandLine = $commandLine
        }
    }
    return $active
}

function Enter-PureLiveHeavyTaskSlot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $TaskName,
        [int] $QueueTimeoutMinutes = 180
    )

    $mutex = [System.Threading.Mutex]::new($false, 'Local\Codex.HeavyBuildSlot')
    $deadline = [DateTime]::UtcNow.AddMinutes($QueueTimeoutMinutes)
    $hasMutex = $false
    while (-not $hasMutex) {
        if ([DateTime]::UtcNow -ge $deadline) {
            $mutex.Dispose()
            throw "Timed out while queuing heavy task '$TaskName'."
        }
        try {
            $hasMutex = $mutex.WaitOne([TimeSpan]::FromSeconds(5))
        } catch [System.Threading.AbandonedMutexException] {
            $hasMutex = $true
        }
        if (-not $hasMutex) {
            Write-Host "Heavy task '$TaskName' is queued behind another Codex workspace."
        }
    }

    try {
        $quietSamples = 0
        while ($quietSamples -lt 2) {
            if ([DateTime]::UtcNow -ge $deadline) {
                throw "Timed out while waiting for active build processes before '$TaskName'."
            }
            $active = @(Get-PureLiveActiveHeavyProcess)
            if ($active.Count -eq 0) {
                $quietSamples++
                continue
            }
            $quietSamples = 0
            $summary = ($active | ForEach-Object { "$($_.Name)#$($_.Id)" }) -join ', '
            Write-Host "Heavy task '$TaskName' is queued; active processes: $summary"
            Start-Sleep -Seconds 2
        }
    } catch {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
        throw
    }

    return [pscustomobject]@{
        TaskName = $TaskName
        Mutex = $mutex
        EnteredAtUtc = [DateTime]::UtcNow
    }
}

function Exit-PureLiveHeavyTaskSlot {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] $Lease)

    if ($Lease.Mutex) {
        $Lease.Mutex.ReleaseMutex()
        $Lease.Mutex.Dispose()
    }
}

function Start-PureLiveResourceMonitor {
    [CmdletBinding()]
    param()

    $names = @($script:PureLiveHeavyProcessNames)
    $job = Start-Job -Name "pure-live-resource-$PID-$([Guid]::NewGuid().ToString('N'))" -ArgumentList (, $names) -ScriptBlock {
        param([string[]] $ProcessNames)
        $logicalProcessors = [Math]::Max(1, [Environment]::ProcessorCount)
        $previousAt = [DateTime]::UtcNow
        $previousCpu = $null
        while ($true) {
            $processes = @(Get-Process -Name $ProcessNames -ErrorAction SilentlyContinue)
            $now = [DateTime]::UtcNow
            $cpuSeconds = [double](($processes | Measure-Object -Property CPU -Sum).Sum)
            $workingSet = [long](($processes | Measure-Object -Property WorkingSet64 -Sum).Sum)
            $cpuPercent = 0.0
            if ($null -ne $previousCpu) {
                $elapsed = [Math]::Max(0.001, ($now - $previousAt).TotalSeconds)
                $cpuPercent = [Math]::Max(0.0, (($cpuSeconds - $previousCpu) / $elapsed / $logicalProcessors) * 100.0)
            }
            [pscustomobject]@{
                TimestampUtc = $now.ToString('o')
                CpuPercent = [Math]::Round($cpuPercent, 2)
                WorkingSetBytes = $workingSet
                ProcessCount = $processes.Count
            }
            $previousAt = $now
            $previousCpu = $cpuSeconds
            Start-Sleep -Seconds 1
        }
    }
    return $job
}

function Stop-PureLiveResourceMonitor {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] $Job)

    Stop-Job -Job $Job -ErrorAction SilentlyContinue
    $samples = @(Receive-Job -Job $Job -ErrorAction SilentlyContinue)
    Remove-Job -Job $Job -Force -ErrorAction SilentlyContinue
    if ($samples.Count -eq 0) {
        return [pscustomobject]@{
            PeakCpuPercent = 0.0
            PeakWorkingSetBytes = 0
            PeakProcessCount = 0
            SampleCount = 0
        }
    }
    return [pscustomobject]@{
        PeakCpuPercent = [double](($samples | Measure-Object -Property CpuPercent -Maximum).Maximum)
        PeakWorkingSetBytes = [long](($samples | Measure-Object -Property WorkingSetBytes -Maximum).Maximum)
        PeakProcessCount = [int](($samples | Measure-Object -Property ProcessCount -Maximum).Maximum)
        SampleCount = $samples.Count
    }
}

function Wait-PureLiveBackgroundCpuSettle {
    [CmdletBinding()]
    param([int] $TimeoutSeconds = 20)

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $active = @(Get-PureLiveActiveHeavyProcess)
        if ($active.Count -eq 0) { return 0 }
        Start-Sleep -Seconds 1
    } while ([DateTime]::UtcNow -lt $deadline)
    return $active.Count
}

function Write-PureLiveTaskRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepoRoot,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary] $Record
    )

    $directory = Join-Path $RepoRoot 'local-artifacts\build-records'
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $safeTask = ($Record.task -replace '[^A-Za-z0-9_.-]', '-')
    $path = Join-Path $directory "$stamp-$safeTask.json"
    $Record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding utf8
    return $path
}
