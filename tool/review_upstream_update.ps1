[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $BaseRef,
    [Parameter(Mandatory = $true)][string] $UpstreamRef,
    [string] $OutputPath,
    [string] $AuditDocument,
    [switch] $ApproveHighRisk,
    [switch] $ReportOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-GitText {
    param(
        [Parameter(Mandatory = $true)][string[]] $Arguments,
        [int[]] $AllowedExitCodes = @(0)
    )

    $previousPreference = $ErrorActionPreference
    $nativePreference = Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
    $previousNativePreference = if ($nativePreference) { $PSNativeCommandUseErrorActionPreference } else { $null }
    $ErrorActionPreference = 'Continue'
    try {
        if ($nativePreference) { $PSNativeCommandUseErrorActionPreference = $false }
        $output = @(& git -C $repoRoot @Arguments 2>&1 | ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
    } finally {
        if ($nativePreference) { $PSNativeCommandUseErrorActionPreference = $previousNativePreference }
        $ErrorActionPreference = $previousPreference
    }
    if ($exitCode -notin $AllowedExitCodes) {
        throw "git $($Arguments -join ' ') failed ($exitCode): $($output -join [Environment]::NewLine)"
    }
    return [pscustomobject]@{ Lines = $output; ExitCode = $exitCode }
}

function Resolve-Commit {
    param([Parameter(Mandatory = $true)][string] $Ref)
    return (Invoke-GitText -Arguments @('rev-parse', '--verify', "$Ref^{commit}")).Lines[0].Trim()
}

function Resolve-Category {
    param([Parameter(Mandatory = $true)][string] $Path)

    $rules = [ordered]@{
        live_playback = '^lib/(modules/live_play|player)/'
        platform_interfaces = '^lib/core/'
        persisted_settings = '^lib/common/services/settings/'
        navigation_and_startup = '^lib/(routes/|main\.dart$|modules/(home|splash)/)'
        recording_and_storage = '^lib/(recorder/|common/global/app_path_manager\.dart$|plugins/(cache_manager|file_utils)\.dart$)'
        app_modules = '^lib/modules/'
        common_runtime = '^lib/common/'
        other_application_source = '^lib/'
        android_native = '^android/'
        windows_native = '^windows/'
        apple_native = '^(ios|macos)/'
        linux_native = '^linux/'
        dependencies_and_vendored = '^(pubspec\.(yaml|lock)$|plugins/|third_party/)'
        workflows_and_release = '^(\.github/workflows/|assets/version\.json$|assets/releases\.json$|RELEASE_NOTES\.md$)'
        translations_and_assets = '^assets/'
        tests = '^test/'
        tooling_and_policy = '^(tool/|docs/|BUILD_POLICY\.md$|UPSTREAM_REVIEW_POLICY\.md$|AGENTS\.md$|\.agents/)'
        repository_metadata = '.*'
    }
    foreach ($entry in $rules.GetEnumerator()) {
        if ($Path -match $entry.Value) { return $entry.Key }
    }
    return 'repository_metadata'
}

function Resolve-Risk {
    param([Parameter(Mandatory = $true)][string] $Category)
    if ($Category -in @(
        'live_playback', 'platform_interfaces', 'persisted_settings', 'navigation_and_startup',
        'recording_and_storage', 'android_native', 'windows_native', 'apple_native',
        'linux_native', 'dependencies_and_vendored', 'workflows_and_release'
    )) { return 'high' }
    if ($Category -in @('app_modules', 'common_runtime', 'other_application_source', 'translations_and_assets')) {
        return 'medium'
    }
    return 'low'
}

$baseSha = Resolve-Commit -Ref $BaseRef
$upstreamSha = Resolve-Commit -Ref $UpstreamRef
$mergeBase = (Invoke-GitText -Arguments @('merge-base', $baseSha, $upstreamSha)).Lines[0].Trim()
$ancestorCheck = Invoke-GitText -Arguments @('merge-base', '--is-ancestor', $upstreamSha, $baseSha) -AllowedExitCodes @(0, 1)
$upstreamAlreadyContained = $ancestorCheck.ExitCode -eq 0
$range = "$mergeBase..$upstreamSha"

$commitLines = if ($upstreamAlreadyContained) {
    @()
} else {
    (Invoke-GitText -Arguments @('log', '--reverse', '--format=%H%x09%aI%x09%an%x09%s', $range)).Lines
}
$commits = @()
foreach ($line in $commitLines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "`t", 4
    $commits += [pscustomobject]@{
        sha = $parts[0]
        authored_at = $parts[1]
        author = $parts[2]
        subject = $parts[3]
    }
}

$nameStatus = if ($commits.Count -eq 0) { @() } else {
    (Invoke-GitText -Arguments @('diff', '--name-status', '--find-renames', $range)).Lines
}
$numStat = if ($commits.Count -eq 0) { @() } else {
    (Invoke-GitText -Arguments @('diff', '--numstat', '--find-renames', $range)).Lines
}
$stats = @{}
foreach ($line in $numStat) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "`t"
    if ($parts.Count -lt 3) { continue }
    $stats[$parts[-1].Replace('\', '/')] = [pscustomobject]@{
        additions = if ($parts[0] -eq '-') { $null } else { [int]$parts[0] }
        deletions = if ($parts[1] -eq '-') { $null } else { [int]$parts[1] }
        binary = $parts[0] -eq '-' -or $parts[1] -eq '-'
    }
}

$changes = @()
foreach ($line in $nameStatus) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "`t"
    $path = $parts[-1].Replace('\', '/')
    $category = Resolve-Category -Path $path
    $stat = $stats[$path]
    $changes += [pscustomobject]@{
        status = $parts[0]
        path = $path
        previous_path = if ($parts.Count -gt 2) { $parts[1].Replace('\', '/') } else { $null }
        category = $category
        risk = Resolve-Risk -Category $category
        additions = if ($stat) { $stat.additions } else { $null }
        deletions = if ($stat) { $stat.deletions } else { $null }
        binary = if ($stat) { $stat.binary } else { $false }
    }
}

$diffCheckOutput = @()
$diffCheckExitCode = 0
$diffSummary = @()
$addedLines = @()
if ($commits.Count -gt 0) {
    $diffCheck = Invoke-GitText -Arguments @('diff', '--check', $range) -AllowedExitCodes @(0, 2)
    $diffCheckOutput = $diffCheck.Lines
    $diffCheckExitCode = $diffCheck.ExitCode
    $diffSummary = (Invoke-GitText -Arguments @('diff', '--summary', '--find-renames', $range)).Lines
    $rawDiff = (Invoke-GitText -Arguments @('diff', '--unified=0', '--no-color', $range)).Lines
    $addedLines = @($rawDiff | Where-Object { $_ -match '^\+(?!\+\+)' })
}

$violations = @()
foreach ($line in $addedLines) {
    if ($line -match '(^|\s)default:\s*true\s*$') { $violations += 'workflow_default_true' }
    if ($line -match '^\+\s*pull_request_target:\s*$') { $violations += 'pull_request_target' }
    if ($line -match '^\+\s*permissions:\s*write-all\s*$') { $violations += 'workflow_write_all' }
    if ($line -match 'uses:\s+[^\s]+@([^\s#]+)' -and $Matches[1] -notmatch '^[0-9a-f]{40}$') {
        $violations += 'mutable_action_reference'
    }
    if ($line -match '^\+\s+ref:\s*["'']?([^\s#"'']+)' -and $Matches[1] -notmatch '^[0-9a-f]{40}$') {
        $violations += 'mutable_git_dependency'
    }
    if ($line -match '(gh[opusr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[A-Z0-9]{16}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY)') {
        $violations += 'credential_material_in_added_lines'
    }
}
$violations = @($violations | Sort-Object -Unique)

$highRisk = @($changes | Where-Object risk -eq 'high')
$deletedSource = @($changes | Where-Object { $_.status -eq 'D' -and $_.path -match '^(lib|android|windows|linux|macos|ios)/' })
$binaryChanges = @($changes | Where-Object binary)

$resolvedAuditDocument = $null
$auditDocumentValid = $false
if (-not [string]::IsNullOrWhiteSpace($AuditDocument)) {
    $resolvedAuditDocument = if ([IO.Path]::IsPathRooted($AuditDocument)) { $AuditDocument } else { Join-Path $repoRoot $AuditDocument }
    if (Test-Path -LiteralPath $resolvedAuditDocument -PathType Leaf) {
        $auditText = Get-Content -LiteralPath $resolvedAuditDocument -Raw -Encoding UTF8
        $requiredMarkers = @($upstreamSha, $mergeBase, 'file_review', 'conflict_resolution', 'verification_plan')
        $auditDocumentValid = @($requiredMarkers | Where-Object { -not $auditText.Contains($_) }).Count -eq 0
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "local-artifacts\upstream-reviews\upstream-$($upstreamSha.Substring(0, 12)).json"
} elseif (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $repoRoot $OutputPath
}

$result = [ordered]@{
    schema_version = 2
    reviewed_at_utc = [DateTime]::UtcNow.ToString('o')
    base_ref = $BaseRef
    base_sha = $baseSha
    upstream_ref = $UpstreamRef
    upstream_sha = $upstreamSha
    merge_base_sha = $mergeBase
    upstream_already_contained = $upstreamAlreadyContained
    incoming_range = $range
    commit_count = $commits.Count
    commits = $commits
    changed_file_count = $changes.Count
    changes = $changes
    category_counts = @($changes | Group-Object category | ForEach-Object {
        [pscustomobject]@{ category = $_.Name; count = $_.Count }
    })
    high_risk_count = $highRisk.Count
    high_risk = $highRisk
    deleted_source = $deletedSource
    binary_changes = $binaryChanges
    diff_summary = $diffSummary
    diff_check_passed = $diffCheckExitCode -eq 0
    diff_check_output = $diffCheckOutput
    violations = $violations
    audit_document = $resolvedAuditDocument
    audit_document_valid = $auditDocumentValid
    high_risk_approved = [bool]$ApproveHighRisk
    report_only = [bool]$ReportOnly
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Upstream review: base=$baseSha upstream=$upstreamSha merge-base=$mergeBase"
Write-Host "Incoming commits: $($commits.Count); files: $($changes.Count); high-risk: $($highRisk.Count)"
Write-Host "Evidence: $OutputPath"

if ($diffCheckExitCode -ne 0) {
    throw "Incoming diff contains whitespace errors: $($diffCheckOutput -join '; ')"
}
if ($violations.Count -gt 0) {
    throw "Incoming diff violates repository policy: $($violations -join ', ')"
}
if ($commits.Count -gt 0 -and -not $ReportOnly -and -not $ApproveHighRisk) {
    throw 'Every incoming upstream commit requires a documented whole-diff review and -ApproveHighRisk.'
}
if ($commits.Count -gt 0 -and -not $ReportOnly -and -not $auditDocumentValid) {
    throw 'Incoming upstream commits require an audit document containing the frozen SHA, merge base, file_review, conflict_resolution and verification_plan.'
}

if ($ReportOnly -and $commits.Count -gt 0) {
    Write-Host 'Whole-upstream report completed; merging still requires the documented approval gate.'
} else {
    Write-Host 'Whole-upstream review gate passed.'
}
