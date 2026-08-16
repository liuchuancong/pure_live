[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)] [string] $Tag,
    [string] $ArtifactDirectory,
    [switch] $CreateTag,
    [switch] $AllowQaArtifacts
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
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
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    $headCommit = (git rev-parse HEAD).Trim()
    if ($metadata.source_commit -ne $headCommit -or $metadata.tracked_files_dirty) {
        throw 'Artifacts were not built from the current clean commit; rebuild them after committing.'
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
    $files = Get-ChildItem $ArtifactDirectory -File | ForEach-Object FullName
    if ($PSCmdlet.ShouldProcess($Tag, 'Publish GitHub release from local artifacts')) {
        $releaseList = gh release list --repo wzgrx/pure_live --limit 100 --json tagName | ConvertFrom-Json
        if ($LASTEXITCODE) { throw 'Failed to query existing GitHub Releases.' }
        $releaseExists = @($releaseList).tagName -contains $Tag
        if ($releaseExists) {
            gh release upload $Tag @files --clobber --repo wzgrx/pure_live
        } else {
            gh release create $Tag @files --verify-tag --title "Pure Live $Tag" --notes-file RELEASE_NOTES.md --repo wzgrx/pure_live
        }
    }
} finally {
    Pop-Location
}
