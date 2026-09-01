[CmdletBinding(DefaultParameterSetName = 'List')]
param(
    [Parameter(ParameterSetName = 'List')]
    [switch]$List,

    [Parameter(Mandatory, ParameterSetName = 'Tap')]
    [string]$Tap,

    [Parameter(Mandatory, ParameterSetName = 'TapSemantic')]
    [string]$TapSemantic,

    [Parameter(Mandatory, ParameterSetName = 'Sequence')]
    [string]$Sequence,

    [Parameter(Mandatory, ParameterSetName = 'Snapshot')]
    [string]$Snapshot,

    [Parameter(Mandatory, ParameterSetName = 'RemoveSnapshot')]
    [string]$RemoveSnapshot,

    [Parameter(ParameterSetName = 'Snapshot')]
    [switch]$IncludeNonActionable,

    [Parameter(Mandatory, ParameterSetName = 'Record')]
    [string]$Record,

    [Parameter(Mandatory, ParameterSetName = 'Record')]
    [int]$X,

    [Parameter(Mandatory, ParameterSetName = 'Record')]
    [int]$Y,

    [Parameter(ParameterSetName = 'Validate')]
    [switch]$Validate,

    [string]$Label = '',
    [string]$Serial = $env:ANDROID_SERIAL,
    [string]$Profile,
    [switch]$DryRun,
    [switch]$CaptureOnFailure,
    [switch]$VerifySemantics,
    [switch]$NoBringToFront
)

$ErrorActionPreference = 'Stop'
$mapPath = Join-Path $PSScriptRoot 'device_ui_map.json'
$adbCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'),
    'adb.exe'
)
$adb = $adbCandidates | Where-Object {
    if ([System.IO.Path]::IsPathRooted($_)) { Test-Path -LiteralPath $_ }
    else { [bool](Get-Command $_ -ErrorAction SilentlyContinue) }
} | Select-Object -First 1

if (-not $adb) { throw 'ADB executable was not found.' }

function Invoke-Adb {
    param([Parameter(Mandatory = $true)][string[]]$AdbArguments)
    $all = @()
    if ($Serial) { $all += @('-s', $Serial) }
    $all += $AdbArguments
    $result = & $adb @all
    if ($LASTEXITCODE -ne 0) { throw "adb exited with code ${LASTEXITCODE}: $($AdbArguments -join ' ')" }
    $result
}

function Get-Map {
    Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Format-JsonText {
    param([Parameter(Mandatory = $true)][string]$Json)
    $builder = [System.Text.StringBuilder]::new()
    $indent = 0
    $inString = $false
    $escaped = $false
    for ($index = 0; $index -lt $Json.Length; $index++) {
        $character = $Json[$index]
        if ($inString) {
            $null = $builder.Append($character)
            if ($escaped) { $escaped = $false }
            elseif ($character -eq '\') { $escaped = $true }
            elseif ($character -eq '"') { $inString = $false }
            continue
        }
        if ($character -eq '"') {
            $inString = $true
            $null = $builder.Append($character)
            continue
        }
        if ([char]::IsWhiteSpace($character)) { continue }
        switch ($character) {
            { $_ -eq '{' -or $_ -eq '[' } {
                $null = $builder.Append($character)
                $next = if ($index + 1 -lt $Json.Length) { $Json[$index + 1] } else { [char]0 }
                $matchingClose = if ($character -eq '{') { '}' } else { ']' }
                if ($next -ne $matchingClose) {
                    $indent++
                    $null = $builder.Append("`n").Append(' ' * ($indent * 2))
                }
                break
            }
            { $_ -eq '}' -or $_ -eq ']' } {
                $previous = if ($index -gt 0) { $Json[$index - 1] } else { [char]0 }
                $matchingOpen = if ($character -eq '}') { '{' } else { '[' }
                if ($previous -ne $matchingOpen) {
                    $indent--
                    $null = $builder.Append("`n").Append(' ' * ($indent * 2))
                }
                $null = $builder.Append($character)
                break
            }
            ',' {
                $null = $builder.Append(",`n").Append(' ' * ($indent * 2))
                break
            }
            ':' {
                $null = $builder.Append(': ')
                break
            }
            default { $null = $builder.Append($character) }
        }
    }
    $builder.ToString()
}

function Save-Map {
    param($Map)
    $compact = $Map | ConvertTo-Json -Depth 30 -Compress
    $formatted = Format-JsonText $compact
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($mapPath, $formatted + [Environment]::NewLine, $utf8WithoutBom)
}

function Get-DeviceMetrics {
    $window = (Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'window', 'displays') | Select-String 'cur=(\d+)x(\d+)' | Select-Object -First 1)
    if ($window -and $window.Line -match 'cur=(\d+)x(\d+)') {
        $width = [int]$Matches[1]
        $height = [int]$Matches[2]
    }
    else {
        $line = (Invoke-Adb -AdbArguments @('shell', 'wm', 'size') | Select-Object -First 1)
        if ($line -notmatch '(\d+)x(\d+)') { throw "Unexpected device size output: $line" }
        $width = [int]$Matches[1]
        $height = [int]$Matches[2]
    }
    [pscustomobject]@{
        Width = $width
        Height = $height
        Orientation = $(if ($width -gt $height) { 'landscape' } else { 'portrait' })
    }
}

function Get-AppVersion {
    param([string]$Package)
    $lines = Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'package', $Package)
    $versionName = (($lines | Select-String 'versionName=' | Select-Object -First 1).Line -replace '^.*versionName=', '').Trim()
    $versionCodeLine = ($lines | Select-String 'versionCode=' | Select-Object -First 1).Line
    $versionCode = if ($versionCodeLine -match 'versionCode=(\d+)') { $Matches[1] } else { '' }
    [pscustomobject]@{ Name = $versionName; Code = $versionCode }
}

