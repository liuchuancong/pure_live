# requires PowerShell 5.1+
# Module: tool/test_check_architecture.ps1
# Purpose: Regression tests for tool/check_architecture.dart using generated fixture repositories.
# Author: liuchuancong
# Created: 2026-10-08
<#
.SYNOPSIS
    Regression suite for the v2 architecture guard.

.DESCRIPTION
    Each case writes a throwaway workspace under %TEMP% and runs the guard against it with --root, so
    the rules from docs/architecture/dependency-rules.md and docs/architecture/package-architecture.md
    are proven to fire rather than assumed to. Case names follow test_<function>_<scenario>_<expected>
    as required by docs/DEVELOPMENT_STANDARDS.md section 6.

    The guard is executed with the repository's own package configuration because it parses pubspec
    files with package:yaml; the fixtures themselves only need plain files.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_check_architecture.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$guard = Join-Path $PSScriptRoot 'check_architecture.dart'
$packageConfig = Join-Path $repoRoot '.dart_tool\package_config.json'

# The guard needs a Dart VM plus the repository package configuration, so resolve the same SDK that
# tool/flutterw.ps1 would pick rather than assuming a location. Both the Windows and the POSIX
# launcher names are probed because this suite also runs on ubuntu-latest in CI.
$candidates = @($env:PURE_LIVE_DART)
$flutterCommand = @(Get-Command flutter, flutter.bat -ErrorAction SilentlyContinue) | Select-Object -First 1
if ($flutterCommand) {
    $flutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
    $candidates += (Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe')
    $candidates += (Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart')
}
foreach ($name in @('dart.exe', 'dart')) {
    $found = @(Get-Command $name -ErrorAction SilentlyContinue) | Select-Object -First 1
    if ($found) { $candidates += $found.Source }
}
$dart = @($candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) }) | Select-Object -First 1

$script:checks = 0
$script:failures = @()

function Assert-True {
    param([bool] $Condition, [AllowEmptyString()][string] $Message)
    $script:checks++
    if ($Condition) { return }
    $script:failures += $Message
    Write-Host "  FAIL $Message" -ForegroundColor Red
}

