# requires PowerShell 5.1+
<#
.SYNOPSIS
    PureLive v2 包脚手架:按定稿架构生成零漂移包骨架。

.DESCRIPTION
    模板来源 docs/architecture/package-architecture.md(目录形态、每类包内部模板、所有包必备文件)
    与 docs/architecture/dependency-rules.md(逐层允许依赖)。产出文件一律 LF + UTF-8 无 BOM。
    骨架不预置依赖:依赖在对应 wave 实装时按依赖矩阵手动加入(空 dependencies 键会让 pub 报错)。
    结构不得私自偏离;要偏离先改本模板(见 docs/development/package-development.md)。

.PARAMETER Path
    位置参数,`层/短名`,短名可嵌套。例:foundation/utils、features/live/repository、plugins/bilibili

.PARAMETER Layer
    与 Path 等价的拆分写法之一。

.PARAMETER Name
    与 Path 等价的拆分写法之一,可带子目录(features/live/repository)。

.PARAMETER Description
    README 与 barrel 的"职责一句话";留空写可检索占位符。

.PARAMETER Flutter
    该包需要 Flutter SDK(ui / feature UI / provider 视图侧)。默认生成纯 Dart 包。

.PARAMETER Force
    重写骨架自有文件(pubspec / README / CHANGELOG / analysis_options / barrel)并补齐缺失目录;
    不删除、不覆盖 lib/src/ 与 test/ 下的手写代码。

.EXAMPLE
    .\tool\scaffold_package.ps1 foundation/utils

.EXAMPLE
    .\tool\scaffold_package.ps1 -Layer features -Name live/repository -Flutter
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

# --------------------------------------------------------------- 层规则表 ------
# Allowed 文案逐条对齐 docs/architecture/dependency-rules.md §3;Dirs 对齐 §2 包清单
# 与 package-architecture.md §2 每类包内部模板。
$LayerRules = [ordered] @{
    'foundation'   = @{ Dir = 'foundation'; Allowed = '仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。'; Dirs = @('lib/src') }
    'integrations' = @{ Dir = 'integrations'; Allowed = '-> L0 foundation;厂商 SDK 只允许出现在本层。'; Dirs = @('lib/src') }
    'ecosystem'    = @{ Dir = 'ecosystem'; Allowed = '-> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。'; Dirs = @('lib/src') }
    'services'     = @{ Dir = 'services'; Allowed = '-> L0 foundation + L1 ecosystem(plugin_api)。'; Dirs = @('lib/src') }
    'ui'           = @{ Dir = 'ui'; Allowed = '-> design(ui_kit -> design 单向)+ L0 + theme;只有 ui_kit 可 import fluttersdk_wind。'; Dirs = @('lib/src') }
    'features'     = @{ Dir = 'features'; Allowed = 'repository 包 -> L0 + plugin_api + services;UI 包 -> 本域 repository + services + ui + ecosystem;同层禁互依。'; Dirs = @('lib/src/data', 'lib/src/domain', 'lib/src/presentation') }
    'plugins'      = @{ Dir = 'plugins'; Allowed = '-> L0 + L1 plugin_api(经 host 注入的沙箱桥);同层禁互依;不得触碰 PlayerAdapter(I1/I5)。'; Dirs = @('lib/src/models', 'fixtures') }
}

# --------------------------------------------------------------- 参数校验 ------
if ($Path) {
    if ($Layer -or $Name) { throw 'Path 与 -Layer/-Name 二选一,不要同时提供。' }
    $segments = @($Path -split '[\\/]+' | Where-Object { $_ })
    if ($segments.Count -lt 2) { throw "Path 需形如 层/短名,收到 '$Path'。" }
    $Layer = $segments[0]
    $Name = ($segments[1..($segments.Count - 1)] -join '/')
}
if (-not $Layer) { throw "缺少层名。可用:$($LayerRules.Keys -join ', ')。" }
if (-not $LayerRules.Contains($Layer)) { throw "未知层 '$Layer'。可用:$($LayerRules.Keys -join ', ')。" }
if (-not $Name) { throw "缺少包短名,例:$Layer/utils。" }

$shortSegments = @($Name -split '/' | Where-Object { $_ })
foreach ($seg in $shortSegments) {
    if ($seg -notmatch '^[a-z0-9_]+$') { throw "非法包名段 '$seg':只允许小写字母、数字、下划线。" }
}
$pkgName = 'pure_live_' + ($shortSegments -join '_')
if ($pkgName -notmatch '^[a-z][a-z0-9_]{2,63}$') { throw "包名 '$pkgName' 不是合法 Dart 包名。" }

$rule = $LayerRules[$Layer]
$pkgRel = (@($rule.Dir) + $shortSegments) -join '/'
$pkgDir = Join-Path $repoRoot ((@($rule.Dir) + $shortSegments) -join '\')
if (-not $Description) { $Description = '(待补:一句话说清职责)' }

# --------------------------------------------------------------- 写出器 --------
function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string] $FilePath,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $Content
    )
    $parent = Split-Path -Parent $FilePath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    # PS 5.1 的 Set-Content -Encoding utf8 会写 BOM;pub 与 analyzer 都不需要它。
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FilePath, ($Content -replace "`r`n", "`n"), $utf8NoBom)
}

