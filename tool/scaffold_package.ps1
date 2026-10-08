# requires PowerShell 5.1+
# Module: tool/scaffold_package.ps1
# Purpose: Generate layer-conformant PureLive v2 package skeletons and register them in the root pub workspace.
# Author: liuchuancong
# Created: 2026-10-08
<#
.SYNOPSIS
    PureLive v2 package scaffolder.

.DESCRIPTION
    Templates come from docs/architecture/package-architecture.md (repository layout, per-layer internal
    layout, files every package must own) and docs/architecture/dependency-rules.md (allowed dependencies
    per layer). Every emitted file uses LF and UTF-8 without BOM.

    Skeletons carry no dependencies: a dependency is a design decision and must be added explicitly when
    the wave that needs it is implemented, after checking the dependency matrix.

    Structure must not drift. To change a layout, change this template first, never an individual package.
    Comment language follows docs/DEVELOPMENT_STANDARDS.md section 4: code and config comments are English,
    while markdown documentation keeps the repository language used across docs/.

.PARAMETER Path
    Positional, "layer/short-name"; the short name may nest. Examples: foundation/utils, features/live/repository.

.PARAMETER Layer
    Alternative to Path. Must be one of the supported layers.

.PARAMETER Name
    Alternative to Path. May nest, e.g. features uses "live/repository".

.PARAMETER Description
    One-sentence package responsibility, written into README.md and pubspec.yaml. Required: the standard
    forbids placeholder text, so the tool refuses to invent one.

.PARAMETER Flutter
    The package needs the Flutter SDK (ui layer, feature UI, provider view side). Pure Dart is the default.

.PARAMETER Force
    Rewrite the scaffold-owned files (pubspec, README, CHANGELOG, analysis_options) and add missing
    directories. Never deletes hand-written code under lib/src/ or test/, and never rewrites the barrel:
    once a package exports anything the barrel is owned by the package.

.EXAMPLE
    .\tool\scaffold_package.ps1 foundation/utils -Description "Value types and dependency-free extensions"

.EXAMPLE
    .\tool\scaffold_package.ps1 features/live/repository -Flutter -Description "Live domain data and use cases"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string] $Path,
    [string] $Layer,
    [string] $Name,
    [string] $Description,
    [switch] $Flutter,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$scaffoldMark = 'GENERATED-BY: tool/scaffold_package.ps1'
$author = (& git -C $repoRoot config user.name)
if (-not $author) { $author = 'unknown' }
$created = (Get-Date).ToString('yyyy-MM-dd')

# ------------------------------------------------------------------ layer rules --
# 'Allowed' is the English summary of docs/architecture/dependency-rules.md section 3 and is what the
# barrel comment states. 'AllowedZh' is the README table wording. 'Dirs' is the internal layout of
# docs/architecture/package-architecture.md section 2.
$LayerRules = [ordered] @{
    'foundation' = @{
        Dir = 'foundation'
        Allowed = 'pub.dev packages only; foundation packages do not depend on each other (utils and logging are leaf packages).'
        AllowedZh = '仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。'
        Dirs = @('lib/src')
    }
    'integrations' = @{
        Dir = 'integrations'
        Allowed = 'layer L0 foundation; vendor SDKs may only be referenced from this layer.'
        AllowedZh = '-> L0 foundation;厂商 SDK 只允许出现在本层。'
        Dirs = @('lib/src')
    }
    'ecosystem' = @{
        Dir = 'ecosystem'
        Allowed = 'layer L0 foundation; contract and model packages are pure Dart and must not depend on Flutter.'
        AllowedZh = '-> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。'
        Dirs = @('lib/src')
    }
    'services' = @{
        Dir = 'services'
        Allowed = 'layer L0 foundation plus L1 ecosystem plugin_api.'
        AllowedZh = '-> L0 foundation + L1 ecosystem(plugin_api)。'
        Dirs = @('lib/src')
    }
    'ui' = @{
        Dir = 'ui'
        Allowed = 'design (ui_kit depends on design, one direction), L0 foundation and theme; only ui_kit may import fluttersdk_wind.'
        AllowedZh = '-> design(ui_kit -> design 单向)+ L0 + theme;只有 ui_kit 可 import fluttersdk_wind。'
        Dirs = @('lib/src')
    }
    'features' = @{
        Dir = 'features'
        Allowed = 'repository packages use L0, plugin_api and services; UI packages use their own domain repository, services, ui and ecosystem; no same-layer cycles.'
        AllowedZh = 'repository 包 -> L0 + plugin_api + services;UI 包 -> 本域 repository + services + ui + ecosystem;同层禁互依。'
        Dirs = @('lib/src/data', 'lib/src/domain', 'lib/src/presentation')
    }
    'providers' = @{
        Dir = 'providers'
        Allowed = 'L0 foundation plus L1 plugin_api through the sandbox bridge injected by the host; providers never depend on each other and never touch PlayerAdapter (invariants I1 and I5).'
        AllowedZh = '-> L0 + L1 plugin_api(经 host 注入的沙箱桥);同层禁互依;不得触碰 PlayerAdapter(I1/I5)。'
        Dirs = @('lib/src/models', 'fixtures')
    }
}

