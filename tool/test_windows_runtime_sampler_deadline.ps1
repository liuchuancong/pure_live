$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# A collector slower than the one-second interval must skip missed slots and
# stop at the elapsed deadline, rather than executing every planned sample.
$target = Start-Process -FilePath (Get-Command powershell.exe).Source `
    -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 45' `
    -WindowStyle Hidden -PassThru
try {
    function Get-CimInstance {
        param([string] $ClassName, [string] $Filter, [string] $ErrorAction)
        if ($ClassName -eq 'Win32_VideoController') { return }
        if ($ClassName -ne 'Win32_Process') { throw "Unexpected CIM class $ClassName" }
        Start-Sleep -Milliseconds 1800
        return [pscustomobject]@{ ReadTransferCount = 0; WriteTransferCount = 0 }
    }

    $result = . (Join-Path $PSScriptRoot 'sample_windows_runtime.ps1') `
        -TargetProcessId $target.Id -DurationSeconds 10 -IntervalSeconds 1 `
        -Scenario 'sampler-deadline-test'
    $summary = Get-Content -LiteralPath $result.SummaryPath -Raw | ConvertFrom-Json
    $csvRows = @(Import-Csv -LiteralPath $result.CsvPath)
    if ($summary.sample_count -ne $csvRows.Count -or $summary.sample_count -lt 2 -or $summary.sample_count -gt 7) {
        throw "Incorrect deadline sampling count: $($summary.sample_count)"
    }
    if ($summary.actual_duration_seconds -gt 16 -or $summary.requested_duration_seconds -ne 10) {
        throw "Sampler exceeded elapsed deadline: $($summary.actual_duration_seconds)s"
    }
    Write-Output "Windows runtime sampler deadline: $($summary.sample_count) rows in $($summary.actual_duration_seconds)s passed"
} finally {
    if (Get-Process -Id $target.Id -ErrorAction SilentlyContinue) {
        Stop-Process -Id $target.Id -Force
    }
}