function Get-TopPackage {
    $match = Invoke-Adb -AdbArguments @('shell', 'dumpsys', 'activity', 'activities') |
        Select-String 'topResumedActivity=|mResumedActivity:' |
        Select-Object -First 1
    if ($null -eq $match) { return '' }
    $line = $match.Line
    if ($line -match ' u\d+ ([^/\s]+)/') { return $Matches[1] }
    ''
}

function Assert-TargetApp {
    param([string]$Package)
    $top = Get-TopPackage
    if ($top -ne $Package) {
        throw "Expected '$Package' in foreground, but '$top' is resumed. UI action was stopped before tapping."
    }
}

function Enter-TargetApp {
    param([string]$Package)
    if (-not $NoBringToFront) {
        Invoke-Adb -AdbArguments @('shell', 'am', 'start', '-n', "$Package/.MainActivity") | Out-Null
        Start-Sleep -Milliseconds 250
    }
    Assert-TargetApp $Package
}

function Resolve-Profile {
    param($Map)
    if ($Profile) {
        $selected = $Map.profiles.PSObject.Properties[$Profile]
        if (-not $selected) { throw "Unknown UI profile: $Profile" }
        return [pscustomobject]@{ Name = $Profile; Data = $selected.Value }
    }

    $metrics = Get-DeviceMetrics
    foreach ($entry in $Map.profiles.PSObject.Properties) {
        if ($entry.Value.width -eq $metrics.Width -and
            $entry.Value.height -eq $metrics.Height -and
            $entry.Value.orientation -eq $metrics.Orientation) {
            return [pscustomobject]@{ Name = $entry.Name; Data = $entry.Value }
        }
    }

    $fallback = $Map.profiles.PSObject.Properties[$Map.defaultProfile]
    if ($fallback.Value.orientation -ne $metrics.Orientation) {
        throw "No $($metrics.Orientation) UI profile for $($metrics.Width)x$($metrics.Height). Record a profile before using cached coordinates."
    }
    Write-Warning "No exact profile for $($metrics.Width)x$($metrics.Height); scaling '$($Map.defaultProfile)'."
    [pscustomobject]@{ Name = $Map.defaultProfile; Data = $fallback.Value }
}

