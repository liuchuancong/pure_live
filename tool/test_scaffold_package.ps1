# requires PowerShell 5.1+
# Module: tool/test_scaffold_package.ps1
# Purpose: Regression tests for tool/scaffold_package.ps1: package layout, encoding, templates and workspace registration.
# Author: liuchuancong
# Created: 2026-10-08
<#
.SYNOPSIS
    Regression suite for the PureLive v2 package scaffolder.

.DESCRIPTION
    Every case runs against a throwaway repository under %TEMP% so the real working tree is never touched.
    Expectations come from docs/architecture/package-architecture.md section 2 (files every package must own
    and the per-layer internal layout), docs/architecture/dependency-rules.md section 3 (allowed dependencies)
    and docs/DEVELOPMENT_STANDARDS.md section 4 (English comments, no placeholders) and section 6 (test naming).

    Test case names follow test_<function>_<scenario>_<expected> as required by the standard.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tool/test_scaffold_package.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$toolSrc = Join-Path $PSScriptRoot 'scaffold_package.ps1'

$script:checks = 0
$script:failures = @()

# ------------------------------------------------------------------- assertions --
function Assert-True {
    param(
        [bool] $Condition,
        [AllowEmptyString()][string] $Message
    )
    $script:checks++
    if ($Condition) { return }
    $script:failures += $Message
    Write-Host "  FAIL $Message" -ForegroundColor Red
}

function Read-RepoText {
    param([string] $Path)
    return [System.IO.File]::ReadAllText($Path)
}

function Assert-TextFileQuality {
    <#
    Purpose: Assert a scaffold-owned file exists and meets the encoding and language rules of the standard.
    Params:  Path - file to inspect; Label - human readable name used in failure messages.
    Returns: nothing; failures are recorded through Assert-True.
    #>
    param([string] $Path, [string] $Label)
    if (-not (Test-Path -LiteralPath $Path)) {
        Assert-True -Condition $false -Message "$Label exists"
        return
    }
    Assert-True -Condition $true -Message "$Label exists"
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $text = Read-RepoText $Path
    Assert-True -Condition (-not $hasBom) -Message "$Label has no UTF-8 BOM"
    Assert-True -Condition (-not $text.Contains("`r")) -Message "$Label uses LF line endings"
    Assert-True -Condition (-not [regex]::IsMatch($text, '__[A-Z][A-Z_]*__')) -Message "$Label has no unreplaced placeholder"
}

# --------------------------------------------------------------------- fixtures --
function New-ScratchRepo {
    <#
    Purpose: Build an isolated repository that only contains the scaffolder and a workspace root pubspec.
    Returns: the scratch directory path; the caller removes it.
    #>
    $dir = Join-Path $env:TEMP ('pl_scaffold_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'tool') | Out-Null
    Copy-Item -LiteralPath $toolSrc -Destination (Join-Path $dir 'tool\scaffold_package.ps1')
    $rootPubspec = @'
name: pure_live_workspace
description: scratch workspace root for scaffolder tests
publish_to: none

environment:
  sdk: ^3.13.0

dependencies:
  placeholder: any
'@
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $dir 'pubspec.yaml'), ($rootPubspec -replace "`r`n", "`n"), $utf8NoBom)
    return $dir
}

function Remove-ScratchRepo {
    param([string] $Dir)
    if ($Dir -and (Test-Path -LiteralPath $Dir)) {
        Remove-Item -LiteralPath $Dir -Recurse -Force
    }
}

function Invoke-Scaffold {
    <#
    Purpose: Run the copied scaffolder inside a scratch repository.
    Params:  Dir - scratch repo; Arguments - raw argument string appended to the invocation.
    Returns: nothing; the tool reports through Write-Host which the suite discards.
    #>
    param([string] $Dir, [string] $Arguments)
    $tool = Join-Path $Dir 'tool\scaffold_package.ps1'
    Invoke-Expression ("& '$tool' $Arguments | Out-Null")
}

function Get-ScaffoldError {
    param([string] $Dir, [string] $Arguments)
    try {
        Invoke-Scaffold -Dir $Dir -Arguments $Arguments
    }
    catch {
        return $_.Exception.Message
    }
    return ''
}

