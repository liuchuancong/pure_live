<#
.tool
  audit_settings_disposition.ps1
#>
[CmdletBinding()]
param(
    [string]$Root,
    # Emit the markdown inventory instead of the console report.
    [switch]$Markdown,
    [string]$OutFile
)

if (-not $Root) { $Root = (Resolve-Path (Split-Path -Parent $PSScriptRoot)).Path }
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$appLibRel = 'apps/pure_live/lib'
$appLib = Join-Path $Root $appLibRel
$packagesRoot = Join-Path $Root 'packages'
$checklistPath = Join-Path $Root 'docs/settings-review-checklist.md'
$backupFile = Join-Path $appLib 'features/backup/document/backup_settings.dart'

$dartFiles = @(Get-ChildItem -Path $appLib -Recurse -File -Filter '*.dart' | Where-Object { -not $_.Name.EndsWith('.g.dart') })
if (Test-Path $packagesRoot) {
    $dartFiles += @(Get-ChildItem -Path $packagesRoot -Recurse -File -Filter '*.dart' |
        Where-Object { -not $_.Name.EndsWith('.g.dart') -and $_.FullName -notmatch '\\live_storage\\' })
}
$textOf = @{}
$dirOf = @{}
foreach ($f in $dartFiles) {
    $rel = $f.FullName.Substring($Root.Length + 1).Replace('\', '/')
    $textOf[$rel] = Get-Content -Raw $f.FullName
    $dirOf[$rel] = (Split-Path -Parent $f.FullName).Replace('\', '/')
}
$allRel = @($textOf.Keys)
$pkgIndex = @{}
foreach ($rel in $allRel) { if ($rel.StartsWith("$appLibRel/")) { $pkgIndex[$rel.Substring($appLibRel.Length + 1)] = $rel } }

function Shorten-Path { param($p)
    ($p -split ', ' | ForEach-Object {
        $_ -replace '^apps/pure_live/lib/', '' -replace '^packages/', 'pkg:'
    }) -join ', '
}

# ---- keys, kinds and holders, resolved the way tool/check_prefs_manifest.ps1 does ----
$methodNames = 'getString|setString|getBool|setBool|getInt|setInt|getDouble|setDouble|getStringList|setStringList|getAnyPref|setAnyPref|remove|containsKey'
$callRe = "\bStoragePrefs\s*\.\s*($methodNames)\s*\(\s*('[^']+'|[A-Za-z_]\w*|[^,\r\n)]+)"
$constRe = "\b(?:static\s+)?const\s+(?:String\s+)?(\w+)\s*=\s*'([a-zA-Z0-9_.]+)'"
$helperRe = "(?m)^\s*(?:[\w<>?,\s]+\s+)?(_?\w+)\s*\(\s*String\s+(?:key|pref|prefsName)\b"
$kindOf = { param($m) switch ($m) {
    'getString' { 'string' } 'setString' { 'string' } 'getBool' { 'bool' } 'setBool' { 'bool' }
    'getInt' { 'int' } 'setInt' { 'int' } 'getDouble' { 'double' } 'setDouble' { 'double' }
    'getStringList' { 'list' } 'setStringList' { 'list' } default { 'any' } } }

$constValues = @{}
foreach ($rel in $allRel) {
    foreach ($m in [regex]::Matches($textOf[$rel], $constRe)) {
        $n = $m.Groups[1].Value
        if (-not $constValues.ContainsKey($n)) { $constValues[$n] = [System.Collections.Generic.HashSet[string]]::new() }
        [void]$constValues[$n].Add($m.Groups[2].Value)
    }
}
$globalConsts = @{}
foreach ($e in $constValues.GetEnumerator()) { if (@($e.Value).Count -eq 1) { $globalConsts[$e.Key] = @($e.Value)[0] } }

$keyHolders = @{}
$keyKinds = @{}
$dynamicSites = [System.Collections.Generic.List[string]]::new()
function Add-Key { param($key, $rel, $kind)
    if (-not $script:keyHolders.ContainsKey($key)) {
        $script:keyHolders[$key] = [System.Collections.Generic.HashSet[string]]::new()
        $script:keyKinds[$key] = [System.Collections.Generic.HashSet[string]]::new()
    }
    [void]$script:keyHolders[$key].Add($rel)
    [void]$script:keyKinds[$key].Add($kind)
}
foreach ($rel in $allRel) {
    $text = $textOf[$rel]
    if ($text -notmatch 'StoragePrefs') { continue }
    $fileConsts = @()
    foreach ($m in [regex]::Matches($text, $constRe)) { $fileConsts += @{ Pos = $m.Index; Name = $m.Groups[1].Value; Value = $m.Groups[2].Value } }
    foreach ($m in [regex]::Matches($text, $callRe)) {
        $arg = $m.Groups[2].Value.Trim(); $key = $null
        if ($arg.StartsWith("'")) { $key = $arg.Trim("'") }
        elseif ($arg -match '^[A-Za-z_]\w*$') {
            $r = $null
            foreach ($cand in $fileConsts) { if ($cand.Name -eq $arg -and $cand.Pos -le $m.Index) { $r = $cand } }
            if ($r) { $key = $r.Value } elseif ($globalConsts.ContainsKey($arg)) { $key = $globalConsts[$arg] }
        }
        if ($key) { Add-Key $key $rel (& $kindOf $m.Groups[1].Value) } else { $dynamicSites.Add("$rel : StoragePrefs.$($m.Groups[1].Value)($arg)") }
    }
    foreach ($m in [regex]::Matches($text, $helperRe)) {
        $helper = $m.Groups[1].Value
        foreach ($call in [regex]::Matches($text, "\b$helper\s*\(\s*('[^']+'|[A-Za-z_]\w*)")) {
            $arg = $call.Groups[1].Value; $key = $null
            if ($arg.StartsWith("'")) { $key = $arg.Trim("'") }
            elseif ($globalConsts.ContainsKey($arg)) { $key = $globalConsts[$arg] }
            else { foreach ($cand in $fileConsts) { if ($cand.Name -eq $arg -and $cand.Pos -le $call.Index) { $key = $cand.Value } } }
            if ($key) { Add-Key $key $rel 'any' }
        }
    }
}

# ---- manifests the keys must appear in ----
$backupText = Get-Content -Raw $backupFile
$backedUp = [System.Collections.Generic.HashSet[string]]::new()
foreach ($m in [regex]::Matches($backupText, "\('([a-zA-Z0-9_.]+)',\s*BackupPrefKind\.\w+\)")) { [void]$backedUp.Add($m.Groups[1].Value) }
$checklistText = if (Test-Path $checklistPath) { Get-Content -Raw $checklistPath } else { '' }

# ---- settings surface: the package plus the files it directly hosts ----
$importRe = "(?m)^\s*(?:import|export)\s*'([^']+)'"
$surface = [System.Collections.Generic.HashSet[string]]::new()
$seeds = @($allRel | Where-Object { $_ -match ('^' + [regex]::Escape("$appLibRel/features/settings/")) })
foreach ($s in $seeds) { [void]$surface.Add($s) }
foreach ($s in $seeds) {
    foreach ($m in [regex]::Matches($textOf[$s], $importRe)) {
        $spec = $m.Groups[1].Value
        $target = $null
        if ($spec.StartsWith('package:pure_live/')) { $target = $pkgIndex[$spec.Substring('package:pure_live/'.Length)] }
        elseif (-not $spec.StartsWith('package:') -and -not $spec.StartsWith('dart:')) {
            $normalized = [System.IO.Path]::GetFullPath((Join-Path $dirOf[$s] $spec)).Replace('\', '/')
            foreach ($candidate in $allRel) { if ($candidate.Equals($normalized, [StringComparison]::OrdinalIgnoreCase)) { $target = $candidate; break } }
        }
        if ($target) { [void]$surface.Add($target) }
    }
}

# ---- exported symbols per file, for the one-hop reference read ----
$stop = @('if','for','while','switch','case','return','await','catch','assert','is','as','in','new','try','else','do','get','set','final','const','static','void','Future','String','int','bool','double','var','typedef','enum','class','extension','with','on','yield','throw','super','this')
$symbolsOf = @{}
foreach ($rel in $allRel) {
    $syms = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($m in [regex]::Matches($textOf[$rel], "\bfinal\s+(\w+Provider)\s*=")) { [void]$syms.Add($m.Groups[1].Value) }
    foreach ($m in [regex]::Matches($textOf[$rel], '(?m)^\s*(?:abstract\s+|final\s+|sealed\s+|base\s+)*(?:class|enum|mixin|extension)\s+([A-Z]\w+)')) { [void]$syms.Add($m.Groups[1].Value) }
    foreach ($m in [regex]::Matches($textOf[$rel], "(?m)^\s*(?:static\s+)?const\s+([a-zA-Z_]\w*)\s*=")) { [void]$syms.Add($m.Groups[1].Value) }
    foreach ($m in [regex]::Matches($textOf[$rel], '(?m)^([\w<>,?\s]{0,60}?\s)?([a-z]\w*)\s*\(')) {
        $name = $m.Groups[2].Value
        if ($stop -notcontains $name -and $name.Length -gt 3) { [void]$syms.Add($name) }
    }
    $symbolsOf[$rel] = @($syms)
}
$refCache = @{}
function Get-Referrers { param($rel)
    if ($script:refCache.ContainsKey($rel)) { return $script:refCache[$rel] }
    $syms = @($script:symbolsOf[$rel])
    $found = [System.Collections.Generic.HashSet[string]]::new()
    if ($syms.Count) {
        $re = [regex]::new('\b(' + (($syms | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b')
        foreach ($other in $script:allRel) {
            if ($other -eq $rel) { continue }
            if ($re.IsMatch($script:textOf[$other])) { [void]$found.Add($other) }
        }
    }
    $script:refCache[$rel] = @($found)
    return $found
}

$rows = foreach ($key in ($keyHolders.Keys | Sort-Object)) {
    $holders = @($keyHolders[$key])
    $refs = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($h in $holders) { foreach ($r in (Get-Referrers $h)) { [void]$refs.Add($r) } }
    $inSurface = @($refs | Where-Object { $surface.Contains($_) } | ForEach-Object { Shorten-Path $_ } | Sort-Object -Unique | Select-Object -First 3)
    $outSurface = @($refs | Where-Object { -not $surface.Contains($_) } | ForEach-Object { Shorten-Path $_ } | Sort-Object -Unique | Select-Object -First 3)
    [pscustomobject]@{
        Key = $key
        Kind = ((@($keyKinds[$key]) | Sort-Object) -join '/')
        Backup = if ($backedUp.Contains($key)) { 'Y' } else { '.' }
        Ledger = if ($checklistText.Contains($key)) { 'Y' } else { '.' }
        Holder = (Shorten-Path ($holders -join ', '))
        SettingsSide = ($inSurface -join ' ')
        BusinessSide = ($outSurface -join ' ')
    }
}

$total = @($rows).Count
$noBackup = @($rows | Where-Object { $_.Backup -eq '.' }).Count
$noLedger = @($rows | Where-Object { $_.Ledger -eq '.' }).Count

if ($Markdown) {
    # A literal here-string: inside double quotes PowerShell would read a single
    # backtick as an escape character and eat the markdown code spans.
    $head = @'
# 设置键级清单（工作区侧，阶段 A 证据）

由 `tool/audit_settings_disposition.ps1` 生成，共 @@TOTAL@@ 个 StoragePrefs 键。它回答规范 §10.3
「每项现有设置都有明确的处理结果」的**键侧**那一半：每个键的类型、是否进备份、是否在评审清单里登记、
由哪个文件读写、被设置面与业务面各自引用到什么地方。页面侧的逐项处置仍看
`docs/settings-center-restructure.md` 的分页裁定与 `docs/settings-review-checklist.md` 的行级状态。

## 口径与已知局限

- 键解析沿用 `tool/check_prefs_manifest.ps1` 的规则：字面量、同文件常量（按声明位置）、全局唯一常量、
  以 key 为形参的本地助手。拼接/派生键进文末「计算键」表，不进本表。
- 「设置面」= `features/settings/` 里的文件 **加上它直接 import 的文件**（录制页、日志面板这类由外壳页
  承载的真实控件所在文件）。按传递 import 闭包算过一次，得到 212/221 个文件，任何判定都变成恒真；
  一跳口径下 `ROW`/`APPLIED` 又双双 177/177。因此本工具**只出清单，不出门禁**——文件粒度证明不了
  「某个控件绑到某个键」，那要等 D2 把 pane 拆成每页一文件后的行粒度。
- 引用列是「持键文件导出的符号（provider / 类型 / 常量 / 顶层函数）是否出现在另一文件里」，
  是保守的可达性提示，不是调用图：命中不代表该控件真的读写这个键，**未命中**才值得人看。
- 「进备份」对照 `kBackedUpPrefs`；「清单登记」只看本工作区键名是否出现在
  `docs/settings-review-checklist.md` 文本里，共 @@NOLEDGER@@ 个未出现。抽样核实其成分见
  `docs/settings-center-restructure.md` 的「阶段 A 键侧证据补全」：多为清单用参考端旧键名描述同一行。

'@
    $head = $head.Replace('@@TOTAL@@', "$total").Replace('@@NOLEDGER@@', "$noLedger")
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append($head)
    [void]$sb.AppendLine('| 键 | 类型 | 进备份 | 清单登记 | 持键文件 | 设置面引用（≤3） | 业务面引用（≤3） |')
    [void]$sb.AppendLine('| --- | --- | --- | --- | --- | --- | --- |')
    foreach ($r in $rows) {
        $bt = [char]96
        [void]$sb.AppendLine("| $bt$($r.Key)$bt | $($r.Kind) | $($r.Backup) | $($r.Ledger) | $($r.Holder) | $($r.SettingsSide) | $($r.BusinessSide) |")
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 计算键（派生名，不能进备份清单，逐条需人工判断）')
    [void]$sb.AppendLine('')
    foreach ($d in ($dynamicSites | Sort-Object -Unique)) {
        $short = $d -replace '^apps/pure_live/lib/', ''
        [void]$sb.AppendLine("- ``$short``")
    }
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("生成时实测：$total 键 / 未进备份 $noBackup / 清单未点名 $noLedger / 设置面一跳文件 $($surface.Count) / 全树 dart $($allRel.Count)")
    $target = if ($OutFile) { $OutFile } else { Join-Path $Root 'docs/settings-key-disposition.md' }
    # No BOM: every other file under docs/ is BOM-less UTF-8.
    [System.IO.File]::WriteAllText($target, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "wrote $target"
}

Write-Host ("keys: {0} | not in kBackedUpPrefs: {1} | not named in the checklist: {2} | dynamic sites: {3}" -f $total, $noBackup, $noLedger, $dynamicSites.Count)
Write-Host 'keys not in the backup manifest:'
foreach ($r in ($rows | Where-Object { $_.Backup -eq '.' })) { Write-Host ("  {0}  [{1}]" -f $r.Key, $r.Holder) }
