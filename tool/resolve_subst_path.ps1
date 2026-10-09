function Resolve-PureLiveSubstPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [string[]] $Mappings = @()
    )

    $resolved = [IO.Path]::GetFullPath($Path)
    $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    while ($true) {
        $root = [IO.Path]::GetPathRoot($resolved).TrimEnd('\')
        if (-not $visited.Add($root)) { throw "Cyclic SUBST mapping for $Path" }
        $target = @($Mappings | ForEach-Object {
            if ($_ -match "^$([Regex]::Escape($root))\\:\s*=>\s*(.+)$") {
                $Matches[1].Trim()
            }
        })
        if ($target.Count -eq 0) { return $resolved }
        if ($target.Count -ne 1) { throw "Ambiguous SUBST mapping for $root" }
        $relative = $resolved.Substring([IO.Path]::GetPathRoot($resolved).Length)
        $resolved = [IO.Path]::GetFullPath([IO.Path]::Combine($target[0], $relative))
    }
}

# After ADR 0015 moved the app to apps/pure_live, a Flutter command has to run inside that project while
# the workspace hub, the packages and the lock file stay at the repository root. The wrapper picks one
# path space for the root (physical, junction or SUBST); this maps the caller's directory into whichever
# space it chose, so a short-path fix never changes which project a command is about.
function Resolve-PureLiveProjectPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $RepoRoot,
        [Parameter(Mandatory = $true)][string] $WorkRoot,
        [Parameter(Mandatory = $true)][string] $CallerPath
    )

    $normalizedRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('')
    $normalizedCaller = [IO.Path]::GetFullPath($CallerPath).TrimEnd('')
    if ($normalizedCaller.Equals($normalizedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return $WorkRoot
    }
    $rootWithSeparator = $normalizedRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $normalizedCaller.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
        # Outside this repository (another drive, a sibling checkout): keep the previous behaviour rather
        # than inventing a project directory the caller never asked for.
        return $WorkRoot
    }
    return [IO.Path]::Combine($WorkRoot, $normalizedCaller.Substring($rootWithSeparator.Length))
}
