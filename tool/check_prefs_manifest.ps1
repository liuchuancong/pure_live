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

# The settings manifests are hand-maintained lists beside code that already
# knows the answer: kBackedUpPrefs names the keys a backup carries and the kind
# each side speaks, and kSettingsProviders names the controllers a window
# rebuilds when values change underneath it. Both drift the moment a surface
# adds a pref. This gate re-derives the truth from the call sites and fails on
# the difference, so a new setting is only finished once both manifests know
# it.
$appLib = Join-Path $Root "apps/pure_live/lib"
$packagesRoot = Join-Path $Root "packages"
$backupFile = Join-Path $appLib "features/backup/backup_settings.dart"
$refreshFile = Join-Path $appLib "app/providers/settings_refresh.dart"

foreach ($required in @($appLib, $backupFile, $refreshFile)) {
    if (-not (Test-Path $required)) {
        throw "Required path not found: $required"
    }
}

# StoragePrefs is the app layer's facade; a package that reads it directly
# owns keys no settings page can be held accountable for, so the packages are
# scanned too and any call site there is reported.
$dartFiles = @(Get-ChildItem -Path $appLib -Recurse -File -Filter "*.dart" |
    Where-Object { -not $_.Name.EndsWith(".g.dart") })
if (Test-Path $packagesRoot) {
    $dartFiles += @(Get-ChildItem -Path $packagesRoot -Recurse -File -Filter "*.dart" |
        Where-Object { -not $_.Name.EndsWith(".g.dart") -and $_.FullName -notmatch "\\live_storage\\" })
}

$kindOf = {
    param($method)
    switch ($method) {
        "getString" { "string" }
        "setString" { "string" }
        "getBool" { "boolean" }
        "setBool" { "boolean" }
        "getInt" { "integer" }
        "setInt" { "integer" }
        "getDouble" { "floating" }
        "setDouble" { "floating" }
        "getStringList" { "stringList" }
        "setStringList" { "stringList" }
        default { "any" }
    }
}

$methodNames = "getString|setString|getBool|setBool|getInt|setInt|getDouble|setDouble|getStringList|setStringList|getAnyPref|setAnyPref|remove|containsKey"
$callRe = "\bStoragePrefs\s*\.\s*($methodNames)\s*\(\s*('[^']+'|[A-Za-z_]\w*|[^,\r\n)]+)"
$constRe = "\b(?:static\s+)?const\s+(?:String\s+)?(\w+)\s*=\s*'([a-zA-Z0-9_.]+)'"
# A file-local helper that takes the key as a parameter (`String?
# _storedString(String key)`) hides its keys from the direct scan; the values
# handed to it are collected instead, under the kind its own body speaks.
$helperRe = "(?m)^\s*(?:[\w<>?,\s]+\s+)?(_?\w+)\s*\(\s*String\s+(?:key|pref|prefsName)\b"