function Write-File {
    param([string] $Path, [AllowEmptyString()][string] $Content = '')
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllText($Path, ($Content -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

# ------------------------------------------------------------------- fixtures -----
function New-FixtureRepo {
    <#
    Purpose: Create an empty workspace root that the guard can read.
    Returns: the fixture directory; the caller removes it.
    #>
    $dir = Join-Path $env:TEMP ('pl_arch_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-File -Path (Join-Path $dir 'analysis_options.package.yaml') -Content "analyzer:`n  language:`n    strict-casts: true`n"
    Write-File -Path (Join-Path $dir 'pubspec.yaml') -Content "name: pure_live_workspace`npublish_to: none`nworkspace:`n"
    return $dir
}

function Add-FixtureMember {
    param([string] $Dir, [string] $Path)
    $text = [IO.File]::ReadAllText((Join-Path $Dir 'pubspec.yaml'))
    [IO.File]::WriteAllText((Join-Path $Dir 'pubspec.yaml'), $text.TrimEnd("`n") + "`n  - $Path`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Get-FixturePackageName {
    param([string] $RelPath)
    # Mirrors the scaffolder: packages/<layer>/<a>/<b> becomes pure_live_<a>_<b>.
    $segments = @(($RelPath -split '/') | Select-Object -Skip 2)
    return 'pure_live_' + ($segments -join '_')
}

function Get-FixtureInternalDirs {
    param([string] $RelPath)
    if ($RelPath -like '*/features/*') { return @('lib/src/data', 'lib/src/domain', 'lib/src/presentation') }
    if ($RelPath -like '*/providers/*') { return @('lib/src/models', 'fixtures') }
    return @('lib/src')
}

function Add-FixturePackage {
    <#
    Purpose: Write a conforming package skeleton into a fixture, with optional deviations.
    Params:  Deps - extra dependency package names; Include - analysis include override;
             Imports - Dart import lines written into lib/src/probe.dart; Omit - files to leave out.
    #>
    param(
        [string] $Dir,
        [string] $RelPath,
        [string[]] $Deps = @(),
        [string] $Include = '',
        [string[]] $Imports = @(),
        [string[]] $Omit = @()
    )
    $pkgDir = Join-Path $Dir ($RelPath -replace '/', '\')
    $packageName = Get-FixturePackageName -RelPath $RelPath

    $pubspec = @(
        "name: $packageName",
        'publish_to: none',
        'resolution: workspace',
        '',
        'environment:',
        '  sdk: ^3.13.0'
    )
    if ($Deps.Count -gt 0) {
        $depLines = @($Deps | ForEach-Object { '  ' + $_ + ':' })
        $pubspec = $pubspec + @('', 'dependencies:') + $depLines
    }
    Write-File -Path (Join-Path $pkgDir 'pubspec.yaml') -Content (($pubspec -join "`n") + "`n")

    if ($Omit -notcontains 'README.md') { Write-File -Path (Join-Path $pkgDir 'README.md') -Content "# $packageName`n" }
    if ($Omit -notcontains 'CHANGELOG.md') { Write-File -Path (Join-Path $pkgDir 'CHANGELOG.md') -Content "# Changelog`n" }
    $depth = ($RelPath -split '/').Count
    $include = if ($Include) { $Include } else { ('../' * $depth) + 'analysis_options.package.yaml' }
    if ($Omit -notcontains 'analysis_options.yaml') {
        Write-File -Path (Join-Path $pkgDir 'analysis_options.yaml') -Content "include: $include`n"
    }
    if ($Omit -notcontains 'barrel') {
        Write-File -Path (Join-Path $pkgDir "lib\$packageName.dart") -Content "library;`n"
    }
    Write-File -Path (Join-Path $pkgDir 'test\.gitkeep')
    foreach ($inner in Get-FixtureInternalDirs -RelPath $RelPath) {
        # When a real source file is written into lib/src the skeleton marker must not stay there: the guard
        # reports a .gitkeep in a populated directory as stale-scaffold-marker, and these fixtures would
        # otherwise carry a finding that has nothing to do with the rule under test.
        if ($Imports.Count -gt 0 -and $inner -eq 'lib/src') { continue }
        Write-File -Path (Join-Path $pkgDir (($inner -replace '/', '\') + '\.gitkeep'))
    }
    if ($Imports.Count -gt 0) {
        Write-File -Path (Join-Path $pkgDir 'lib\src\probe.dart') -Content (($Imports -join "`n") + "`n")
    }
}

function Add-FixtureApp {
    <#
    Purpose: Write an app member (apps/<name>) into a fixture.
    Returns: nothing; the caller registers it with Add-FixtureMember so the unregistered case can be built.
    Params:  Name - the app package name (apps carry their own name, no pure_live_ prefix); Deps - dependency
             names; Imports - lines written into lib/main.dart.
    #>
    param(
        [string] $Dir,
        [string] $Name,
        [string[]] $Deps = @(),
        [string[]] $Imports = @()
    )
    $appDir = Join-Path $Dir ('apps\' + $Name)
    $pubspec = @("name: $Name", 'publish_to: none', 'resolution: workspace', '', 'environment:', '  sdk: ^3.13.0')
    if ($Deps.Count -gt 0) {
        $pubspec = $pubspec + @('', 'dependencies:') + @($Deps | ForEach-Object { '  ' + $_ + ':' })
    }
    Write-File -Path (Join-Path $appDir 'pubspec.yaml') -Content (($pubspec -join "`n") + "`n")
    Write-File -Path (Join-Path $appDir 'lib\main.dart') -Content (($Imports -join "`n") + "`n")
}

function Invoke-Guard {
    param([string] $Dir)
    # PowerShell turns a native process' stderr into ErrorRecord objects; the guard writes diagnostics
    # there on purpose, so the preference must be relaxed while it runs and the exit code inspected.
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $dart --packages="$packageConfig" $guard --root $Dir 2>&1
        return [pscustomobject]@{ Exit = $LASTEXITCODE; Text = (($output | ForEach-Object { "$_" }) -join "`n") }
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

# ---------------------------------------------------------------------- cases -----
function test_checkarchitecture_conformingworkspace_reports_nothing {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils'
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/content'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/content' -Deps @('pure_live_utils')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 0 -and $result.Text.Contains('errors=0')) -Message "conforming workspace passes, got: $($result.Text)"
}

function test_checkarchitecture_unregisteredpackage_reports_error {
    param([string] $Dir)
    # One listed member keeps the workspace readable; the second package is the drift under test.
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/ghost'
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 1 -and $result.Text.Contains('unregistered-package')) -Message 'a package missing from workspace: is reported'
}

function test_checkarchitecture_foundationLeafDependency_isallowed {
    param([string] $Dir)
    # dependency-rules.md section 3: L0 packages do not depend on each other, except the utils and
    # logging leaves that everyone may use.
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils'
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/logging'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/logging' -Deps @('pure_live_utils')
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/cache'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/cache' -Deps @('pure_live_network')
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/network'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/network'
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition (-not $result.Text.Contains('layer-direction: pure_live_logging')) -Message 'a leaf dependency inside L0 is allowed'
    Assert-True -Condition ($result.Text.Contains('layer-direction: pure_live_cache')) -Message 'a non-leaf L0 to L0 edge is still refused'
}

function test_checkarchitecture_listedbutmissingmember_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/gone'
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('missing-package')) -Message 'a listed member without a pubspec is reported'
}

function test_checkarchitecture_upwarddependency_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils' -Deps @('pure_live_content')
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/content'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/content'
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('layer-direction') -and $result.Text.Contains('pure_live_utils')) -Message 'foundation depending on ecosystem is refused'
}

function test_checkarchitecture_approvedexception_isallowed {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/sync'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/sync' -Deps @('pure_live_firebase')
    Add-FixtureMember -Dir $Dir -Path 'packages/integrations/firebase'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/integrations/firebase'
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 0) -Message "sync -> firebase is on the exception list, got: $($result.Text)"
}

function test_checkarchitecture_runtimeExceptionEdge_isallowed {
    param([string] $Dir)
    # ADR 0017 puts the TVBox adapter on top of the Python host, which is an L1 to L0.5 edge and is
    # approved explicitly rather than by loosening the layer table.
    Add-FixtureMember -Dir $Dir -Path 'packages/integrations/python_runtime'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/integrations/python_runtime'
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/external_tvbox'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/external_tvbox' -Deps @('pure_live_python_runtime')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 0) -Message "external_tvbox -> python_runtime is whitelisted, got: $($result.Text)"
}

function test_checkarchitecture_gatewayServiceEdge_reports_nothing {
    param([string] $Dir)
    # ADR 0019: the gateway assembles ExtensionContext out of the permission and task packages. That is a
    # same-layer edge, allowed for this one package and for nothing else.
    foreach ($rel in @('packages/ecosystem/platform', 'packages/ecosystem/permission', 'packages/ecosystem/task', 'packages/ecosystem/extension')) {
        Add-FixtureMember -Dir $Dir -Path $rel
        Add-FixturePackage -Dir $Dir -RelPath $rel
    }
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/extension' -Deps @('pure_live_platform', 'pure_live_permission', 'pure_live_task')
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/permission' -Deps @('pure_live_platform')
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/task' -Deps @('pure_live_platform')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 0) -Message "extension -> permission/task is whitelisted, got: $($result.Text)"
}

function test_checkarchitecture_siblingTakingTheServiceEdge_reports_error {
    param([string] $Dir)
    # The whitelist names the gateway, not the layer: another ecosystem package reaching for permission must fail.
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/permission'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/permission'
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/content'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/content' -Deps @('pure_live_permission')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('layer-direction') -and $result.Text.Contains('pure_live_permission')) -Message 'only the gateway may take the permission edge'
}
function test_checkarchitecture_resolverCapabilityEdge_reports_nothing {
    param([string] $Dir)
    # ADR 0021: CapabilityResolver lifts a source's ResolveCapability into the platform's Resolver,
    # which needs the capability contract from the same layer.
    foreach ($rel in @('packages/ecosystem/platform', 'packages/ecosystem/capability')) {
        Add-FixtureMember -Dir $Dir -Path $rel
        Add-FixturePackage -Dir $Dir -RelPath $rel
    }
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/resolver'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/resolver' -Deps @('pure_live_platform', 'pure_live_capability')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 0) -Message "resolver -> capability is whitelisted, got: $($result.Text)"
}

function test_checkarchitecture_otherPackageTakingTheCapabilityEdge_reports_error {
    param([string] $Dir)
    # The whitelist names the resolver, not the layer: a different ecosystem package must not reach for capability.
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/platform'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/platform'
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/capability'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/capability' -Deps @('pure_live_platform')
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/extension'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/extension' -Deps @('pure_live_capability')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('layer-direction') -and $result.Text.Contains('pure_live_capability')) -Message 'only the resolver may take the capability edge'
}