function Convert-Bounds {
    param([string]$Bounds)
    if ($Bounds -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') { return $null }
    $left = [int]$Matches[1]
    $top = [int]$Matches[2]
    $right = [int]$Matches[3]
    $bottom = [int]$Matches[4]
    [pscustomobject]@{
        Left = $left
        Top = $top
        Right = $right
        Bottom = $bottom
        X = [math]::Floor(($left + $right) / 2)
        Y = [math]::Floor(($top + $bottom) / 2)
        Area = [math]::Max(0, ($right - $left) * ($bottom - $top))
    }
}

function Get-UiNodes {
    Assert-TargetApp $map.package
    $remote = '/sdcard/purelive-ui-map.xml'
    $local = [System.IO.Path]::GetTempFileName()
    # Live danmaku changes continuously, so UIAutomator may never observe an
    # idle frame. Android's built-in timeout keeps semantic verification from
    # blocking the whole device regression; --compressed also reduces work.
    try {
        Invoke-Adb -AdbArguments @('shell', 'timeout', '10', 'uiautomator', 'dump', '--compressed', $remote) | Out-Null
        # Pull the XML as bytes. Capturing `adb shell cat` output through Windows
        # PowerShell 5.1 decodes UTF-8 semantics with the active OEM code page,
        # corrupting Chinese labels and making semantic verification unreliable.
        Invoke-Adb -AdbArguments @('pull', $remote, $local) | Out-Null
        $raw = [System.IO.File]::ReadAllText($local, [System.Text.Encoding]::UTF8)
    }
    finally {
        Invoke-Adb -AdbArguments @('shell', 'rm', '-f', $remote) | Out-Null
        Remove-Item -LiteralPath $local -Force -ErrorAction SilentlyContinue
    }
    [xml]$xml = $raw
    Assert-TargetApp $map.package
    $nodes = foreach ($node in $xml.SelectNodes('//node')) {
        $bounds = Convert-Bounds $node.bounds
        if (-not $bounds -or $bounds.Area -le 0) { continue }
        [pscustomobject]@{
            Text = [string]$node.text
            Description = [string]$node.'content-desc'
            ResourceId = [string]$node.'resource-id'
            Class = [string]$node.class
            Clickable = [string]$node.clickable -eq 'true'
            LongClickable = [string]$node.'long-clickable' -eq 'true'
            Scrollable = [string]$node.scrollable -eq 'true'
            Checkable = [string]$node.checkable -eq 'true'
            Checked = [string]$node.checked -eq 'true'
            Selected = [string]$node.selected -eq 'true'
            BoundsText = [string]$node.bounds
            Bounds = $bounds
        }
    }
    @($nodes)
}

function Find-SemanticNode {
    param([object[]]$Nodes, [string[]]$Semantics)
    foreach ($semantic in $Semantics) {
        $matches = @($Nodes | Where-Object {
            $_.Description -eq $semantic -or $_.Text -eq $semantic -or
            $_.Description -like "$semantic`n*" -or $_.Text -like "$semantic`n*"
        } | Sort-Object @{ Expression = { -not $_.Clickable } }, @{ Expression = { $_.Bounds.Area } })
        if ($matches.Count -gt 0) { return $matches[0] }
    }
    $null
}

function Get-PointSemantics {
    param($Point)
    if (-not $Point.PSObject.Properties['semantic']) { return @() }
    @($Point.semantic | ForEach-Object { [string]$_ } | Where-Object { $_ })
}

function Resolve-Point {
    param($SelectedProfile, [string]$Name, [object[]]$UiNodes)
    $property = $SelectedProfile.Data.points.PSObject.Properties[$Name]
    if (-not $property) { throw "Unknown UI point '$Name'. Run .\tool\android_ui.ps1 -List." }

    $point = $property.Value
    $semantics = Get-PointSemantics $point
    if ($UiNodes -and $semantics.Count -gt 0) {
        $node = Find-SemanticNode $UiNodes $semantics
        if ($node) {
            return [pscustomobject]@{
                Name = $Name; X = $node.Bounds.X; Y = $node.Bounds.Y
                Label = $point.label; Source = 'semantic'; Semantic = $node.Description
            }
        }
    }

    $metrics = Get-DeviceMetrics
    $x = [math]::Round(([double]$point.x / [double]$SelectedProfile.Data.width) * $metrics.Width)
    $y = [math]::Round(([double]$point.y / [double]$SelectedProfile.Data.height) * $metrics.Height)
    [pscustomobject]@{ Name = $Name; X = $x; Y = $y; Label = $point.label; Source = 'cache'; Semantic = '' }
}

function Invoke-TapPoint {
    param($SelectedProfile, [string]$Name, [switch]$SemanticCheck)
    Assert-TargetApp $map.package
    $nodes = if ($SemanticCheck) { Get-UiNodes } else { $null }
    $point = Resolve-Point $SelectedProfile $Name $nodes
    Write-Host ("tap {0} ({1},{2}) [{3}] - {4}" -f $point.Name, $point.X, $point.Y, $point.Source, $point.Label)
    if (-not $DryRun) { Invoke-Adb -AdbArguments @('shell', 'input', 'tap', $point.X, $point.Y) | Out-Null }
}

function Invoke-TapSemantic {
    param([string]$Semantic)
    Assert-TargetApp $map.package
    $node = Find-SemanticNode (Get-UiNodes) @($Semantic)
    if (-not $node) { throw "Semantic target '$Semantic' is not visible." }
    Write-Host ("tap semantic '{0}' ({1},{2})" -f $Semantic, $node.Bounds.X, $node.Bounds.Y)
    if (-not $DryRun) { Invoke-Adb -AdbArguments @('shell', 'input', 'tap', $node.Bounds.X, $node.Bounds.Y) | Out-Null }
}

function Invoke-SwipeGesture {
    param($SelectedProfile, [string]$Name)
    Assert-TargetApp $map.package
    $property = $SelectedProfile.Data.gestures.PSObject.Properties[$Name]
    if (-not $property) { throw "Unknown UI gesture '$Name'." }
    $gesture = $property.Value
    $metrics = Get-DeviceMetrics
    $x1 = [math]::Round(([double]$gesture.x1 / $SelectedProfile.Data.width) * $metrics.Width)
    $y1 = [math]::Round(([double]$gesture.y1 / $SelectedProfile.Data.height) * $metrics.Height)
    $x2 = [math]::Round(([double]$gesture.x2 / $SelectedProfile.Data.width) * $metrics.Width)
    $y2 = [math]::Round(([double]$gesture.y2 / $SelectedProfile.Data.height) * $metrics.Height)
    $duration = if ($gesture.durationMs) { [int]$gesture.durationMs } else { 350 }
    Write-Host ("swipe {0} ({1},{2})->({3},{4}) {5}ms" -f $Name, $x1, $y1, $x2, $y2, $duration)
    if (-not $DryRun) { Invoke-Adb -AdbArguments @('shell', 'input', 'swipe', $x1, $y1, $x2, $y2, $duration) | Out-Null }
}

function Save-Snapshot {
    param($Map, $SelectedProfile, [string]$Name)
    $nodes = Get-UiNodes
    $metrics = Get-DeviceMetrics
    $version = Get-AppVersion $Map.package
    $catalog = foreach ($node in $nodes) {
        $hasIdentity = $node.Text -or $node.Description -or $node.ResourceId
        $actionable = $node.Clickable -or $node.LongClickable -or $node.Scrollable -or $node.Checkable
        if (-not $hasIdentity -or (-not $IncludeNonActionable -and -not $actionable)) { continue }
        # Keep this expression ASCII-only so the helper also parses correctly in
        # Windows PowerShell 5.1, which treats a UTF-8 file without a BOM as an
        # ANSI script. Password-like semantics use the ordinary colon form.
        if ($node.Description -match '\*{3}\s*:' -or $node.Text -match '\*{3}\s*:') { continue }
        [ordered]@{
            text = $node.Text
            semantic = $node.Description
            resourceId = $node.ResourceId
            class = $node.Class
            bounds = @($node.Bounds.Left, $node.Bounds.Top, $node.Bounds.Right, $node.Bounds.Bottom)
            center = @($node.Bounds.X, $node.Bounds.Y)
            clickable = $node.Clickable
            longClickable = $node.LongClickable
            scrollable = $node.Scrollable
            checkable = $node.Checkable
            checked = $node.Checked
            selected = $node.Selected
        }
    }
    if (-not $SelectedProfile.Data.PSObject.Properties['screens']) {
        $SelectedProfile.Data | Add-Member -NotePropertyName screens -NotePropertyValue ([pscustomobject]@{})
    }
    $snapshotData = [ordered]@{
        recordedAt = (Get-Date).ToString('s')
        appVersion = $version.Name
        versionCode = $version.Code
        orientation = $metrics.Orientation
        width = $metrics.Width
        height = $metrics.Height
        topPackage = Get-TopPackage
        nodes = @($catalog)
    }
    $SelectedProfile.Data.screens | Add-Member -NotePropertyName $Name -NotePropertyValue $snapshotData -Force
    Save-Map $Map
    Write-Host "Saved screen '$Name' with $(@($catalog).Count) semantic/actionable nodes."
}

function Test-Map {
    param($Map, $SelectedProfile)
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($point in $SelectedProfile.Data.points.PSObject.Properties) {
        if ($point.Value.x -lt 0 -or $point.Value.x -gt $SelectedProfile.Data.width -or
            $point.Value.y -lt 0 -or $point.Value.y -gt $SelectedProfile.Data.height) {
            $errors.Add("Point '$($point.Name)' is outside the profile bounds.")
        }
    }
    foreach ($sequence in $SelectedProfile.Data.sequences.PSObject.Properties) {
        foreach ($step in $sequence.Value) {
            # PowerShell unwraps a one-item pipeline result into a scalar.
            # StrictMode then rejects `$actions.Count`, even though every valid
            # sequence step intentionally contains exactly one action. Keep the
            # filtered result as an array on both Windows PowerShell and pwsh.
            $actions = @(
                @('tap', 'tapSemantic', 'swipe', 'wait') | Where-Object {
                    $step.PSObject.Properties[$_]
                }
            )
            if ($actions.Count -ne 1) {
                $errors.Add("Sequence '$($sequence.Name)' must declare exactly one action per step.")
            }
            if ($step.PSObject.Properties['tap'] -and -not $SelectedProfile.Data.points.PSObject.Properties[$step.tap]) {
                $errors.Add("Sequence '$($sequence.Name)' references missing point '$($step.tap)'.")
            }
            if ($step.PSObject.Properties['swipe'] -and -not $SelectedProfile.Data.gestures.PSObject.Properties[$step.swipe]) {
                $errors.Add("Sequence '$($sequence.Name)' references missing gesture '$($step.swipe)'.")
            }
            if ($step.PSObject.Properties['wait'] -and ((-not [bool]$step.wait) -or $step.waitMs -le 0)) {
                $errors.Add("Sequence '$($sequence.Name)' has an invalid wait action.")
            }
        }
    }
    if ($errors.Count -gt 0) { throw ($errors -join [Environment]::NewLine) }
    $mapJson = Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8
    $null = $mapJson | ConvertFrom-Json
    $pointCount = @($SelectedProfile.Data.points.PSObject.Properties).Count
    $sequenceCount = @($SelectedProfile.Data.sequences.PSObject.Properties).Count
    Write-Host "UI map valid: schema $($Map.schemaVersion), profile '$($SelectedProfile.Name)', $pointCount points, $sequenceCount sequences."
}

function Save-FailureEvidence {
    param([string]$Name)
    if (-not $CaptureOnFailure) { return }
    $safeName = $Name -replace '[^a-zA-Z0-9_.-]', '_'
    $dir = Join-Path (Split-Path $PSScriptRoot -Parent) '.dart_tool\device-ui-failures'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $remoteImage = "/sdcard/purelive-$stamp.png"
    $remoteXml = "/sdcard/purelive-$stamp.xml"
    Invoke-Adb -AdbArguments @('shell', 'screencap', '-p', $remoteImage) | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'timeout', '10', 'uiautomator', 'dump', '--compressed', $remoteXml) | Out-Null
    Invoke-Adb -AdbArguments @('pull', $remoteImage, (Join-Path $dir "$stamp-$safeName.png")) | Out-Null
    Invoke-Adb -AdbArguments @('pull', $remoteXml, (Join-Path $dir "$stamp-$safeName.xml")) | Out-Null
    Invoke-Adb -AdbArguments @('shell', 'rm', $remoteImage, $remoteXml) | Out-Null
}