function New-Template {
    param(
        [Parameter(Mandatory = $true)][string[]] $Lines,
        [hashtable] $Tokens = @{}
    )
    $out = foreach ($line in $Lines) {
        $t = $line
        foreach ($k in $Tokens.Keys) { $t = $t.Replace("__${k}__", [string] $Tokens[$k]) }
        $t
    }
    return ($out -join "`n") + "`n"
}

# --------------------------------------------------------------- 模板 ----------
# SDK 约束从仓库根 pubspec 继承,避免每包各写一份。
$sdkConstraint = '^3.13.0'
$rootPubspecPath = Join-Path $repoRoot 'pubspec.yaml'
if (Test-Path -LiteralPath $rootPubspecPath) {
    $rootRaw = Get-Content -LiteralPath $rootPubspecPath -Raw
    $m = [regex]::Match($rootRaw, '(?m)^environment:\s*\r?\n\s+sdk:\s*(\S+)')
    if ($m.Success) { $sdkConstraint = $m.Groups[1].Value }
}

# YAML 里 description 常含中文冒号,统一用双引号包裹。
$descYaml = '"' + ($Description -replace '"', '\"') + '"'

$pubspecLines = @(
    "# $scaffoldMark —— 结构由脚手架保证;改结构请改模板。",
    'name: __PKG__',
    'description: __DESCY__',
    'publish_to: none',
    'resolution: workspace',
    '',
    'environment:',
    '  sdk: __SDK__',
    ''
)
if ($Flutter) {
    $pubspecLines += @(
        'dependencies:',
        '  flutter:',
        '    sdk: flutter',
        ''
    )
}
$pubspecLines += @(
    '# 依赖按 docs/architecture/dependency-rules.md 的依赖矩阵在本包实装时加入。',
    '# dependencies:',
    '#',
    '# dev_dependencies:',
    '#   test: ^1.25.0'
)
$pubspec = New-Template $pubspecLines @{ PKG = $pkgName; DESCY = $descYaml; SDK = $sdkConstraint }

$barrel = New-Template @(
    "// $scaffoldMark —— 公共 API 只能经本 barrel 导出,包内实现放 lib/src/。",
    '///',
    '/// 职责:__DESC__',
    '///',
    '/// 允许依赖:__ALLOWED',
    '/// 规则见 docs/architecture/dependency-rules.md。',
    'library;'
) @{ DESC = $Description; ALLOWED = $rule.Allowed }

$srcList = ($rule.Dirs | ForEach-Object { "- ``$_``" }) -join "`n"
$readme = New-Template @(
    '# __PKG__',
    '',
    '> 职责:__DESC__',
    '',
    '| 项 | 规则 |',
    '|---|---|',
    '| 层 | __LAYER__(见 [依赖规则](__ROOT_DOCS__/architecture/dependency-rules.md)) |',
    '| 允许依赖 | __ALLOWED |',
    '| 禁止依赖 | 任何反向依赖;禁止依赖 app(唯一组合根,见 I9);同层互依(除规则明示例外) |',
    '| 公共面 | 只有 `lib/__PKG__.dart`;内部实现放 `lib/src/` |',
    '',
    '## 结构',
    '',
    '- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `test/` —— 所有包必备',
    '__SRC_LIST__',
    '',
    '## 验证',
    '',
    '- 分析:在包目录 `dart analyze`(CI 走 melos filter)',
    '- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter` 生成)',
    '',
    '## 实装待办',
    '',
    '- [ ] 补齐"职责一句话";它失效时先改文档再改代码。',
    '- [ ] 按依赖矩阵加依赖,不保留空 `dependencies:`。',
    '- [ ] 公开 API 全部经 barrel;补单测与契约测试。'
) @{
    PKG = $pkgName; DESC = $Description; LAYER = $Layer; ALLOWED = $rule.Allowed
    SRC_LIST = $srcList; ROOT_DOCS = ('../' * (@(($pkgRel -split '/')).Count)) + 'docs'
}

$changelog = New-Template @(
    '# Changelog',
    '',
    '> 版本由 melos lockstep 统一管理(见 docs/architecture/package-architecture.md §3)。',
    '',
    '## Unreleased',
    '',
    '- 骨架初始化:__LAYER__ 层 `__PKG__`,零依赖、零实现。'
) @{ LAYER = $Layer; PKG = $pkgName }

$baseInclude = ('../' * (@(($pkgRel -split '/')).Count)) + 'analysis_options.package.yaml'
$pkgAnalyzer = New-Template @(
    "# $scaffoldMark",
    '# 统一 include 仓库根包级模板,禁止各包自写规则(结构零漂移)。',
    "include: $baseInclude"
) @{}

