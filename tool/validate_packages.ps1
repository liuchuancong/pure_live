[CmdletBinding()]
param(
    # Resolved below rather than in the default value: $PSScriptRoot is still
    # empty while a param block is evaluated under Windows PowerShell, which made
    # this script unrunnable as documented.
    [string]$Root,
    [switch]$CheckFormatting
)

if (-not $Root) {
    $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$issues = [System.Collections.Generic.List[string]]::new()
$rootPubspec = Join-Path $Root "pubspec.yaml"

if (-not (Test-Path $rootPubspec)) {
    throw "Root pubspec.yaml not found: $rootPubspec"
}

$content = Get-Content -Raw $rootPubspec
$workspacePaths = [System.Collections.Generic.List[string]]::new()
$inWorkspace = $false
foreach ($line in (Get-Content $rootPubspec)) {
    if ($line -match '^workspace:\s*$') {
        $inWorkspace = $true
        continue
    }
    if ($inWorkspace) {
        if ($line -match '^\S' -and $line -notmatch '^workspace:') {
            $inWorkspace = $false
        } elseif ($line -match '^\s*-\s+(.+?)\s*$') {
            $workspacePaths.Add($Matches[1].Trim("'`""))
        }
    }
}

$seenNames = @{}
foreach ($relativePath in $workspacePaths) {
    $normalized = $relativePath.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    $packagePath = Join-Path $Root $normalized
    if (-not (Test-Path $packagePath)) {
        $issues.Add("Workspace path does not exist: $relativePath")
        continue
    }

    $pubspec = Join-Path $packagePath "pubspec.yaml"
    if (-not (Test-Path $pubspec)) {
        $issues.Add("Missing pubspec.yaml: $relativePath")
        continue
    }

    $yaml = Get-Content -Raw $pubspec
    if ($yaml -notmatch '(?m)^name:\s*([a-z0-9_]+)\s*$') {
        $issues.Add("Cannot read valid package name in $relativePath/pubspec.yaml")
        continue
    }
    $name = $Matches[1]

    if ($name -notmatch '^live_[a-z0-9]+(?:_[a-z0-9]+)*$' -and $relativePath -notmatch '^apps/') {
        $issues.Add("Package name '$name' does not follow live_snake_case: $relativePath")
    }
    if ($seenNames.ContainsKey($name)) {
        $issues.Add("Duplicate package name '$name': $relativePath and $($seenNames[$name])")
    } else {
        $seenNames[$name] = $relativePath
    }

    $actualName = Split-Path $packagePath -Leaf
    if ($actualName -ne $name) {
        $issues.Add("Directory name '$actualName' does not match pubspec name '$name': $relativePath")
    }

    if ($yaml -notmatch '(?m)^resolution:\s*workspace\s*$') {
        $issues.Add("Missing 'resolution: workspace': $relativePath/pubspec.yaml")
    }

    foreach ($required in @("README.md", "CHANGELOG.md", "analysis_options.yaml", "lib", "test")) {
        if (-not (Test-Path (Join-Path $packagePath $required))) {
            $issues.Add("Missing required item '$required': $relativePath")
        }
    }

    # A package importing its own lib/src is normal and must not be reported;
    # the rule is about reaching into *another* package's implementation. The
    # previous pattern matched every `package:x/src/` import, so each package was
    # blamed for its own internal imports and the real findings were buried.
    $crossPackageSrc = Get-ChildItem -Path (Join-Path $packagePath "lib") -Recurse -File -Filter "*.dart" -ErrorAction SilentlyContinue |
        Select-String -Pattern "package:([A-Za-z0-9_]+)/src/" -AllMatches -ErrorAction SilentlyContinue
    foreach ($match in $crossPackageSrc) {
        foreach ($group in $match.Matches) {
            if ($group.Groups[1].Value -ne $name) {
                $issues.Add(
                    "Cross-package private import of '$($group.Groups[1].Value)/src/' in $relativePath`: $($match.Path):$($match.LineNumber)"
                )
            }
        }
    }
}

if ($CheckFormatting) {
    Push-Location $Root
    try {
        & dart format --output=none --set-exit-if-changed .
        if ($LASTEXITCODE -ne 0) {
            $issues.Add("Dart formatting check failed.")
        }
    } finally {
        Pop-Location
    }
}

if ($issues.Count -gt 0) {
    Write-Host "Package validation failed:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host " - $issue" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Package validation passed. Checked $($workspacePaths.Count) workspace entries." -ForegroundColor Green