$map = Get-Map
$selected = Resolve-Profile $map

try {
    if ($PSCmdlet.ParameterSetName -in @('Tap', 'TapSemantic', 'Sequence', 'Snapshot')) {
        Enter-TargetApp $map.package
    }
    switch ($PSCmdlet.ParameterSetName) {
        'List' {
            Write-Host "Profile: $($selected.Name) [$($selected.Data.width)x$($selected.Data.height), $($selected.Data.orientation)]"
            Write-Host 'Points:'
            foreach ($entry in $selected.Data.points.PSObject.Properties) {
                Write-Host ("  {0,-32} ({1,4},{2,4})  {3}" -f $entry.Name, $entry.Value.x, $entry.Value.y, $entry.Value.label)
            }
            Write-Host 'Gestures:'
            foreach ($entry in $selected.Data.gestures.PSObject.Properties) { Write-Host "  $($entry.Name)" }
            Write-Host 'Sequences:'
            foreach ($entry in $selected.Data.sequences.PSObject.Properties) { Write-Host "  $($entry.Name)" }
            if ($selected.Data.PSObject.Properties['screens']) {
                Write-Host 'Screen snapshots:'
                foreach ($entry in $selected.Data.screens.PSObject.Properties) {
                    Write-Host "  $($entry.Name) [$($entry.Value.nodes.Count) nodes, $($entry.Value.recordedAt)]"
                }
            }
        }
        'Tap' { Invoke-TapPoint $selected $Tap -SemanticCheck:$VerifySemantics }
        'TapSemantic' { Invoke-TapSemantic $TapSemantic }
        'Sequence' {
            $property = $selected.Data.sequences.PSObject.Properties[$Sequence]
            if (-not $property) { throw "Unknown UI sequence '$Sequence'. Run .\tool\android_ui.ps1 -List." }
            foreach ($step in $property.Value) {
                if ($step.PSObject.Properties['tap']) {
                    Invoke-TapPoint $selected $step.tap -SemanticCheck:($VerifySemantics -or [bool]$step.verifySemantics)
                }
                elseif ($step.PSObject.Properties['tapSemantic']) {
                    Invoke-TapSemantic $step.tapSemantic
                }
                elseif ($step.PSObject.Properties['swipe']) {
                    Invoke-SwipeGesture $selected $step.swipe
                }
                elseif ($step.PSObject.Properties['wait']) {
                    if (-not [bool]$step.wait -or $step.waitMs -le 0) {
                        throw "Sequence '$Sequence' has an invalid wait action."
                    }
                    Write-Host "wait $($step.waitMs)ms"
                }
                if ($step.waitMs -gt 0 -and -not $DryRun) { Start-Sleep -Milliseconds $step.waitMs }
            }
        }
        'Snapshot' { Save-Snapshot $map $selected $Snapshot }
        'RemoveSnapshot' {
            if (-not $selected.Data.PSObject.Properties['screens'] -or
                -not $selected.Data.screens.PSObject.Properties[$RemoveSnapshot]) {
                throw "Unknown screen snapshot '$RemoveSnapshot'."
            }
            $selected.Data.screens.PSObject.Properties.Remove($RemoveSnapshot)
            Save-Map $map
            Write-Host "Removed screen snapshot '$RemoveSnapshot'."
        }
        'Record' {
            $metrics = Get-DeviceMetrics
            $profileProperty = $map.profiles.PSObject.Properties[$selected.Name]
            $point = [ordered]@{
                x = [math]::Round(($X / $metrics.Width) * $selected.Data.width)
                y = [math]::Round(($Y / $metrics.Height) * $selected.Data.height)
                label = $(if ($Label) { $Label } else { $Record })
            }
            $profileProperty.Value.points | Add-Member -NotePropertyName $Record -NotePropertyValue $point -Force
            Save-Map $map
            Write-Host "Recorded '$Record' at ($X,$Y) in profile '$($selected.Name)'."
        }
        'Validate' { Test-Map $map $selected }
    }
}
catch {
    Save-FailureEvidence $PSCmdlet.ParameterSetName
    throw
}