# ----------------------------------------------------------------- file writers --
function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string] $FilePath,
        [AllowEmptyString()][string] $Content = ''
    )
    $parent = Split-Path -Parent $FilePath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    # Set-Content -Encoding utf8 writes a BOM on PowerShell 5.1; pub and the analyzer do not want one.
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FilePath, ($Content -replace "`r`n", "`n"), $utf8NoBom)
}

# Templates are single-quoted here-strings with __TOKEN__ placeholders: a double-quoted here-string
# would treat backticks as escape characters and silently corrupt the generated markdown.
function Expand-Template {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $Text,
        [hashtable] $Tokens = @{}
    )
    $out = $Text
    foreach ($key in $Tokens.Keys) { $out = $out.Replace("__${key}__", [string] $Tokens[$key]) }
    $out = $out -replace "`r`n", "`n"
    if (-not $out.EndsWith("`n")) { $out += "`n" }
    $left = [regex]::Matches($out, '__[A-Z][A-Z_]*__')
    if ($left.Count -gt 0) {
        $names = @($left | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ', '
        throw "Unreplaced template placeholder: $names (check the token spelling)."
    }
    return $out
}

# -------------------------------------------------------------- input handling ---
function Resolve-Target {
    param(
        [string] $Path,
        [string] $Layer,
        [string] $Name
    )
    $resolvedLayer = $Layer
    $resolvedName = $Name
    if ($Path) {
        if ($Layer -or $Name) { throw 'Provide either Path or -Layer/-Name, not both.' }
        $segments = @($Path -split '[\\/]+' | Where-Object { $_ })
        if ($segments.Count -lt 2) { throw "Path must look like layer/short-name, got '$Path'." }
        $resolvedLayer = $segments[0]
        $resolvedName = ($segments[1..($segments.Count - 1)] -join '/')
    }
    if (-not $resolvedLayer) { throw "Missing layer. Available: $($LayerRules.Keys -join ', ')." }
    if (-not $LayerRules.Contains($resolvedLayer)) {
        throw "Unknown layer '$resolvedLayer'. Available: $($LayerRules.Keys -join ', ')."
    }
    if (-not $resolvedName) { throw "Missing package short name, e.g. $resolvedLayer/utils." }

    $shortSegments = @($resolvedName -split '/' | Where-Object { $_ })
    foreach ($segment in $shortSegments) {
        if ($segment -notmatch '^[a-z0-9_]+$') {
            throw "Invalid package name segment '$segment': only lower case letters, digits and underscores."
        }
    }
    $packageName = 'pure_live_' + ($shortSegments -join '_')
    if ($packageName -notmatch '^[a-z][a-z0-9_]{2,63}$') { throw "'$packageName' is not a valid Dart package name." }

    return [pscustomobject]@{ Layer = $resolvedLayer; PackageName = $packageName; ShortSegments = $shortSegments }
}

function Get-RootSdkConstraint {
    param([Parameter(Mandatory = $true)][string] $RootPubspec)
    if (-not (Test-Path -LiteralPath $RootPubspec)) { return '^3.13.0' }
    # Members must not drift from the workspace root constraint.
    $match = [regex]::Match((Get-Content -LiteralPath $RootPubspec -Raw), '(?m)^environment:\s*\r?\n\s+sdk:\s*(\S+)')
    if ($match.Success) { return $match.Groups[1].Value }
    return '^3.13.0'
}

# ------------------------------------------------------------------ templates ----
$pubspecTemplate = @'
# __MARK__
name: __PKG__
description: __DESCY__
publish_to: none
resolution: workspace

environment:
  sdk: __SDK__
__DEPS__
# Add dependencies from the matrix in docs/architecture/dependency-rules.md section 3.
'@

$barrelTemplate = @'
// __MARK__
// Module: lib/__PKG__.dart
// Purpose: Public barrel of __PKG__; the only import surface other packages may use.
// Author: __AUTHOR__
// Created: __CREATED__
///
/// Layer: __LAYER__. Allowed dependencies: __ALLOWED__
/// See docs/architecture/dependency-rules.md and the package README.
library;
'@

