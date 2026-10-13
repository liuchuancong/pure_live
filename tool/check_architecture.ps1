[CmdletBinding()]
param(
    # Resolved below rather than in the default value: $PSScriptRoot is still
    # empty while a param block is evaluated under Windows PowerShell.
    [string]$Root
)

if (-not $Root) {
    $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$issues = [System.Collections.Generic.List[string]]::new()
$packagesRoot = Join-Path $Root "packages"

if (-not (Test-Path $packagesRoot)) {
    throw "Packages directory not found: $packagesRoot"
}

$packageFiles = Get-ChildItem -Path $packagesRoot -Recurse -File -Filter "pubspec.yaml"
$packageMap = @{}

foreach ($file in $packageFiles) {
    $yaml = Get-Content -Raw $file.FullName
    if ($yaml -match '(?m)^name:\s*([a-z0-9_]+)\s*$') {
        $packageMap[$Matches[1]] = $file.Directory.FullName
    }
}

foreach ($packageName in $packageMap.Keys) {
    $packagePath = $packageMap[$packageName]
    $libPath = Join-Path $packagePath "lib"
    $pubspec = Get-Content -Raw (Join-Path $packagePath "pubspec.yaml")

    if (-not (Test-Path $libPath)) {
        continue
    }

    $dartFiles = Get-ChildItem -Path $libPath -Recurse -File -Filter "*.dart"
    foreach ($file in $dartFiles) {
        $source = Get-Content -Raw $file.FullName

        # UI core must not depend on concrete style libraries.
        if ($packageName -eq "live_uikit") {
            foreach ($forbidden in @(
                "fluent_ui",
                "macos_ui",
                "flutter_neumorphic_ui_kit",
                "glass_morphism_plus",
                "fluttersdk_wind"
            )) {
                if ($source -match "package:$([regex]::Escape($forbidden))/" -or $pubspec -match "(?m)^\s+$([regex]::Escape($forbidden))\s*:") {
                    $issues.Add("UI core references forbidden concrete UI dependency '$forbidden': $($file.FullName)")
                }
            }
        }

        # UI adapters must not depend on each other.
        if ($packageName -match '^live_uikit_.+') {
            foreach ($otherAdapter in $packageMap.Keys | Where-Object { $_ -match '^live_uikit_.+' -and $_ -ne $packageName }) {
                if ($source -match "package:$([regex]::Escape($otherAdapter))/" -or $pubspec -match "(?m)^\s+$([regex]::Escape($otherAdapter))\s*:") {
                    $issues.Add("UI adapter '$packageName' depends on another adapter '$otherAdapter'.")
                }
            }
        }

        # Warn about package imports into another package's private src path.
        if ($source -match "package:([a-z0-9_]+)/src/") {
            $targetPackage = $Matches[1]
            if ($packageMap.ContainsKey($targetPackage) -and $targetPackage -ne $packageName) {
                $issues.Add("Cross-package private import: '$packageName' imports '$targetPackage/src' in $($file.FullName)")
            }
        }
    }
}

if ($issues.Count -gt 0) {
    Write-Host "Architecture checks failed:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host " - $issue" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Architecture checks passed." -ForegroundColor Green