function test_checkarchitecture_dependencyonapp_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/providers/bilibili'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/providers/bilibili' -Deps @('pure_live')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('depend-on-app')) -Message 'depending on the application shell is refused (I9)'
}

function test_checkarchitecture_unknownworkspacepackage_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils' -Deps @('pure_live_notthere')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('unknown-dependency')) -Message 'a dependency on a non-member is reported'
}

function test_checkarchitecture_missingrequiredfile_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils' -Omit @('CHANGELOG.md')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('missing-file') -and $result.Text.Contains('CHANGELOG.md')) -Message 'the required file set is enforced'
}

function test_checkarchitecture_analyzerincludetamper_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils' -Include '../../other.yaml'
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('analyzer-drift')) -Message 'a package that stops inheriting the shared rules is reported'
}

function test_checkarchitecture_featuresmissinglayer_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/features/live/repository'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/features/live/repository'
    Remove-Item -LiteralPath (Join-Path $Dir 'packages\features\live\repository\lib\src\presentation') -Recurse -Force
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('layout-drift') -and $result.Text.Contains('presentation')) -Message 'the features internal layout is enforced'
}

function test_checkarchitecture_stalescaffoldmarker_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils' -Imports @("import 'dart:async';")
    Write-File -Path (Join-Path $Dir 'packages\foundation\utils\lib\src\.gitkeep')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('stale-scaffold-marker') -and $result.Exit -ne 0) -Message 'a skeleton marker left in a populated directory is reported'
}