$readmeTemplate = @'
# __PKG__

> 职责:__DESC__

| 项 | 规则 |
|---|---|
| 层 | __LAYER__(见 [依赖规则](__DOCS__/architecture/dependency-rules.md)) |
| 允许依赖 | __ALLOWEDZH__ |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/__PKG__.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
__SRC_LIST__

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
'@

$changelogTemplate = @'
# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Skeleton created for layer __LAYER__ as `__PKG__`: no dependencies and no implementation yet.
'@

$analyzerTemplate = @'
# __MARK__
# Every package inherits the shared package rules from the repository root so one rule change lands
# in all packages at once. Do not add package-local lint configuration here.
include: __BASE_INCLUDE__
'@

$baseTemplate = @'
# Shared analysis_options for every package generated by tool/scaffold_package.ps1.
# Only rules that do not require a specific package may appear here; application-level rules live
# in analysis_options.yaml at the repository root.
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    always_declare_return_types: true
    avoid_print: true
    directives_ordering: true
    prefer_relative_imports: true
    unnecessary_lambdas: true
'@

# ------------------------------------------------------------------ rendering ----
function New-PackageText {
    param(
        [Parameter(Mandatory = $true)][hashtable] $Rule,
        [Parameter(Mandatory = $true)][string] $PackageName,
        [Parameter(Mandatory = $true)][string] $Layer,
        [Parameter(Mandatory = $true)][string] $Description,
        [Parameter(Mandatory = $true)][string] $SdkConstraint,
        [Parameter(Mandatory = $true)][string] $UpFromPkg,
        [bool] $UseFlutter = $false
    )
    $depsBlock = ''
    if ($UseFlutter) { $depsBlock = "`ndependencies:`n  flutter:`n    sdk: flutter`n" }
    $tokens = @{
        MARK = $scaffoldMark
        PKG = $PackageName
        LAYER = $Layer
        ALLOWED = $Rule.Allowed
        ALLOWEDZH = $Rule.AllowedZh
        DESC = $Description
        DESCY = '"' + ($Description -replace '"', '\"') + '"'
        SDK = $SdkConstraint
        DEPS = $depsBlock
        DOCS = ($UpFromPkg + 'docs')
        BASE_INCLUDE = ($UpFromPkg + 'analysis_options.package.yaml')
        SRC_LIST = (@($Rule.Dirs) | ForEach-Object { '- `' + $_ + '`' }) -join "`n"
        AUTHOR = $author
        CREATED = $created
    }
    return @{
        Pubspec = Expand-Template $pubspecTemplate $tokens
        Barrel = Expand-Template $barrelTemplate $tokens
        Readme = Expand-Template $readmeTemplate $tokens
        Changelog = Expand-Template $changelogTemplate $tokens
        Analyzer = Expand-Template $analyzerTemplate $tokens
    }
}

