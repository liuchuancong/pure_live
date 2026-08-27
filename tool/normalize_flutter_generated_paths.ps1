[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$generatedPath = Join-Path $repoRoot '.flutter-plugins-dependencies'
$mappingPath = Join-Path $repoRoot '.dart_tool\pure_live_subst_drive.txt'
if (-not (Test-Path -LiteralPath $generatedPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $mappingPath -PathType Leaf)) {
    return
}

$drive = (Get-Content -LiteralPath $mappingPath -Raw).Trim().TrimEnd('\')
if ($drive -notmatch '^[A-Za-z]:$') { return }
$repoLeaf = Split-Path -Leaf $repoRoot
$substRoot = "$drive\$repoLeaf"
$data = Get-Content -LiteralPath $generatedPath -Raw | ConvertFrom-Json
$changed = $false

foreach ($platform in $data.plugins.PSObject.Properties) {
    foreach ($plugin in @($platform.Value)) {
        $path = $plugin.path
        $normalizedPath = if ([string]::IsNullOrWhiteSpace($path)) { '' } else { $path -replace '[\\/]+', '\' }
        if ([string]::IsNullOrWhiteSpace($normalizedPath) -or
            -not $normalizedPath.StartsWith($substRoot, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $relative = $normalizedPath.Substring($substRoot.Length).TrimStart('\', '/')
        $resolved = [IO.Path]::GetFullPath((Join-Path $repoRoot $relative))
        $repoPrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $resolved)) {
            throw "Generated Flutter plugin path escaped or is missing: $path"
        }
        if ($normalizedPath.EndsWith('\') -or $normalizedPath.EndsWith('/')) { $resolved += '\' }
        $plugin.path = $resolved
        $changed = $true
    }
}

if ($changed) {
    $data | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $generatedPath -Encoding utf8 -NoNewline
    Write-Host 'Normalized generated Flutter plugin paths to the physical repository drive.'
}
