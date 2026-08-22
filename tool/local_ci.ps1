[CmdletBinding()]
param(
    [switch] $SkipInterfaces
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$flutterw = Join-Path $PSScriptRoot 'flutterw.ps1'
Push-Location $repoRoot
try {
    python (Join-Path $PSScriptRoot 'validate_device_ui_map.py')
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    & $flutterw pub get --enforce-lockfile
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    # Seed the verified Windows FFmpeg Native Assets archive before analyze or
    # tests invoke the package build hook. Android artifacts are fetched only
    # for an Android release build.
    & (Join-Path $PSScriptRoot 'prefetch_android_native.ps1') -SkipAndroidMedia
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    python (Join-Path $PSScriptRoot 'audit_built_in_kotlin.py')
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    # This file vendors a large JavaScript implementation in raw Dart strings;
    # dart format rewrites the embedded source and makes upstream comparison noisy.
    $formatExclusions = @('lib/core/scripts/douyin_sign.dart')
    # Keep the result strongly typed as an array. When exactly one Dart file
    # changed, PowerShell otherwise unwraps it to a scalar and argument
    # splatting passes each character to `dart format` as a separate path.
    [string[]] $dartFiles = @(
        git diff --name-only --diff-filter=ACMR HEAD -- '*.dart'
        git ls-files --others --exclude-standard -- '*.dart'
    ) | Where-Object {
        $_ -and
        $_ -notin $formatExclusions -and
        -not $_.StartsWith('plugins/built_in_kotlin/', [StringComparison]::OrdinalIgnoreCase) -and
        -not $_.StartsWith('plugins/flv_lzc/', [StringComparison]::OrdinalIgnoreCase) -and
        -not $_.StartsWith('third_party/media_kit_video/', [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $_)
    } | Sort-Object -Unique
    if ($dartFiles.Count -gt 0) {
        & $flutterw dart format --output=none --set-exit-if-changed @dartFiles
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    }

    # Dependency resolution already completed with the lockfile above. Avoid a
    # second network/Native Assets pass for every quality-gate command.
    & $flutterw analyze --no-pub --no-fatal-infos --no-fatal-warnings
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    & $flutterw test --no-pub
    if ($LASTEXITCODE) { exit $LASTEXITCODE }

    if (-not $SkipInterfaces) {
        python (Join-Path $PSScriptRoot 'interface_probe.py')
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    }
} finally {
    Pop-Location
}