function Get-WorkspaceMembers {
    param([string] $Dir)
    $text = Read-RepoText (Join-Path $Dir 'pubspec.yaml')
    $body = [regex]::Match($text, '(?m)^workspace:\r?\n(?<b>(?:^  - [^\r\n]*\r?\n)+)').Groups['b'].Value
    return @($body -split "`n" | Where-Object { $_ } | ForEach-Object { ($_ -replace '^\s*-\s*', '') })
}

# ---------------------------------------------------------------------- cases -----
function test_scaffold_newpackage_creates_required_files {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'foundation/utils -Description "Value types and extensions"'
    $pkg = Join-Path $Dir 'packages\foundation\utils'
    Assert-TextFileQuality -Path (Join-Path $pkg 'pubspec.yaml') -Label 'pubspec.yaml'
    Assert-TextFileQuality -Path (Join-Path $pkg 'lib\pure_live_utils.dart') -Label 'barrel'
    Assert-TextFileQuality -Path (Join-Path $pkg 'README.md') -Label 'README.md'
    Assert-TextFileQuality -Path (Join-Path $pkg 'CHANGELOG.md') -Label 'CHANGELOG.md'
    Assert-TextFileQuality -Path (Join-Path $pkg 'analysis_options.yaml') -Label 'analysis_options.yaml'
    # package-architecture.md section 2: foundation packages keep internals under lib/src.
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $pkg 'lib\src\.gitkeep')) -Message 'foundation package has lib/src'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $pkg 'test\.gitkeep')) -Message 'package has a test directory'
}

function test_scaffold_newpackage_writes_english_code_comments {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'foundation/utils -Description "通用值类型与扩展"'
    $barrel = Read-RepoText (Join-Path $Dir 'packages\foundation\utils\lib\pure_live_utils.dart')
    # DEVELOPMENT_STANDARDS.md section 4: comments are English even when the README keeps the repository language.
    Assert-True -Condition ($barrel.Contains('// Module: lib/pure_live_utils.dart')) -Message 'barrel carries the file header'
    Assert-True -Condition ($barrel.Contains('// Purpose:')) -Message 'barrel header states purpose'
    Assert-True -Condition ($barrel.Contains('// Author:')) -Message 'barrel header states author'
    Assert-True -Condition ($barrel.Contains('// Created:')) -Message 'barrel header states creation date'
    Assert-True -Condition ($barrel -notmatch '[一-鿿]') -Message 'barrel comments contain no CJK characters'
    $readme = Read-RepoText (Join-Path $Dir 'packages\foundation\utils\README.md')
    Assert-True -Condition ($readme.Contains('通用值类型与扩展')) -Message 'README keeps the Chinese responsibility line'
}

function test_scaffold_newpackage_registers_workspace_member {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'foundation/utils -Description "x"'
    $members = @(Get-WorkspaceMembers -Dir $Dir)
    Assert-True -Condition ($members.Count -eq 1 -and $members[0] -eq 'packages/foundation/utils') -Message 'member registered once under packages/'
    $root = Read-RepoText (Join-Path $Dir 'pubspec.yaml')
    Assert-True -Condition (([regex]::Matches($root, '(?m)^dependencies:')).Count -eq 1) -Message 'inserting the workspace key keeps other top-level keys intact'
}

function test_scaffold_existingpackage_withoutforce_throws {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'foundation/utils -Description "x"'
    $message = Get-ScaffoldError -Dir $Dir -Arguments 'foundation/utils -Description "x"'
    Assert-True -Condition ($message.Contains('already exists')) -Message ('re-scaffolding without -Force is refused, got: ' + $message)
}

function test_scaffold_force_rewrites_without_duplicate_member {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'foundation/utils -Description "x"'
    Invoke-Scaffold -Dir $Dir -Arguments 'foundation/utils -Force -Description "y"'
    $members = @(Get-WorkspaceMembers -Dir $Dir)
    Assert-True -Condition ($members.Count -eq 1) -Message 'workspace registration is idempotent'
    $readme = Read-RepoText (Join-Path $Dir 'packages\foundation\utils\README.md')
    Assert-True -Condition ($readme.Contains('y')) -Message '-Force refreshes scaffold-owned files'
}