function Write-PackageLayout {
    param(
        [Parameter(Mandatory = $true)][string] $PkgDir,
        [Parameter(Mandatory = $true)][hashtable] $Rule,
        [Parameter(Mandatory = $true)][string] $PackageName,
        [Parameter(Mandatory = $true)][hashtable] $Text
    )
    foreach ($dir in @('lib', 'test') + @($Rule.Dirs)) {
        $full = Join-Path $PkgDir ($dir -replace '/', '\')
        if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Force -Path $full | Out-Null }
    }
    Write-TextFile -FilePath (Join-Path $PkgDir 'pubspec.yaml') -Content $Text.Pubspec
    # The barrel gains export lines the moment the package has code, so it is created once and then
    # owned by whoever writes the package; -Force must not erase those exports.
    $barrelPath = Join-Path (Join-Path $PkgDir 'lib') "$PackageName.dart"
    if (-not (Test-Path -LiteralPath $barrelPath)) {
        Write-TextFile -FilePath $barrelPath -Content $Text.Barrel
    }
    Write-TextFile -FilePath (Join-Path $PkgDir 'README.md') -Content $Text.Readme
    Write-TextFile -FilePath (Join-Path $PkgDir 'CHANGELOG.md') -Content $Text.Changelog
    Write-TextFile -FilePath (Join-Path $PkgDir 'analysis_options.yaml') -Content $Text.Analyzer
    # git does not track empty directories, so the layout keeps a marker until code lands.
    foreach ($dir in (@($Rule.Dirs) + @('test'))) {
        $keep = Join-Path (Join-Path $PkgDir ($dir -replace '/', '\')) '.gitkeep'
        if (-not (Test-Path -LiteralPath $keep)) { Write-TextFile -FilePath $keep }
    }
}

# -------------------------------------------------------- workspace registry -----
function Find-WorkspaceHeader {
    param([string[]] $Lines)
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^workspace:\s*(#.*)?$') { return $i }
    }
    return -1
}

function Insert-WorkspaceHeader {
    param([string[]] $Lines)
    $insertAt = -1
    for ($i = 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^(dependencies|dev_dependencies|dependency_overrides):') { $insertAt = $i; break }
    }
    if ($insertAt -lt 1) { throw 'Cannot find a top-level position for the workspace: key in pubspec.yaml.' }
    $block = @('# v2 monorepo members. Add a package with tool/scaffold_package.ps1.', 'workspace:', '')
    return @($Lines[0..($insertAt - 1)]) + $block + @($Lines[$insertAt..($Lines.Count - 1)])
}

function Get-WorkspaceEntry {
    param(
        [string[]] $Lines,
        [Parameter(Mandatory = $true)][int] $HeaderIndex
    )
    $entries = @()
    $i = $HeaderIndex + 1
    while ($i -lt $Lines.Count -and $Lines[$i] -match '^\s+-\s+(\S+)\s*(#.*)?$') {
        $entries += [pscustomobject]@{ Index = $i; Value = $Matches[1] }
        $i++
    }
    return $entries
}

function Add-WorkspaceMember {
    param(
        [Parameter(Mandatory = $true)][string] $RootPubspec,
        [Parameter(Mandatory = $true)][string] $Member
    )
    $lines = @(((Get-Content -LiteralPath $RootPubspec -Raw) -replace "`r`n", "`n") -split "`n")

    $headerIndex = Find-WorkspaceHeader -Lines $lines
    if ($headerIndex -lt 0) {
        $lines = @(Insert-WorkspaceHeader -Lines $lines)
        $headerIndex = Find-WorkspaceHeader -Lines $lines
    }
    $entries = @(Get-WorkspaceEntry -Lines $lines -HeaderIndex $headerIndex)
    if ($entries.Count -gt 0 -and @($entries.Value) -contains $Member) { return 'already' }

    # Insert in lexical order so the list stays readable and the diff only ever adds one line.
    $at = $headerIndex + 1
    foreach ($entry in $entries) {
        if ($entry.Value.CompareTo($Member) -gt 0) { $at = $entry.Index; break }
        $at = $entry.Index + 1
    }
    $merged = @($lines[0..($at - 1)]) + @("  - $Member") + @($lines[$at..($lines.Count - 1)])
    Write-TextFile -FilePath $RootPubspec -Content ($merged -join "`n")
    return 'added'
}

# ------------------------------------------------------------------------ main ---
if (-not $Description) {
    throw '-Description is required: the standard forbids placeholder text, so the tool will not invent a responsibility line.'
}

$target = Resolve-Target -Path $Path -Layer $Layer -Name $Name
$rule = $LayerRules[$target.Layer].Clone()
$pkgName = $target.PackageName
$pkgPathSegments = @('packages', $rule.Dir) + $target.ShortSegments
$pkgRel = $pkgPathSegments -join '/'
$pkgDir = Join-Path $repoRoot ($pkgPathSegments -join '\')
$upFromPkg = '../' * (@($pkgRel -split '/').Count)

$isRewrite = Test-Path -LiteralPath $pkgDir
if ($isRewrite -and -not $Force) {
    throw "Package directory already exists: $pkgRel (pass -Force to rewrite scaffold files)."
}

$baseTemplatePath = Join-Path $repoRoot 'analysis_options.package.yaml'
if (-not (Test-Path -LiteralPath $baseTemplatePath)) {
    Write-TextFile -FilePath $baseTemplatePath -Content (Expand-Template $baseTemplate)
    Write-Host 'Created repository root package template analysis_options.package.yaml'
}

$text = New-PackageText -Rule $rule -PackageName $pkgName -Layer $target.Layer -Description $Description `
    -SdkConstraint (Get-RootSdkConstraint -RootPubspec (Join-Path $repoRoot 'pubspec.yaml')) `
    -UpFromPkg $upFromPkg -UseFlutter ([bool] $Flutter)
Write-PackageLayout -PkgDir $pkgDir -Rule $rule -PackageName $pkgName -Text $text

$wsResult = Add-WorkspaceMember -RootPubspec (Join-Path $repoRoot 'pubspec.yaml') -Member $pkgRel

$state = 'created'
if ($isRewrite) { $state = 'rewritten' }
$kind = 'dart'
if ($Flutter) { $kind = 'flutter' }
Write-Host "$state $pkgRel -> $pkgName ($kind); workspace: $wsResult"
