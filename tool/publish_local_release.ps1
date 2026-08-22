[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)] [string] $Tag,
    [string] $ArtifactDirectory,
    [string] $Repository = 'wzgrx/pure_live',
    [switch] $CreateTag,
    [switch] $AllowQaArtifacts
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseNotesPath = $null
if (-not $ArtifactDirectory) {
    $ArtifactDirectory = Get-ChildItem (Join-Path $repoRoot 'local-artifacts') -Directory |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ArtifactDirectory -or -not (Test-Path -LiteralPath $ArtifactDirectory)) {
    throw 'Local artifact directory was not found.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI (gh) is required.' }

Push-Location $repoRoot
try {
    if (git status --porcelain) { throw 'Commit all changes before publishing.' }
    $versionLine = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)' | Select-Object -First 1
    $fullVersion = $versionLine.Matches[0].Groups[1].Value
    $displayVersion = $fullVersion.Split('+')[0]
    $artifactVersion = $fullVersion.Replace('+', '-')
    if ($Tag -ne "v$displayVersion") { throw "Tag $Tag does not match pubspec version v$displayVersion." }
    if ((Split-Path -Leaf $ArtifactDirectory) -ne $artifactVersion) {
        throw "Artifact directory must be local-artifacts/$artifactVersion for $Tag."
    }

    $metadataPath = Join-Path $ArtifactDirectory 'BUILD_METADATA.json'
    if (-not (Test-Path -LiteralPath $metadataPath)) { throw 'BUILD_METADATA.json is missing.' }
    $metadata = Get-Content -LiteralPath $metadataPath -Raw -Encoding utf8 | ConvertFrom-Json
    $headCommit = (git rev-parse HEAD).Trim()
    $releaseCommit = if ($metadata.release_commit) {
        $metadata.release_commit
    } else {
        $metadata.source_commit
    }
    if ($releaseCommit -ne $headCommit -or $metadata.tracked_files_dirty) {
        throw 'Release metadata does not match the current clean commit.'
    }
    $apks = Get-ChildItem $ArtifactDirectory -File -Filter '*.apk'
    if ($apks -and $metadata.android_signing -ne 'release' -and -not $AllowQaArtifacts) {
        throw 'Debug-signed APKs are blocked from an official Release. Configure the repository release key or publish Windows-only artifacts.'
    }

    $checksumPath = Join-Path $ArtifactDirectory 'SHA256SUMS.txt'
    if (-not (Test-Path -LiteralPath $checksumPath)) { throw 'SHA256SUMS.txt is missing.' }
    foreach ($line in Get-Content -LiteralPath $checksumPath) {
        if ($line -notmatch '^([0-9a-fA-F]{64}) \*(.+)$') { throw "Invalid checksum line: $line" }
        $assetPath = Join-Path $ArtifactDirectory $Matches[2]
        if (-not (Test-Path -LiteralPath $assetPath)) { throw "Checksummed asset is missing: $($Matches[2])" }
        $actual = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash
        if ($actual -ne $Matches[1]) { throw "Checksum mismatch: $($Matches[2])" }
    }
    if ($CreateTag -and -not (git tag --list $Tag)) {
        if ($PSCmdlet.ShouldProcess($Tag, 'Create and push tag')) {
            git tag -a $Tag -m "Pure Live $Tag"
            git push origin $Tag
        }
    }
    # Windows PowerShell 5.1 defaults Get-Content to the active ANSI code page.
    # Reading UTF-8 Markdown without an explicit encoding corrupts Chinese text
    # before gh uploads it, even though the temporary file itself is UTF-8.
    $releaseNotes = Get-Content -LiteralPath 'RELEASE_NOTES.md' -Raw -Encoding utf8
    $releasePattern = '(?ms)^# Pure Live\s+' + [regex]::Escape($Tag) + '\s*$.*?(?=^---\s*$|\z)'
    $releaseMatch = [regex]::Match($releaseNotes, $releasePattern)
    if (-not $releaseMatch.Success) { throw "Release notes section was not found for $Tag." }
    $releaseNotesPath = Join-Path $env:TEMP "pure-live-$($Tag.TrimStart('v'))-release-notes-$PID.md"
    [IO.File]::WriteAllText(
        $releaseNotesPath,
        $releaseMatch.Value.Trim(),
        [Text.UTF8Encoding]::new($false)
    )

    $files = Get-ChildItem $ArtifactDirectory -File | ForEach-Object FullName
    if ($PSCmdlet.ShouldProcess($Tag, 'Publish GitHub release from local artifacts')) {
        $releaseList = gh release list --repo $Repository --limit 100 --json tagName | ConvertFrom-Json
        if ($LASTEXITCODE) { throw 'Failed to query existing GitHub Releases.' }
        $releaseExists = @($releaseList).tagName -contains $Tag
        if ($releaseExists) {
            gh release upload $Tag @files --clobber --repo $Repository
            if ($LASTEXITCODE) { throw 'Failed to upload GitHub Release assets.' }
            gh release edit $Tag --title "Pure Live $Tag" --notes-file $releaseNotesPath --repo $Repository
        } else {
            gh release create $Tag @files --verify-tag --title "Pure Live $Tag" --notes-file $releaseNotesPath --repo $Repository
        }
        if ($LASTEXITCODE) { throw 'Failed to create or update the GitHub Release.' }
    }
} finally {
    if ($releaseNotesPath -and (Test-Path -LiteralPath $releaseNotesPath)) {
        Remove-Item -LiteralPath $releaseNotesPath -Force
    }
    Pop-Location
}
