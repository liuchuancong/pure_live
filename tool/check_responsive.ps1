# Responsive layout gate (§10).
#
# The one class of responsive bug this project actually shipped was a grid
# wall whose column count was a literal (the platform picker's fixed three):
# on a phone's sheet the names compressed into ellipses, on a desktop panel
# the width was wasted. Every other surface already branches on its own
# width through LayoutBuilder or LiveWindow.
#
# So this gate has one rule, stated as narrowly as the bug: a grid delegate
# must not be const and must not name a literal column count. A computed
# count (from the constraints, clamped) passes. Grow the rule set only when
# an audit finds a real second class.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$lib = Join-Path $root 'apps/pure_live/lib'
$failures = New-Object System.Collections.Generic.List[string]

Get-ChildItem -Path $lib -Recurse -Filter *.dart | ForEach-Object {
    $relative = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    $text = Get-Content -Path $_.FullName -Raw -Encoding UTF8
    foreach ($match in [regex]::Matches($text, 'SliverGridDelegateWithFixedCrossAxisCount')) {
        $lineStart = $text.LastIndexOf("`n", [Math]::Max(0, $match.Index - 1)) + 1
        $lineEnd = $text.IndexOf("`n", $match.Index)
        if ($lineEnd -lt 0) { $lineEnd = $text.Length }
        $line = $text.Substring($lineStart, $lineEnd - $lineStart)
        $lineNumber = ($text.Substring(0, $match.Index) -split "`n").Count
        if ($line -match '\bconst\b') {
            $failures.Add("${relative}:${lineNumber} : a const grid delegate names its columns at build time")
        }
    }
    foreach ($match in [regex]::Matches($text, 'crossAxisCount\s*:\s*(\d+)')) {
        $lineNumber = ($text.Substring(0, $match.Index) -split "`n").Count
        $failures.Add("${relative}:${lineNumber} : crossAxisCount is the literal $($match.Groups[1].Value); derive it from the constraints")
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'responsive layout gate failed:'
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}

Write-Host 'responsive layout gate passed (no literal grid columns).'
