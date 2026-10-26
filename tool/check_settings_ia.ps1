# Settings-center information-architecture gate.
#
# The settings surface is one registry (SettingsSection), one module menu
# (kModuleNavigation), one pane dispatch (the switch in settings_page.dart)
# and one hand-maintained search catalogue. Those four are the same fact
# written four times, so they drift as soon as a row is added to the wrong
# page or a search hit keeps pointing at an old section. This gate re-derives
# all four from source and fails when they disagree.
#
# Parsing is lightweight text matching, like the other gates here: a rule it
# cannot see is a rule it will not report.
#
# One check is deliberately weaker than it looks. A search hit's row is only
# confirmed to exist somewhere in the files its pane reaches, not on that pane
# exactly: while the private panes share settings_page.dart, that file imports
# the whole settings surface, so a hit re-hung on the wrong page still finds
# its label. It does catch a hit whose label disappeared. Extracting each pane
# into its own file (docs/settings-center-restructure.md, step D2) narrows the
# reach to the page and turns this into a real attribution gate.

param(
    # Defaults to the repository; pass a copy of the tree to prove a check bites.
    [string]$Root
)

$ErrorActionPreference = 'Stop'

function Get-SwitchMap {
    <#  Parses `SettingsSection.a || SettingsSection.b => SettingsSection.c,` runs
        (the alias/parent getters) into a source -> target map. #>
    param([string]$Block)
    $map = [ordered]@{}
    foreach ($match in [regex]::Matches($Block, '(?s)(.*?)=> SettingsSection\.(\w+),')) {
        $sources = [regex]::Matches($match.Groups[1].Value, 'SettingsSection\.(\w+)') | ForEach-Object { $_.Groups[1].Value }
        if (-not $sources) { continue }
        foreach ($source in $sources) { $map[$source] = $match.Groups[2].Value }
    }
    return $map
}

function Get-EnumValues {
    param([string]$Block)
    return @([regex]::Matches($Block, '(?m)^  (\w+)\(') | ForEach-Object { $_.Groups[1].Value })
}

function Get-ClassIndex {
    <#  One pass over the app sources: class name -> the file that declares it. #>
    param([string]$Lib)
    $index = @{}
    foreach ($file in (Get-ChildItem -Path $Lib -Recurse -Filter '*.dart' |
            Where-Object { $_.Name -notlike '*.g.dart' -and $_.FullName -notlike '*\l10n\*' })) {
        foreach ($match in [regex]::Matches((Get-Content -Raw -LiteralPath $file.FullName), '(?m)^(?:abstract\s+|final\s+|sealed\s+|base\s+)*class\s+(\w+)')) {
            if (-not $index.Contains($match.Groups[1].Value)) { $index[$match.Groups[1].Value] = $file.FullName }
        }
    }
    return $index
}

function Resolve-ClassFile {
    param([string]$ClassName, [hashtable]$ClassIndex)
    if ($ClassIndex.Contains($ClassName)) { return $ClassIndex[$ClassName] }
    return $null
}

function Get-ReachableFiles {
    <#  The pane's own file plus the files it imports, three levels deep: a row
        can be built by a widget that lives in a helper file. #>
    param([string]$Entry, [string]$Lib, [int]$Depth = 3)
    $seen = [ordered]@{}
    $queue = New-Object System.Collections.Queue
    $queue.Enqueue(@{ Path = $Entry; Level = 0 })
    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        if ($seen.Contains($item.Path) -or $item.Level -gt $Depth) { continue }
        $seen[$item.Path] = $true
        if ($item.Level -eq $Depth) { continue }
        $source = Get-Content -Raw -LiteralPath $item.Path
        foreach ($match in [regex]::Matches($source, "(?:import|export) '(?:(package:pure_live/)|)([^']*\.dart)'")) {
            $relative = $match.Groups[2].Value -replace '^lib/', ''
            $candidate = if ($match.Groups[1].Success) {
                Join-Path $Lib ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
            } else {
                Join-Path (Split-Path -Parent $item.Path) ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
            }
            if (Test-Path -LiteralPath $candidate) { $queue.Enqueue(@{ Path = $candidate; Level = $item.Level + 1 }) }
        }
    }
    return @($seen.Keys)
}