function test_checkarchitecture_featuresuiownrepository_isallowed {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/features/live/repository'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/features/live/repository'
    Add-FixtureMember -Dir $Dir -Path 'packages/features/live/live_ui'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/features/live/live_ui' -Deps @('pure_live_live_repository')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 0) -Message "a feature UI may use its own repository, got: $($result.Text)"
}

function test_checkarchitecture_windimportoutsideuikit_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils' -Imports @("import 'package:fluttersdk_wind/wind.dart';")
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('import-wind')) -Message 'only ui_kit may import fluttersdk_wind'
}

function test_checkarchitecture_providerimportingplayer_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/providers/bilibili'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/providers/bilibili' -Imports @("import 'package:media_core/media_core.dart';")
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('provider-touches-player')) -Message 'providers must not reach the player (I1 and I5)'
}

function test_checkarchitecture_rootwithoutworkspace_reports_readfailure {
    param([string] $Dir)
    Write-File -Path (Join-Path $Dir 'pubspec.yaml') -Content "name: broken`npublish_to: none`n"
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 64) -Message 'an unreadable workspace root fails with exit 64'
}

# ADR 0022 makes every app its own composition root, so the guard has to police the boundary *between*
# apps as well as the one between apps and packages. These fixtures are the reason: an app-to-app edge is
# invisible to the layer table (an app is not a layer anyone may depend on).
function test_checkarchitecture_appDependingOnAnotherApp_reports_apptoapp {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'apps/pure_live'
    Add-FixtureApp -Dir $Dir -Name 'pure_live' -Deps @('pure_bili')
    Add-FixtureMember -Dir $Dir -Path 'apps/pure_bili'
    Add-FixtureApp -Dir $Dir -Name 'pure_bili'
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 1 -and $result.Text.Contains('app-to-app: pure_live')) `
        -Message 'an app depending on another app is refused (got: ' + $result.Text + ')'
}

function test_checkarchitecture_appImportingAnotherApp_reports_appimportapp {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'apps/pure_live'
    Add-FixtureApp -Dir $Dir -Name 'pure_live' -Imports @("import 'package:pure_bili/app/runtime.dart';")
    Add-FixtureMember -Dir $Dir -Path 'apps/pure_bili'
    Add-FixtureApp -Dir $Dir -Name 'pure_bili'
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('app-import-app')) `
        -Message 'an app importing another app package is refused'
}