# A constant imported from another file resolves through the global map, and
# only while its name is unambiguous there. Provider names come from the same
# whole-tree pass, so a listed controller that was renamed reads as stale.
$providerFiles = @{}
$constValues = @{}
foreach ($file in $dartFiles) {
    $text = Get-Content -Raw $file.FullName
    foreach ($match in [regex]::Matches($text, $constRe)) {
        $name = $match.Groups[1].Value
        if (-not $constValues.ContainsKey($name)) {
            $constValues[$name] = [System.Collections.Generic.HashSet[string]]::new()
        }
        [void]$constValues[$name].Add($match.Groups[2].Value)
    }
    foreach ($match in [regex]::Matches($text, "final\s+(\w+Provider)\s*=")) {
        $providerFiles[$match.Groups[1].Value] = $file.FullName.Substring($Root.Length + 1).Replace("\", "/")
    }
}
$globalConsts = @{}
foreach ($entry in $constValues.GetEnumerator()) {
    if (@($entry.Value).Count -eq 1) {
        $globalConsts[$entry.Key] = @($entry.Value)[0]
    }
}

$observedKinds = @{}
$observedSites = @{}
$dynamicSites = [System.Collections.Generic.List[string]]::new()
$packagePrefSites = [System.Collections.Generic.List[string]]::new()
$prefsProviders = @{}

function Add-Observation {
    param($key, $kind, $site)
    if (-not $script:observedKinds.ContainsKey($key)) {
        $script:observedKinds[$key] = [System.Collections.Generic.HashSet[string]]::new()
        $script:observedSites[$key] = [System.Collections.Generic.List[string]]::new()
    }
    [void]$script:observedKinds[$key].Add($kind)
    $script:observedSites[$key].Add($site)
}

foreach ($file in $dartFiles) {
    $text = Get-Content -Raw $file.FullName
    if ($text -notmatch "StoragePrefs") {
        continue
    }
    $relative = $file.FullName.Substring($Root.Length + 1).Replace("\", "/")

    # Constants in declaration order: a file reuses a name such as `prefsKey`
    # for several classes, and a call site takes the value declared above it.
    $fileConsts = [System.Collections.Generic.List[System.Object]]::new()
    foreach ($match in [regex]::Matches($text, $constRe)) {
        $fileConsts.Add(@{ Pos = $match.Index; Name = $match.Groups[1].Value; Value = $match.Groups[2].Value })
    }


    foreach ($match in [regex]::Matches($text, $callRe)) {
        $method = $match.Groups[1].Value
        $argument = $match.Groups[2].Value.Trim()
        $key = $null
        if ($argument.StartsWith("'")) {
            $key = $argument.Trim("'")
        } elseif ($argument -match "^[A-Za-z_]\w*$") {
            $resolved = $null
            foreach ($candidate in $fileConsts) {
                if ($candidate.Name -eq $argument -and $candidate.Pos -le $match.Index) {
                    $resolved = $candidate
                }
            }
            if ($resolved) {
                $key = $resolved.Value
            } elseif ($globalConsts.ContainsKey($argument)) {
                $key = $globalConsts[$argument]
            }
        }
        if (-not $key) {
            # A computed key: a per-document name, or a key that arrives from
            # further away than a constant. Those must be listed in the
            # manifest by hand, so they are printed for review, not failed on.
            $dynamicSites.Add("$relative : StoragePrefs.$method($argument)")
            continue
        }
        if ($relative.StartsWith("packages/")) {
            $packagePrefSites.Add("$relative uses the key '$key'")
        }
        Add-Observation $key (& $kindOf $method) "$relative`:$method"
    }

    # A helper that takes the key as a parameter hides it from the direct
    # scan: the values handed to it are collected instead, under the kind the
    # helper's own body speaks to the facade.
    foreach ($match in [regex]::Matches($text, $helperRe)) {
        $helper = $match.Groups[1].Value
        $body = $text.Substring($match.Index, [Math]::Min(700, $text.Length - $match.Index))
        $bodyKind = "any"
        if ($body -match "StoragePrefs\s*\.\s*($methodNames)") {
            $bodyKind = & $kindOf $Matches[1]
        }
        foreach ($call in [regex]::Matches($text, "\b$helper\s*\(\s*('[^']+'|[A-Za-z_]\w*)")) {
            $key = $null
            $argument = $call.Groups[1].Value
            if ($argument.StartsWith("'")) {
                $key = $argument.Trim("'")
            } elseif ($globalConsts.ContainsKey($argument)) {
                $key = $globalConsts[$argument]
            } else {
                foreach ($candidate in $fileConsts) {
                    if ($candidate.Name -eq $argument -and $candidate.Pos -le $call.Index) {
                        $key = $candidate.Value
                    }
                }
            }
            if ($key) {
                Add-Observation $key $bodyKind "$relative`:$helper"
            }
        }
    }

    # A controller body that names StoragePrefs owns settings, whatever else it
    # caches, so a change underneath it has to rebuild it.
    foreach ($match in [regex]::Matches($text, "final\s+(\w+Provider)\s*=\s*(?:Async)?NotifierProvider\s*<\s*(\w+)\s*,")) {
        $class = $match.Groups[2].Value
        $start = $text.IndexOf("final class $class")
        if ($start -lt 0) {
            continue
        }
        $next = $text.IndexOf("`nfinal class ", $start + 1)
        $length = $(if ($next -lt 0) { $text.Length - $start } else { $next - $start })
        if ($text.Substring($start, $length) -match "StoragePrefs") {
            $prefsProviders[$match.Groups[1].Value] = $relative
        }
    }
}

# The backup manifest: key plus the kind capture and restore speak.
$backupKinds = @{}
foreach ($match in [regex]::Matches((Get-Content -Raw $backupFile), "\('([a-zA-Z0-9_.]+)',\s*BackupPrefKind\.(\w+)\)")) {
    $backupKinds[$match.Groups[1].Value] = $match.Groups[2].Value
}

# Keys that stay out of the document on purpose, each with the reason the gate
# would otherwise print. A new entry here needs a sentence, not just a name.
$unbackedAllowed = @{
    "recorder.saveDir" = "a legacy value recorder.dir was upgraded from, read only as a fallback and never written; the live choice travels as recorder.dir."
}

foreach ($key in ($observedKinds.Keys | Sort-Object)) {
    if (-not $backupKinds.ContainsKey($key)) {
        if ($unbackedAllowed.ContainsKey($key)) {
            continue
        }
        $sites = ($observedSites[$key] | Select-Object -First 2) -join ", "
        $issues.Add("Unbacked pref '$key' (call sites: $sites) is missing from kBackedUpPrefs, so a backup loses it and a restore cannot bring it back.")
        continue
    }
    $declared = $backupKinds[$key]
    $seen = @($observedKinds[$key] | Where-Object { $_ -ne "any" })
    if ($seen.Count -gt 0 -and -not ($seen -contains $declared)) {
        $issues.Add("Wrong backup kind for '$key': kBackedUpPrefs declares BackupPrefKind.$declared while the call sites speak $(($seen | Sort-Object) -join '/'); capture finds no value and the key never restores.")
    }
}

foreach ($key in ($backupKinds.Keys | Sort-Object)) {
    if (-not $observedKinds.ContainsKey($key)) {
        $issues.Add("Stale backup entry '$key': no StoragePrefs call site uses it any more; drop it from kBackedUpPrefs.")
    }
}

foreach ($site in ($packagePrefSites | Sort-Object -Unique)) {
    $issues.Add("Package-layer pref ownership: $site. Keys belong to the app and the package takes the value as an argument; see docs/settings-center-restructure.md.")
}

$listed = [System.Collections.Generic.HashSet[string]]::new()
foreach ($match in [regex]::Matches((Get-Content -Raw $refreshFile), "(?m)^\s{2}(\w+),")) {
    [void]$listed.Add($match.Groups[1].Value)
}

# Absent on purpose: a window keeps its own navigation and its own live window
# size to itself, so those controllers never take another window's choice or a
# restored document's value.
$refreshAllowed = @{
    "selectedModuleProvider" = "which module a window shows is that window's own navigation state."
    "selectedSiteIdProvider" = "the site a window is browsing is that window's own navigation state."
    "popularSiteProvider"    = "the popular page's picked site is navigation state, not a synced setting."
    "areasSiteProvider"      = "the areas page's picked site is navigation state, not a synced setting."
    "searchSiteIdProvider"   = "the search page's picked site is navigation state, not a synced setting."
    "windowSizeProvider"     = "the controller is the window's own size tracker, armed once at boot; a restored size lands on the next start."
}

foreach ($provider in ($prefsProviders.Keys | Sort-Object)) {
    if ($listed.Contains($provider) -or $refreshAllowed.ContainsKey($provider)) {
        continue
    }
    $issues.Add("Missing invalidation: $provider ($($prefsProviders[$provider])) reads StoragePrefs but is not in kSettingsProviders, so a restored backup or another window's write leaves it on its old values.")
}

foreach ($provider in ($listed | Sort-Object)) {
    if (-not $providerFiles.ContainsKey($provider)) {
        $issues.Add("Stale invalidation entry: $provider is named in kSettingsProviders but no such provider exists any more; drop it or point at the controller that took over.")
    }
}

if ($issues.Count -gt 0) {
    Write-Host "Prefs manifest checks failed:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host " - $issue" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Prefs manifest checks passed: $($observedKinds.Count) prefs keys, $($backupKinds.Count) backup entries, $($listed.Count) invalidations." -ForegroundColor Green
if ($dynamicSites.Count -gt 0) {
    Write-Host "Computed-key call sites, for review rather than failure:" -ForegroundColor DarkGray
    foreach ($site in ($dynamicSites | Sort-Object -Unique | Select-Object -First 15)) {
        Write-Host " - $site" -ForegroundColor DarkGray
    }
}
