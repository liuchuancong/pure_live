[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $BaseRef,
    [Parameter(Mandatory = $true)][string] $UpstreamRef,
    [string] $OutputPath,
    [switch] $ApproveHighRisk
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]] $Arguments)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $repoRoot @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)"
    }
    return @($output | ForEach-Object { $_.ToString() })
}

function Resolve-Commit {
    param([Parameter(Mandatory = $true)][string] $Ref)
    $lines = @(Invoke-GitText -Arguments @('rev-parse', '--verify', "$Ref^{commit}"))
    return $lines[0].Trim()
}

$baseSha = Resolve-Commit -Ref $BaseRef
$upstreamSha = Resolve-Commit -Ref $UpstreamRef
$range = "$baseSha..$upstreamSha"

$nameStatus = Invoke-GitText -Arguments @('diff', '--name-status', '--find-renames', $range)
$changes = @()
foreach ($line in $nameStatus) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "`t"
    $changes += [pscustomobject]@{
        status = $parts[0]
        path = $parts[-1].Replace('\', '/')
        previous_path = if ($parts.Count -gt 2) { $parts[1].Replace('\', '/') } else { $null }
    }
}

$riskRules = [ordered]@{
    live_playback = '^lib/(modules/live_play|player)/'
    platform_interfaces = '^lib/core/'
    persisted_settings = '^lib/common/services/settings/'
    release_and_versioning = '^(\.github/workflows/|pubspec\.yaml$|assets/version\.json$|windows/packaging/)'
    localization = '^assets/translations/'
    native_platform = '^(android|windows|linux|macos|ios)/'
}

$riskItems = @()
foreach ($change in $changes) {
    foreach ($entry in $riskRules.GetEnumerator()) {
        if ($change.path -match $entry.Value) {
            $riskItems += [pscustomobject]@{ category = $entry.Key; path = $change.path; status = $change.status }
        }
    }
}

$diffCheckOutput = @()
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $diffCheckOutput = @(& git -C $repoRoot diff --check $range 2>&1 | ForEach-Object { $_.ToString() })
    $diffCheckExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousPreference
}

$unsafeWorkflowDefaults = @()
foreach ($workflowChange in $changes | Where-Object { $_.path -match '^\.github/workflows/.+\.ya?ml$' }) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $content = @(& git -C $repoRoot show "${upstreamSha}:$($workflowChange.path)" 2>$null)
        $showExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($showExitCode -ne 0) { continue }
    $lineNumber = 0
    foreach ($line in $content) {
        $lineNumber++
        if ($line -match '^\s*default:\s*true\s*$') {
            $unsafeWorkflowDefaults += "$($workflowChange.path):$lineNumber"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $shortSha = $upstreamSha.Substring(0, 12)
    $OutputPath = Join-Path $repoRoot "local-artifacts\upstream-reviews\upstream-$shortSha.json"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $repoRoot $OutputPath
}

$commitCountLines = @(Invoke-GitText -Arguments @('rev-list', '--count', $range))
$result = [ordered]@{
    schema_version = 1
    reviewed_at_utc = [DateTime]::UtcNow.ToString('o')
    base_ref = $BaseRef
    base_sha = $baseSha
    upstream_ref = $UpstreamRef
    upstream_sha = $upstreamSha
    commit_count = [int]$commitCountLines[0]
    changed_file_count = $changes.Count
    changes = $changes
    high_risk_count = $riskItems.Count
    high_risk = $riskItems
    diff_check_passed = ($diffCheckExitCode -eq 0)
    diff_check_output = $diffCheckOutput
    unsafe_workflow_defaults = $unsafeWorkflowDefaults
    high_risk_approved = [bool]$ApproveHighRisk
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Upstream review: $baseSha..$upstreamSha"
Write-Host "Changed files: $($changes.Count); high-risk matches: $($riskItems.Count)"
Write-Host "Evidence: $OutputPath"

$requiresReview = $diffCheckExitCode -ne 0 -or $unsafeWorkflowDefaults.Count -gt 0 -or $riskItems.Count -gt 0
if ($requiresReview -and -not $ApproveHighRisk) {
    $summary = $riskItems | Group-Object category | ForEach-Object { "$($_.Name)=$($_.Count)" }
    throw "Upstream changes require documented review and -ApproveHighRisk: $($summary -join ', ')"
}
if ($diffCheckExitCode -ne 0) {
    Write-Warning "Incoming diff contains whitespace errors that must be fixed in the merge result: $($diffCheckOutput -join '; ')"
}
if ($unsafeWorkflowDefaults.Count -gt 0) {
    Write-Warning "Incoming diff enables manual workflow inputs; retain false defaults in the merge result: $($unsafeWorkflowDefaults -join ', ')"
}

Write-Host 'Upstream review gate passed.'