function test_checkarchitecture_packageDependingOnAnApp_reports_dependonapp {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'apps/pure_music'
    Add-FixtureApp -Dir $Dir -Name 'pure_music'
    Add-FixtureMember -Dir $Dir -Path 'packages/services/favorites'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/services/favorites' -Deps @('pure_music')
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('depend-on-app: pure_live_favorites')) `
        -Message 'a shared package depending on an app is refused (I9)'
}

function test_checkarchitecture_unregisteredApp_reports_error {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'apps/pure_live'
    Add-FixtureApp -Dir $Dir -Name 'pure_live'
    # apps/pure_tvbox exists on disk but the root never lists it.
    Add-FixtureApp -Dir $Dir -Name 'pure_tvbox'
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Text.Contains('unregistered-package: apps/pure_tvbox')) `
        -Message 'an app directory missing from workspace: is reported'
}

function test_checkarchitecture_appDependingOnSharedPackages_reports_nothing {
    param([string] $Dir)
    Add-FixtureMember -Dir $Dir -Path 'packages/foundation/utils'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/foundation/utils'
    Add-FixtureMember -Dir $Dir -Path 'packages/ecosystem/content'
    Add-FixturePackage -Dir $Dir -RelPath 'packages/ecosystem/content' -Deps @('pure_live_utils')
    Add-FixtureMember -Dir $Dir -Path 'apps/pure_live'
    # The composition root may reach every layer, and it imports its own package by name - neither is a
    # cross-app edge, so both must stay silent.
    Add-FixtureApp -Dir $Dir -Name 'pure_live' -Deps @('pure_live_utils', 'pure_live_content') `
        -Imports @("import 'package:pure_live/app/runtime.dart';", "import 'package:pure_live_content/content.dart';")
    $result = Invoke-Guard -Dir $Dir
    Assert-True -Condition ($result.Exit -eq 0 -and $result.Text.Contains('errors=0')) `
        -Message 'a conforming app reports nothing (got: ' + $result.Text + ')'
}

# ----------------------------------------------------------------------- runner ---
if (-not (Test-Path -LiteralPath $packageConfig)) {
    Write-Host 'SKIP: run flutter pub get first; the guard needs .dart_tool/package_config.json' -ForegroundColor Yellow
    exit 0
}
if (-not $dart) {
    Write-Host "SKIP: dart was not found at '$dart'" -ForegroundColor Yellow
    exit 0
}

Write-Host '== tool/check_architecture.dart regression =='
$cases = @((Get-ChildItem -Path 'Function:\' | Where-Object { $_.Name -like 'test_*' }).Name | Sort-Object)
Assert-True -Condition ($cases.Count -gt 8) -Message "runner discovered cases (got $($cases.Count))"
foreach ($case in $cases) {
    $before = $script:failures.Count
    $repo = New-FixtureRepo
    try {
        & $case -Dir $repo
    }
    finally {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($script:failures.Count -eq $before) { Write-Host "  ok   $case" }
    else { Write-Host "  -->  $case failed" -ForegroundColor Red }
}

Write-Host ''
if ($script:failures.Count -gt 0) {
    Write-Host "FAIL: $($script:failures.Count) of $script:checks assertions" -ForegroundColor Red
    foreach ($failure in $script:failures) { Write-Host "  - $failure" }
    exit 1
}
Write-Host "PASS: $script:checks assertions across $($cases.Count) cases"