function test_scaffold_basetemplate_existing_is_not_overwritten {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'foundation/utils -Description "x"'
    $base = Join-Path $Dir 'analysis_options.package.yaml'
    $edited = (Read-RepoText $base) + '# hand-made marker' + "`n"
    [System.IO.File]::WriteAllText($base, $edited, (New-Object System.Text.UTF8Encoding($false)))
    Invoke-Scaffold -Dir $Dir -Arguments 'ecosystem/content -Description "x"'
    Assert-True -Condition ((Read-RepoText $base).Contains('hand-made marker')) -Message 'the shared package template is never overwritten'
}

function test_scaffold_members_sorted_lexically {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'foundation/utils -Description "x"'
    Invoke-Scaffold -Dir $Dir -Arguments 'ecosystem/content -Description "x"'
    $members = @(Get-WorkspaceMembers -Dir $Dir)
    Assert-True -Condition ($members[0] -ceq 'packages/ecosystem/content' -and $members[1] -ceq 'packages/foundation/utils') -Message 'members stay in lexical order'
}

function test_scaffold_featureslayer_creates_inner_layers {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'features/live/repository -Description "x"'
    $pkg = Join-Path $Dir 'packages\features\live\repository'
    foreach ($layer in @('data', 'domain', 'presentation')) {
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $pkg "lib\src\$layer\.gitkeep")) -Message "features package has lib/src/$layer"
    }
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $pkg 'lib\pure_live_live_repository.dart')) -Message 'nested short name composes the package name'
    $analyzer = Read-RepoText (Join-Path $pkg 'analysis_options.yaml')
    Assert-True -Condition ($analyzer.Contains('include: ../../../../analysis_options.package.yaml')) -Message 'nested package computes the relative include path'
}

function test_scaffold_providerslayer_creates_models_and_fixtures {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'providers/bilibili -Description "x"'
    $pkg = Join-Path $Dir 'packages\providers\bilibili'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $pkg 'lib\src\models\.gitkeep')) -Message 'provider package has lib/src/models'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $pkg 'fixtures\.gitkeep')) -Message 'provider package has fixtures'
}

function test_scaffold_fluttervariant_adds_flutter_dependency {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'ui/ui_kit -Flutter -Description "x"'
    $pubspec = Read-RepoText (Join-Path $Dir 'packages\ui\ui_kit\pubspec.yaml')
    Assert-True -Condition ($pubspec.Contains("dependencies:`n  flutter:`n    sdk: flutter`n`n")) -Message 'Flutter variant adds the SDK dependency and keeps a blank separator'
}

function test_scaffold_puredart_default_has_no_dependency_key {
    param([string] $Dir)
    Invoke-Scaffold -Dir $Dir -Arguments 'foundation/cache -Description "x"'
    $pubspec = Read-RepoText (Join-Path $Dir 'packages\foundation\cache\pubspec.yaml')
    Assert-True -Condition (-not $pubspec.Contains("`ndependencies:")) -Message 'pure Dart skeleton declares no dependencies'
    Assert-True -Condition (-not $pubspec.Contains("`n# dependencies:")) -Message 'skeleton has no commented-out sample dependency'
}

function test_scaffold_missingdescription_throws {
    param([string] $Dir)
    $message = Get-ScaffoldError -Dir $Dir -Arguments 'foundation/utils'
    Assert-True -Condition ($message.Contains('-Description is required')) -Message ('placeholder text is refused, got: ' + $message)
}

function test_scaffold_unknownlayer_throws {
    param([string] $Dir)
    $message = Get-ScaffoldError -Dir $Dir -Arguments 'nonsense/utils -Description "x"'
    Assert-True -Condition ($message.Contains('Unknown layer')) -Message 'unknown layer is refused'
}

function test_scaffold_invalidnamesegment_throws {
    param([string] $Dir)
    $message = Get-ScaffoldError -Dir $Dir -Arguments 'foundation/Bad-Name -Description "x"'
    Assert-True -Condition ($message.Contains('Invalid package name segment')) -Message 'invalid name segment is refused'
}

