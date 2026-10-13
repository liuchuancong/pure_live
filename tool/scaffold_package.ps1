[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [ValidateSet("foundation", "integrations", "ecosystem", "services", "ui", "features", "providers")]
    [string]$Category,

    [Parameter(Mandatory = $true)]
    [ValidateSet("dart", "flutter")]
    [string]$Type,

    [switch]$WithCodegen,

    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

if ($Name -notmatch '^live_[a-z0-9]+(?:_[a-z0-9]+)*$') {
    throw "Invalid package name '$Name'. Expected live_lower_snake_case."
}

$packagesRoot = Join-Path $Root "packages"
$categoryRoot = Join-Path $packagesRoot $Category
$packagePath = Join-Path $categoryRoot $Name
$pubspecPath = Join-Path $packagePath "pubspec.yaml"
$rootPubspecPath = Join-Path $Root "pubspec.yaml"

if (-not (Test-Path $rootPubspecPath)) {
    throw "Root pubspec.yaml not found at '$rootPubspecPath'. Run this script from a PureLive repository."
}
if (Test-Path $packagePath) {
    throw "Destination already exists: $packagePath"
}

$rootPubspec = Get-Content -Raw $rootPubspecPath
if ($rootPubspec -match "(?m)^\s*-\s+.*(?:/|\\)$([regex]::Escape($Name))\s*$") {
    throw "A workspace entry for '$Name' may already exist. Check root pubspec.yaml."
}

New-Item -ItemType Directory -Path $packagePath -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $packagePath "lib/src") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $packagePath "test") -Force | Out-Null

$dependencies = if ($Type -eq "flutter") {
@'
dependencies:
  flutter:
    sdk: flutter
'@
} else {
@'
dependencies: {}
'@
}

$devDependencies = if ($Type -eq "flutter") {
@'
dev_dependencies:
  flutter_test:
    sdk: flutter
'@
} else {
@'
dev_dependencies:
  test: any
'@
}

if ($WithCodegen) {
    $devDependencies += @'

  build_runner: any
  freezed: any
  json_serializable: any
'@
}

$pubspec = @"
name: $Name
description: TODO: Describe the responsibility of $Name.
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.13.0
$(
    if ($Type -eq "flutter") { "  flutter: `">=3.47.0`"" } else { "" }
)

$dependencies.TrimEnd()

$devDependencies.TrimEnd()
"@

$entryFile = Join-Path $packagePath "lib/$Name.dart"
$readme = @"
# $Name

## Purpose

TODO: Describe the single responsibility of this package.

## Public API

Import the package through its public entry point:

````dart
import 'package:$Name/$Name.dart';
````

## Dependencies and boundaries

- Keep implementation details under `lib/src/`.
- Do not import another package's private `lib/src/` files.
- Document architectural exceptions in `docs/decisions/`.

## Development

Run the following commands from the workspace root:

````powershell
dart pub get
dart analyze $($packagePath.Replace($Root + [System.IO.Path]::DirectorySeparatorChar, "").Replace("\", "/"))
$(if ($Type -eq "flutter") { "flutter test $($packagePath.Replace($Root + [System.IO.Path]::DirectorySeparatorChar, "").Replace("\", "/"))" } else { "dart test $($packagePath.Replace($Root + [System.IO.Path]::DirectorySeparatorChar, "").Replace("\", "/"))" })
````
"@

$changelog = @'
# Changelog

## Unreleased

### Added

- Initial package scaffold.
'@

$analysisOptions = @'
include: ../../analysis_options.yaml
'@

if ($Category -eq "ui" -or $Type -eq "flutter") {
    $analysisOptions = @'
include: ../../analysis_options.yaml
'@
}

$testFile = Join-Path $packagePath "test/package_test.dart"
$testContent = if ($Type -eq "flutter") {
@"
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('package test scaffold is runnable', () {
    expect(true, isTrue);
  });
}
"@
} else {
@"
import 'package:test/test.dart';

void main() {
  test('package test scaffold is runnable', () {
    expect(true, isTrue);
  });
}
"@
}

Write-Utf8NoBom $pubspecPath ($pubspec.Trim() + "`n")
Write-Utf8NoBom $entryFile "library $Name;`n"
Write-Utf8NoBom (Join-Path $packagePath "README.md") ($readme.Trim() + "`n")
Write-Utf8NoBom (Join-Path $packagePath "CHANGELOG.md") ($changelog.Trim() + "`n")
Write-Utf8NoBom (Join-Path $packagePath "analysis_options.yaml") ($analysisOptions.Trim() + "`n")
Write-Utf8NoBom $testFile ($testContent.Trim() + "`n")

Write-Host "Created package scaffold: $packagePath" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Add '$($packagePath.Substring($Root.Length).TrimStart('\','/').Replace('\','/'))' to root pubspec.yaml workspace list."
Write-Host "  2. Replace TODOs and add the public API."
Write-Host "  3. Run dart pub get, formatting, analysis, and tests."
Write-Host ""
Write-Host "Note: workspace membership is intentionally not edited automatically because YAML formatting and workspace conventions vary."
