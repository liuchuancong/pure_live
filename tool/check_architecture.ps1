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

# The widget library behind each design-language adapter, and the core's own
# boundary. Both halves of §17 hang off this map: the core may not name any of
# these libraries, and no package other than the one listed here may import or
# depend on them. A new adapter adds one entry — every rule below then covers it
# without further editing.
$styleLibraries = [ordered]@{
    "live_uikit_cupertino_ui" = "cupertino_ui"
    "live_uikit_fluent"       = "fluent_ui"
    "live_uikit_glass"        = "glass_morphism_plus"
    "live_uikit_macos"        = "macos_ui"
    "live_uikit_material_ui"  = "material_ui"
    "live_uikit_neumorphic"   = "flutter_neumorphic_ui_kit"
    "live_uikit_wind"         = "fluttersdk_wind"
}
$styleLibraryNames = @($styleLibraries.Values)

# Each adapter imports its library under one fixed prefix (§3.3). The prefixes
# are not style: `material_ui` deliberately shadows SDK names such as `ThemeData`
# and `FilledButton`, so an unqualified import silently resolves to Flutter's own
# Material widgets and the adapter stops being that library's rendering path.
$styleLibraryAliases = @{
    "cupertino_ui"              = "cu"
    "fluent_ui"                 = "fluent"
    "glass_morphism_plus"       = "glass"
    "macos_ui"                  = "macos"
    "material_ui"               = "mu"
    "flutter_neumorphic_ui_kit" = "neu"
    "fluttersdk_wind"           = "wind"
}

# Which adapters are documented (§6/§14 of each specification) to ship a
# localization delegate. `fluent_ui`, the `material_ui` fork and the `cupertino_ui`
# fork each resolve their own localizations type, so the composition root must be
# able to append them; the other four libraries reuse Flutter's own and export
# nothing. A package that drifts from that list has a spec that now lies to the app
# author wiring it, which is the failure this guard exists to catch.
$adaptersWithLocalizationDelegates = @(
    "live_uikit_cupertino_ui",
    "live_uikit_fluent",
    "live_uikit_material_ui"
)