$root = if ($Root) { $Root } elseif ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
$lib = Join-Path $root 'apps/pure_live/lib'
$sectionsPath = Join-Path $lib 'features/settings/surface/settings_sections.dart'
$navPath = Join-Path $lib 'app/navigation/module_navigation.dart'
$pagePath = Join-Path $lib 'features/settings/surface/settings_page.dart'
$searchPath = Join-Path $lib 'features/settings/surface/settings_search.dart'

foreach ($path in @($sectionsPath, $navPath, $pagePath, $searchPath)) {
    if (-not (Test-Path -LiteralPath $path)) { Write-Error "settings IA gate: missing $path" }
}

$sections = Get-Content -Raw -LiteralPath $sectionsPath
$nav = Get-Content -Raw -LiteralPath $navPath
$page = Get-Content -Raw -LiteralPath $pagePath
$search = Get-Content -Raw -LiteralPath $searchPath

$failures = [System.Collections.Generic.List[string]]::new()

# --- the registry ---------------------------------------------------------
$enumBlockMatch = [regex]::Match($sections, '(?s)enum SettingsSection \{(.*?)\r?\n\r?\n  SettingsSection\(this\.icon\)')
if (-not $enumBlockMatch.Success) { Write-Error 'settings IA gate: the SettingsSection enum no longer parses' }
$values = @(Get-EnumValues $enumBlockMatch.Groups[1].Value)

$aliasMatch = [regex]::Match($sections, '(?s)SettingsSection\? get aliasTarget => switch \(this\) \{(.*?)\r?\n  \};')
$parentMatch = [regex]::Match($sections, '(?s)SettingsSection\? get parentSection => switch \(this\) \{(.*?)\r?\n  \};')
if (-not $aliasMatch.Success -or -not $parentMatch.Success) { Write-Error 'settings IA gate: aliasTarget/parentSection no longer parses' }
$aliases = Get-SwitchMap $aliasMatch.Groups[1].Value
$parents = Get-SwitchMap $parentMatch.Groups[1].Value

# childrenOf is `Section.a => const [ ... ],` — the parents' side of $parents.
$childrenOf = [ordered]@{}
foreach ($child in $parents.Keys) {
    $parent = $parents[$child]
    if (-not $childrenOf.Contains($parent)) { $childrenOf[$parent] = [System.Collections.Generic.List[string]]::new() }
    $childrenOf[$parent].Add($child)
}
$childSource = [regex]::Match($sections, '(?s)List<SettingsSection> settingsChildrenOf\(SettingsSection category\) => switch \(category\) \{(.*?)\r?\n\};')
if (-not $childSource.Success) { Write-Error 'settings IA gate: settingsChildrenOf no longer parses' }
foreach ($match in [regex]::Matches($childSource.Groups[1].Value, '(?s)SettingsSection\.(\w+) => const \[(.*?)\],')) {
    $list = [regex]::Matches($match.Groups[2].Value, 'SettingsSection\.(\w+)') | ForEach-Object { $_.Groups[1].Value }
    if ($list) {
        if (-not $childrenOf.Contains($match.Groups[1].Value)) { $childrenOf[$match.Groups[1].Value] = [System.Collections.Generic.List[string]]::new() }
        foreach ($item in $list) { if (-not $childrenOf[$match.Groups[1].Value].Contains($item)) { $childrenOf[$match.Groups[1].Value].Add($item) } }
    }
}

