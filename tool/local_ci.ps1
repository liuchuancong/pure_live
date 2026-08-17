[CmdletBinding()]
param(
    [switch] $SkipInterfaces
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterw = Join-Path $PSScriptRoot 'flutterw.ps1'
Push-Location $repoRoot
try {
    & $flutterw pub get --enforce-lockfile
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    python (Join-Path $PSScriptRoot 'audit_built_in_kotlin.py')
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    # This file vendors a large JavaScript implementation in raw Dart strings;
    # dart format rewrites the embedded source and makes upstream comparison noisy.
    $formatExclusions = @('lib/core/scripts/douyin_sign.dart')
    $dartFiles = @(
        git diff --name-only --diff-filter=ACMR HEAD -- '*.dart'
        git ls-files --others --exclude-standard -- '*.dart'
    ) | Where-Object {
        $_ -and
        $_ -notin $formatExclusions -and
        -not $_.StartsWith('plugins/built_in_kotlin/', [StringComparison]::OrdinalIgnoreCase) -and
        -not $_.StartsWith('plugins/flv_lzc/', [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $_)
    } | Sort-Object -Unique
    if ($dartFiles.Count -gt 0) {
        & $flutterw dart format --output=none --set-exit-if-changed @dartFiles
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    }

    & $flutterw analyze --no-fatal-infos --no-fatal-warnings
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    & $flutterw test
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    if (-not $SkipInterfaces) {
        python (Join-Path $PSScriptRoot 'interface_probe.py')
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    }
} finally {
    Pop-Location
}