# The README of each adapter names its native controls in prose ("Build native …
# for: **button, card, …**"). Those words map onto `LiveUiControl` members, so the
# sentence can be checked against the capability set instead of trusted.
$controlNamesByProse = @{
    "button"     = "button"
    "card"       = "card"
    "text field" = "textField"
    "switch"     = "switchWidget"
    "checkbox"   = "checkbox"
    "slider"     = "slider"
    "segmented"  = "segmented"
    "progress"   = "progress"
    "select"     = "select"
    "tab bar"    = "tabBar"
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
            foreach ($forbidden in $styleLibraryNames) {
                if ($source -match "package:$([regex]::Escape($forbidden))/" -or $pubspec -match "(?m)^\s+$([regex]::Escape($forbidden))\s*:") {
                    $issues.Add("UI core references forbidden concrete UI dependency '$forbidden': $($file.FullName)")
                }
            }
        }

        # UI adapters must not depend on each other.
        #
        # A `<adapter>_example` package is the runnable demo of the adapter it
        # belongs to, and depending on that adapter is its entire purpose - it is
        # not a style adapter and must not be counted as one. Same exemption as
        # docs/decisions/0003.
        if ($packageName -match '^live_uikit_.+' -and $packageName -notmatch '_example$') {
            $adapters = $packageMap.Keys | Where-Object {
                $_ -match '^live_uikit_.+' -and $_ -notmatch '_example$' -and $_ -ne $packageName
            }
            foreach ($otherAdapter in $adapters) {
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

# §17: the shape of each style adapter.
#
# The loop above only knows package-to-package edges. These checks read each
# adapter the way its specification states it: exactly one widget library behind
# it, nothing but the registration API in front of it, the library reached
# through its documented prefix, and a capability set stating precisely the
# control methods the adapter overrides. Every adapter doc asks for the same four
# rules, so they are enforced once here over the map rather than per package.

function Get-SourcePackageName {
    param([string]$Path)

    $relative = $Path.Substring($Root.Length).Replace('\', '/').TrimStart('/')
    if ($relative -notmatch '^(?:packages|apps)/([^/]+)/') {
        return $null
    }
    # `<adapter>_example`, and an `example/` directory inside an adapter, is that
    # adapter's own runnable demo, so it is folded onto the adapter rather than
    # treated as a third party. Same exemption as docs/decisions/0003.
    $owner = $Matches[1]
    if ($owner -match '^(live_uikit_.+?)_example$') {
        return $Matches[1]
    }
    return $owner
}

$dartFileRoots = @($packagesRoot)
if (Test-Path (Join-Path $Root "apps")) {
    $dartFileRoots = @($packagesRoot, (Join-Path $Root "apps"))
}

# The declared edge, not just the imported one: a pubspec that names another
# adapter's library is a dependency even when no file imports it yet.
foreach ($packageName in $packageMap.Keys) {
    $owner = $packageName
    if ($owner -match '^(live_uikit_.+?)_example$') {
        $owner = $Matches[1]
    }
    $pubspecText = Get-Content -Raw (Join-Path $packageMap[$packageName] "pubspec.yaml")
    foreach ($pair in $styleLibraries.GetEnumerator()) {
        if ($owner -eq $pair.Key) {
            continue
        }
        if ($pubspecText -match "(?m)^\s*$([regex]::Escape($pair.Value))\s*:") {
            $issues.Add("Style-library boundary: '$packageName' depends on '$($pair.Value)', which only '$($pair.Key)' may use.")
        }
    }
}

$allDartFiles = @(Get-ChildItem -Path $dartFileRoots -Recurse -File -Filter "*.dart" | Where-Object {
        $_.FullName -notmatch '[\\/](build|\.dart_tool)[\\/]' -and $_.Name -notmatch '\.(g|freezed)\.dart$'
    })

foreach ($file in $allDartFiles) {
    $owner = Get-SourcePackageName -Path $file.FullName
    if (-not $owner) {
        continue
    }
    $source = Get-Content -Raw $file.FullName
    # Only real directives: a doc comment that names `package:material_ui/` is
    # documentation, not a dependency.
    foreach ($hit in [regex]::Matches($source, "(?m)^[ \t]*(?:import|export)\s+['`"]package:([a-z0-9_]+)/")) {
        $lib = $hit.Groups[1].Value
        if ($styleLibraryNames -notcontains $lib) {
            continue
        }
        if ($styleLibraries.Contains($owner) -and $styleLibraries[$owner] -eq $lib) {
            continue
        }
        $issues.Add("Style-library boundary: '$owner' uses 'package:$lib/', which only '$($styleLibraries.Keys | Where-Object { $styleLibraries[$_] -eq $lib })' may use: $($file.FullName)")
    }
}

foreach ($adapter in $styleLibraries.Keys) {
    $lib = $styleLibraries[$adapter]
    $alias = $styleLibraryAliases[$lib]
    $adapterDir = Join-Path $packagesRoot $adapter
    if (-not (Test-Path $adapterDir)) {
        continue
    }

    $adapterSources = @(Get-ChildItem -Path $adapterDir -Recurse -File -Filter "*.dart" | Where-Object {
            $_.FullName -notmatch '[\\/](build|\.dart_tool)[\\/]' -and $_.Name -notmatch '\.(g|freezed)\.dart$'
        })

    foreach ($file in $adapterSources) {
        $source = Get-Content -Raw $file.FullName
        foreach ($hit in [regex]::Matches($source, "(?m)^[ \t]*(?:import|export)\s+['`"]package:$([regex]::Escape($lib))/[^\r\n]*")) {
            if ($hit.Value -notmatch "\bas\s+$([regex]::Escape($alias))\s*;") {
                $issues.Add("'$adapter' imports '$lib' without its 'as $alias' prefix, so fork and SDK names collide: $($file.FullName)")
            }
        }
    }

    # The public barrel is the whole API: the registration file and nothing else.
    # Exporting builders or theme types would let business code construct this
    # library's widgets directly and bypass runtime style switching (§6).
    $barrelPath = Join-Path (Join-Path $adapterDir "lib") ($adapter + ".dart")
    if (-not (Test-Path $barrelPath)) {
        $issues.Add("Missing public barrel for '$adapter': $barrelPath")
    } else {
        foreach ($line in (Get-Content $barrelPath)) {
            if ($line -notmatch '^\s*(?:import|export)\s+') {
                continue
            }
            if ($line -match "^\s*export\s+['`"]package:$([regex]::Escape($adapter))/src/adapter/[a-z_]*registration\.dart['`"]\s*;\s*$") {
                continue
            }
            $issues.Add("Public barrel of '$adapter' exposes more than the registration API: $($line.Trim())")
        }
    }

    # Capability/override drift: declaring a control with no override makes the
    # resolver report `adapterNative` for a shared rendering, and overriding
    # without declaring makes the downgrade silent. Both are lies to diagnostics.
    $contractDir = Join-Path (Join-Path $adapterDir "lib") "src/adapter"
    $adapterFile = @(Get-ChildItem -Path $contractDir -File -Filter "*_adapter.dart" -ErrorAction SilentlyContinue)
    $capabilitiesFile = @(Get-ChildItem -Path $contractDir -File -Filter "*_capabilities.dart" -ErrorAction SilentlyContinue)
    if ($adapterFile.Count -ne 1 -or $capabilitiesFile.Count -ne 1) {
        $issues.Add("'$adapter' must have exactly one *_adapter.dart and one *_capabilities.dart under lib/src/adapter.")
        continue
    }

    $overrides = @(
        [regex]::Matches((Get-Content -Raw $adapterFile[0].FullName), '(?m)^\s+Widget\s+(_?[a-zA-Z]+)(?:<[^>]*>)?\s*\(') |
            ForEach-Object { $_.Groups[1].Value } |
            Where-Object { $_ -ne 'wrap' -and $_ -notmatch '^_' } |
            Sort-Object -Unique
    )
    $declared = @(
        [regex]::Matches((Get-Content -Raw $capabilitiesFile[0].FullName), 'LiveUiControl\.([a-zA-Z]+)') |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique
    )
    if ($overrides.Count -eq 0 -or $declared.Count -eq 0) {
        $issues.Add("'$adapter' declares nothing to check: $($overrides.Count) control override(s), $($declared.Count) capability entry/entries.")
        continue
    }
    foreach ($drift in (Compare-Object -ReferenceObject $overrides -DifferenceObject $declared)) {
        $where = if ($drift.SideIndicator -eq '<=') { 'overridden but not declared' } else { 'declared but not overridden' }
        $issues.Add("Capability/override drift in '$adapter': $($drift.InputObject) is $where.")
    }

    # §6/§14: the documented localization-delegate surface. A delegate that appears
    # here without the spec saying so leaves the composition root under-wired, and one
    # that disappears breaks a host that already appends it.
    $registrationFile = @(Get-ChildItem -Path $contractDir -File -Filter "*_registration.dart" -ErrorAction SilentlyContinue)
    if ($registrationFile.Count -eq 1) {
        $exportsDelegates = (Get-Content -Raw $registrationFile[0].FullName) -match 'LocalizationsDelegates'
        $shouldExport = $adaptersWithLocalizationDelegates -contains $adapter
        if ($exportsDelegates -ne $shouldExport) {
            if ($exportsDelegates) {
                $issues.Add("'$adapter' exports a localization delegate although its §14 documents none; update the spec or remove the export.")
            } else {
                $issues.Add("'$adapter' exports no localization delegate although its §14 tells the composition root to append one.")
            }
        }
    }

    # §7: the README's prose list of native controls is a claim, so compare it to the
    # capability set the resolver actually consults. This is the drift that silently
    # misleads an integrator reading only the README.
    $readmePath = Join-Path $adapterDir "README.md"
    if (Test-Path $readmePath) {
        $claimed = [System.Collections.Generic.List[string]]::new()
        foreach ($hit in [regex]::Matches((Get-Content -Raw $readmePath), '(?is)Build native[^*]*\*\*(.+?)\*\*')) {
            foreach ($word in ($hit.Groups[1].Value -split ',')) {
                $key = ($word -replace '\s+', ' ').Trim().ToLowerInvariant()
                if (-not $key) {
                    continue
                }
                if (-not $controlNamesByProse.ContainsKey($key)) {
                    $issues.Add("'$adapter' README names '$key' as native, which is not a `LiveUiControl` member.")
                    continue
                }
                $claimed.Add($controlNamesByProse[$key])
            }
        }
        if ($claimed.Count -eq 0) {
            $issues.Add("'$adapter' README states no native-control list, so the guard cannot check it against `$($adapter)Capabilities.")
        } else {
            $claimSet = @($claimed | Sort-Object -Unique)
            foreach ($docDrift in (Compare-Object -ReferenceObject $claimSet -DifferenceObject $declared)) {
                $side = if ($docDrift.SideIndicator -eq '<=') { 'listed in the README but not declared' } else { 'declared natively but missing from the README' }
                $issues.Add("'$adapter' README/capability drift: $($docDrift.InputObject) is $side.")
            }
        }
    }
}

# §4 of every uikit specification draws the package's directory tree, and the rest of
# the document is indexed off it: a tree that still names a file the package no longer
# has describes a package that does not exist, and a test the tree omits is a test no
# reader of the spec will find. Only the FIRST fenced block of §4 is the current layout
# — every specification keeps its optional, not-yet-created modules in a later block,
# and those names must stay absent on purpose.
$treeSpecs = [ordered]@{}
if ($packageMap.ContainsKey("live_uikit")) {
    $treeSpecs["live_uikit"] = Join-Path $packageMap["live_uikit"] "live-uikit.md"
}
foreach ($adapter in $styleLibraries.Keys) {
    if (-not $packageMap.ContainsKey($adapter)) {
        continue
    }
    $specPath = @(Get-ChildItem -Path $packageMap[$adapter] -File -Filter "live-uikit-*.md" -ErrorAction SilentlyContinue)
    if ($specPath.Count -ne 1) {
        $issues.Add("'$adapter' must have exactly one live-uikit-<style>.md specification to check its §4 tree against (found $($specPath.Count)).")
        continue
    }
    $treeSpecs[$adapter] = $specPath[0].FullName
}

foreach ($entry in $treeSpecs.GetEnumerator()) {
    $package = $entry.Key
    $packageDir = $packageMap[$package]
    $specPath = $entry.Value
    if (-not (Test-Path $specPath)) {
        $issues.Add("Missing specification for '$package': $specPath")
        continue
    }

    $raw = Get-Content -Raw $specPath
    $section = [regex]::Match($raw, '(?ms)^## 4\..*?(?=^## 5\.)')
    if (-not $section.Success) {
        $issues.Add("'$package' specification has no '## 4. Package directory' section.")
        continue
    }
    $fence = [regex]::Match($section.Value, '(?s)```.+?```')
    if (-not $fence.Success) {
        $issues.Add("'$package' §4 draws no fenced directory tree, so its file list cannot be checked.")
        continue
    }

    $treeNames = @(
        [regex]::Matches($fence.Value, '[A-Za-z0-9_.\-/]+\.dart') |
            ForEach-Object { $_.Value } |
            Sort-Object -Unique
    )
    $dartFiles = @(
        Get-ChildItem -Path $packageDir -Recurse -File -Filter *.dart |
            Where-Object { -not $_.FullName.Replace('\', '/').Contains('/build/') -and -not $_.FullName.Replace('\', '/').Contains('/.dart_tool/') }
    )
    $presentNames = @($dartFiles | ForEach-Object { $_.Name } | Sort-Object -Unique)

    foreach ($named in $treeNames) {
        $leaf = Split-Path $named -Leaf
        if ($presentNames -notcontains $leaf) {
            $issues.Add("Stale §4 tree in '$package': $named is drawn in the current-layout tree but no such file exists (move it to the optional-modules block or delete the line).")
        }
    }

    foreach ($testFile in ($dartFiles | Where-Object { $_.FullName.Replace('\', '/').Contains('/test/') -and $_.Name.EndsWith('_test.dart') })) {
        if ($treeNames -notcontains $testFile.Name) {
            $issues.Add("Undocumented test in '$package': $($testFile.Name) exists under test/ but §4's tree does not name it.")
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