$rows = @([regex]::Matches($nav, 'SettingsSection\.(\w+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
$subpages = @($parents.Keys)
$real = @($values | Where-Object { $aliases.Keys -notcontains $_ })

# --- partition: every value is a row, a subpage, or an alias --------------
foreach ($orphan in @($real | Where-Object { $rows -notcontains $_ -and $subpages -notcontains $_ })) {
    $failures.Add("real page '$orphan' is neither a sidebar row nor a subpage (unreachable)")
}
foreach ($row in $rows) {
    if ($values -notcontains $row) { $failures.Add("module registry names '$row', which is not a SettingsSection") }
    if ($aliases.Contains($row)) { $failures.Add("'$row' is both a sidebar row and a deep-link alias — two truths for one link") }
}
foreach ($entry in $aliases.GetEnumerator()) {
    if ($aliases.Contains($entry.Value)) { $failures.Add("alias '$($entry.Key)' resolves to '$($entry.Value)', itself an alias") }
    if ($real -notcontains $entry.Value) { $failures.Add("alias '$($entry.Key)' resolves to '$($entry.Value)', which is not a real page") }
    if ($subpages -contains $entry.Key) { $failures.Add("'$($entry.Key)' is both a subpage and an alias") }
}
foreach ($entry in $parents.GetEnumerator()) {
    $parent = $entry.Value
    if ($rows -notcontains $parent) { $failures.Add("subpage '$($entry.Key)' hangs off '$parent', which the menu does not list") }
    if (-not $childrenOf.Contains($parent) -or -not $childrenOf[$parent].Contains($entry.Key)) {
        $failures.Add("subpage '$($entry.Key)' names parent '$parent', but settingsChildrenOf('$parent') omits it")
    }
}
foreach ($entry in $childrenOf.GetEnumerator()) {
    foreach ($child in $entry.Value) {
        if ($parents.Contains($child) -and $parents[$child] -ne $entry.Key) { $failures.Add("settingsChildrenOf lists '$child' under '$($entry.Key)' but its parentSection is '$($parents[$child])'") }
        if ($aliases.Contains($child)) { $failures.Add("settingsChildrenOf('$($entry.Key)') lists the alias '$child'") }
        if ($subpages -contains $entry.Key) {
            $failures.Add("'$child' nests under '$($entry.Key)', which is itself a subpage (three pages deep)")
        }
    }
}

# --- the pane dispatch ----------------------------------------------------
$dispatchMatch = [regex]::Match($page, '(?s)final body = switch \(section\) \{(.*?)\r?\n    \};')
if (-not $dispatchMatch.Success) { Write-Error 'settings IA gate: the pane dispatch in settings_page.dart no longer parses' }
$dispatch = [ordered]@{}
$pending = [System.Collections.Generic.List[string]]::new()
foreach ($line in ($dispatchMatch.Groups[1].Value -split "\r?\n")) {
    $arrow = $line.IndexOf('=>')
    if ($arrow -lt 0) {
        foreach ($match in [regex]::Matches($line, 'SettingsSection\.(\w+)')) { $pending.Add($match.Groups[1].Value) }
        continue
    }
    $pane = [regex]::Match($line.Substring($arrow), '=> (?:const )?([A-Za-z_]+)\(').Groups[1].Value
    if (-not $pane) { continue }
    $named = @([regex]::Matches($line.Substring(0, $arrow), 'SettingsSection\.(\w+)') | ForEach-Object { $_.Groups[1].Value })
    foreach ($sectionName in @($pending) + $named) { $dispatch[$sectionName] = $pane }
    $pending.Clear()
}
foreach ($value in $values) {
    if (-not $dispatch.Contains($value)) { $failures.Add("'$value' has no pane case") }
}
foreach ($entry in $aliases.GetEnumerator()) {
    if ($dispatch.Contains($entry.Key) -and $dispatch.Contains($entry.Value) -and $dispatch[$entry.Key] -ne $dispatch[$entry.Value]) {
        $failures.Add("alias '$($entry.Key)' renders $($dispatch[$entry.Key]) but its canonical page renders $($dispatch[$entry.Value])")
    }
}

# --- every subpage is opened from its parent's pane ------------------------
$classIndex = Get-ClassIndex $lib
foreach ($entry in $parents.GetEnumerator()) {
    $child = $entry.Key
    $parent = $entry.Value
    $paneFile = Resolve-ClassFile $dispatch[$parent] $classIndex
    if (-not $paneFile) { $failures.Add("pane '$($dispatch[$parent])' for '$parent' was not found in the app"); continue }
    $sources = Get-ReachableFiles $paneFile $lib
    $opens = $false
    foreach ($file in $sources) {
        $body = Get-Content -Raw -LiteralPath $file
        if ($body -match "SettingsChildEntry\([\s\S]{0,200}?SettingsSection\.$child\b" -or $body -match "openSettingsChild\([\s\S]{0,120}?SettingsSection\.$child\b" -or $body -match "settingsChildrenOf\(SettingsSection\.$parent\)") { $opens = $true; break }
    }
    if (-not $opens) { $failures.Add("subpage '$child' is never opened from its parent pane ($((Split-Path -Leaf $paneFile)))") }
}

# --- the search catalogue --------------------------------------------------
$hits = @([regex]::Matches($search, '_hit\(\s*SettingsSection\.(\w+),\s*([A-Za-z_.]+)') | ForEach-Object {
        @{ Section = $_.Groups[1].Value; Key = (@($_.Groups[2].Value -split '\.')[-1]) }
    })
$declared = [regex]::Matches($search, '_hit\(').Count - 1   # one occurrence is the helper's own declaration
if ($hits.Count -ne $declared) { Write-Error "settings IA gate: parsed $($hits.Count) of $declared search hits — fix the parser before trusting this run" }

$hitSections = @($hits | ForEach-Object { $_.Section } | Select-Object -Unique)
foreach ($sectionName in $hitSections) {
    if ($aliases.Contains($sectionName)) { $failures.Add("a search hit points at the alias '$sectionName'; hits must name the page that carries the row") }
    elseif ($real -notcontains $sectionName) { $failures.Add("a search hit points at '$sectionName', which is not a SettingsSection") }
}
$openable = @($rows + $subpages)
foreach ($sectionName in @($hitSections | Where-Object { $openable -notcontains $_ })) {
    $failures.Add("search section '$sectionName' is in no module menu, so no search result can open it")
}
foreach ($sectionName in @($real | Where-Object { $hitSections -notcontains $_ })) {
    $failures.Add("page '$sectionName' has no search hit")
}
$paneBlobs = @{}
foreach ($hit in $hits) {
    if ($aliases.Contains($hit.Section) -or -not $dispatch.Contains($hit.Section)) { continue }
    $pane = $dispatch[$hit.Section]
    if (-not $paneBlobs.Contains($pane)) {
        $paneFile = Resolve-ClassFile $pane $classIndex
        $blob = ''
        if ($paneFile) {
            foreach ($file in (Get-ReachableFiles $paneFile $lib)) { $blob += (Get-Content -Raw -LiteralPath $file) }
        }
        $paneBlobs[$pane] = $blob
    }
    if ($paneBlobs[$pane] -and $paneBlobs[$pane] -notmatch "[.\s<(]$($hit.Key)\b") {
        $failures.Add("search hit '$($hit.Key)' opens '$($hit.Section)' ($pane), but no file that page renders mentions that label")
    }
}

# --- report ---------------------------------------------------------------
Write-Host ("settings IA: {0} sections ({1} pages, {2} aliases), {3} sidebar rows, {4} subpages, {5} pane cases, {6} search hits" -f `
        $values.Count, $real.Count, $aliases.Count, $rows.Count, $subpages.Count, $dispatch.Count, $hits.Count)

if ($failures.Count) {
    Write-Host ''
    Write-Host "SETTINGS IA GATE FAILED ($($failures.Count)):"
    foreach ($failure in ($failures | Select-Object -Unique)) { Write-Host " - $failure" }
    exit 1
}
Write-Host 'settings IA gate passed.'
