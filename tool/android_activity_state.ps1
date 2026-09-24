# Pure parsing helpers: sourcing this file never connects to a device.
function Test-AndroidPidAbsent {
    param([int] $ExitCode, [AllowEmptyString()][string] $Output)
    # Android pidof normally returns 1 for no matches. Transport failures also
    # return 1, but carry error text and must never count as resource cleanup.
    return $ExitCode -in @(0, 1) -and [string]::IsNullOrWhiteSpace($Output)
}

function Test-AndroidForegroundAvailable {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $Foreground,
        [string] $Package = 'com.mystyle.purelive'
    )

    # An unknown foreground is not evidence that taking over the screen is okay.
    if ([string]::IsNullOrWhiteSpace($Foreground)) { return $false }
    $target = [regex]::Escape($Package) + '/'
    $launcher = '(?:com\.miui\.home|com\.mi\.android\.globallauncher|com\.android\.launcher\w*|com\.google\.android\.apps\.nexuslauncher)/'
    return $Foreground -match ('(?<![\w.])(?:' + $target + '|' + $launcher + ')')
}

function Test-AndroidTargetPictureInPicture {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $ActivityDump,
        [string] $Package = 'com.mystyle.purelive'
    )

    # Scope the reported state to one ActivityRecord, not the whole device.
    # supportsPictureInPicture is a capability, not evidence of entering PiP.
    $blocks = [regex]::Matches(
        $ActivityDump,
        '(?ms)^\s*\*\s*Hist\s+#\d+:\s*ActivityRecord\{(?<identity>[^\r\n]*)\}\r?\n(?<state>.*?)(?=^\s*\*\s*(?:Hist|Task)\b|\z)'
    )
    $target = '(?:^|\s)' + [regex]::Escape($Package) + '/[^\s}]+'
    foreach ($block in $blocks) {
        if ($block.Groups['identity'].Value -match $target -and
            $block.Groups['state'].Value -match '\bmLastReportedPictureInPictureMode=true\b') {
            return $true
        }
    }
    return $false
}