function test_scaffold_pathandlayerspecified_throws {
    param([string] $Dir)
    $message = Get-ScaffoldError -Dir $Dir -Arguments '-Path foundation/x -Layer foundation -Description "x"'
    Assert-True -Condition ($message.Contains('not both')) -Message 'Path and -Layer/-Name are mutually exclusive'
}

function test_scaffold_rootwithoutdependencies_throws {
    param([string] $Dir)
    [System.IO.File]::WriteAllText(
        (Join-Path $Dir 'pubspec.yaml'),
        "name: pure_live_workspace`nenvironment:`n  sdk: ^3.13.0`n",
        (New-Object System.Text.UTF8Encoding($false)))
    $message = Get-ScaffoldError -Dir $Dir -Arguments 'foundation/utils -Description "x"'
    Assert-True -Condition ($message.Contains('Cannot find a top-level position')) -Message 'a root pubspec without an insertion point fails loudly'
}

function test_expandtemplate_unreplacedplaceholder_throws {
    param([string] $Dir)
    # The template helper is loaded straight from the tool source so a broken template cannot ship silently.
    $body = Get-TemplateFunctionSource -Name 'Expand-Template'
    Invoke-Expression $body
    $message = ''
    try { Expand-Template 'value: __BOGUS__' @{} | Out-Null } catch { $message = $_.Exception.Message }
    Assert-True -Condition ($message.Contains('Unreplaced template placeholder')) -Message 'Expand-Template rejects unreplaced placeholders'
}

function test_expandtemplate_validtoken_returnsrendered {
    param([string] $Dir)
    $body = Get-TemplateFunctionSource -Name 'Expand-Template'
    Invoke-Expression $body
    $rendered = Expand-Template 'name: __PKG__' @{ PKG = 'pure_live_x' }
    Assert-True -Condition ($rendered -eq "name: pure_live_x`n") -Message 'Expand-Template substitutes tokens and appends one newline'
}

function test_scaffold_source_parses_without_errors {
    param([string] $Dir)
    $body = Get-TemplateFunctionSource -Name 'Expand-Template'
    Assert-True -Condition ($body.Length -gt 0) -Message 'Expand-Template is locatable in the tool source'
}

function Get-TemplateFunctionSource {
    param([string] $Name)
    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($toolSrc, [ref] $tokens, [ref] $errors)
    $script:parseErrors = $errors.Count
    $found = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name
        }, $true)) | Select-Object -First 1
    if (-not $found) { return '' }
    return $found.Extent.Text
}

# ----------------------------------------------------------------------- runner ---
    Write-Host '== tool/scaffold_package.ps1 regression =='
    $cases = @((Get-ChildItem -Path 'Function:' | Where-Object { $_.Name -like 'test_*' }).Name | Sort-Object)
    Assert-True -Condition ($cases.Count -gt 5) -Message "runner discovered cases (got $($cases.Count))"
    # Each case gets its own scratch repository: cases create and mutate packages, and a shared
    # directory would make results depend on execution order.
    foreach ($case in $cases) {
        $before = $script:failures.Count
        $caseRepo = New-ScratchRepo
        try {
            & $case -Dir $caseRepo
        }
        finally {
            Remove-ScratchRepo -Dir $caseRepo
        }
        if ($script:failures.Count -eq $before) { Write-Host "  ok   $case" }
        else { Write-Host "  -->  $case failed" -ForegroundColor Red }
    }

    $parseErrors = 0
    Get-TemplateFunctionSource -Name 'Expand-Template' | Out-Null
    $parseErrors = $script:parseErrors
    Assert-True -Condition ($parseErrors -eq 0) -Message 'the scaffolder itself parses without syntax errors'

Write-Host ''
if ($script:failures.Count -gt 0) {
    Write-Host "FAIL: $($script:failures.Count) of $script:checks assertions" -ForegroundColor Red
    foreach ($failure in $script:failures) { Write-Host "  - $failure" }
    exit 1
}
Write-Host "PASS: $script:checks assertions across $($cases.Count) cases"