# 包级模板:仓库根只有一份,缺失时生成,存在时不覆盖。
$baseTemplatePath = Join-Path $repoRoot 'analysis_options.package.yaml'
if (-not (Test-Path -LiteralPath $baseTemplatePath)) {
    Write-TextFile -FilePath $baseTemplatePath -Content (New-Template @(
        '# v2 包级 analysis_options 模板:tool/scaffold_package.ps1 生成的每个包都 include 本文件。',
        '# 只写不依赖具体 package 的规则;应用(组合根)侧规则见 analysis_options.yaml。',
        'analyzer:',
        '  exclude:',
        '    - "**/*.g.dart"',
        '    - "**/*.freezed.dart"',
        '  language:',
        '    strict-casts: true',
        '    strict-inference: true',
        '    strict-raw-types: true',
        '',
        'linter:',
        '  rules:',
        '    always_declare_return_types: true',
        '    avoid_print: true',
        '    directives_ordering: true',
        '    prefer_relative_imports: true',
        '    unnecessary_lambdas: true'
    ) @{})
}

# --------------------------------------------------------------- 落盘 ----------
$existingPkg = Test-Path -LiteralPath $pkgDir
if ($existingPkg -and -not $Force) {
    throw "包目录已存在: $pkgRel(要重写骨架文件请加 -Force)。"
}

foreach ($d in (@('lib', 'test') + $rule.Dirs)) {
    $full = Join-Path $pkgDir ($d -replace '/', '\')
    if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Force -Path $full | Out-Null }
}

Write-TextFile -FilePath (Join-Path $pkgDir 'pubspec.yaml') -Content $pubspec
Write-TextFile -FilePath (Join-Path (Join-Path $pkgDir 'lib') "$pkgName.dart") -Content $barrel
Write-TextFile -FilePath (Join-Path $pkgDir 'README.md') -Content $readme
Write-TextFile -FilePath (Join-Path $pkgDir 'CHANGELOG.md') -Content $changelog
Write-TextFile -FilePath (Join-Path $pkgDir 'analysis_options.yaml') -Content $pkgAnalyzer

# git 不跟踪空目录:骨架期用 .gitkeep 占位,加入真实文件后由人工删除。
foreach ($d in (@($rule.Dirs) + @('test'))) {
    $keep = Join-Path (Join-Path $pkgDir ($d -replace '/', '\')) '.gitkeep'
    if (-not (Test-Path -LiteralPath $keep)) { Write-TextFile -FilePath $keep -Content '' }
}

# -------------------------------------------------- 注册进仓库根 pub workspace --
function Add-WorkspaceMember {
    param(
        [Parameter(Mandatory = $true)][string] $RootPubspec,
        [Parameter(Mandatory = $true)][string] $Member
    )

    $text = Get-Content -LiteralPath $RootPubspec -Raw
    $lines = @(($text -replace "`r`n", "`n") -split "`n")

    $headerIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^workspace:\s*(#.*)?$') { $headerIdx = $i; break }
    }
    $created = $false
    if ($headerIdx -lt 0) {
        $insertAt = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^(dependencies|dev_dependencies|dependency_overrides):') { $insertAt = $i; break }
        }
        if ($insertAt -lt 1) { throw 'pubspec.yaml 里找不到可插入 workspace: 的顶层位置。' }
        $block = @(
            '# v2 单仓多包:pub workspace(与 melos 兼容)。新增包请用 tool/scaffold_package.ps1。',
            'workspace:',
            ''
        )
        $lines = @($lines[0..($insertAt - 1)]) + $block + @($lines[$insertAt..($lines.Count - 1)])
        $headerIdx = $insertAt + 1
        $created = $true
    }

    # 表头之后的连续列表项即成员;注释与空行视为块结束。
    $entryRows = @()
    $i = $headerIdx + 1
    while ($i -lt $lines.Count -and $lines[$i] -match '^\s*-\s*(\S+)\s*(#.*)?$') {
        $entryRows += [pscustomobject]@{ Idx = $i; Value = $Matches[1] }
        $i++
    }
    if ($entryRows.Value -contains $Member) {
        return 'already'
    }

    $at = $headerIdx + 1
    foreach ($e in $entryRows) {
        if ($e.Value.CompareTo($Member) -gt 0) { $at = $e.Idx; break }
        $at = $e.Idx + 1
    }
    $lines = @($lines[0..($at - 1)]) + @("  - $Member") + @($lines[$at..($lines.Count - 1)])
    Write-TextFile -FilePath $RootPubspec -Content (($lines -join "`n"))
    if ($created) { return 'created' }
    return 'added'
}

$wsResult = Add-WorkspaceMember -RootPubspec $rootPubspecPath -Member $pkgRel

$state = if ($existingPkg) { '重写骨架' } else { '新建' }
$kind = if ($Flutter) { 'Flutter' } else { '纯 Dart' }
Write-Host "$state $pkgRel -> $pkgName ($kind);workspace: $wsResult"
