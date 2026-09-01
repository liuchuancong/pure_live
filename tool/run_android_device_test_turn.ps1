[CmdletBinding()]
param(
    [string]$CommandLine,
    [switch]$Pass,
    [int]$TimeoutMinutes = 180,
    [int]$TurnGraceSeconds = 120,
    [int]$PollSeconds = 3
)

$ErrorActionPreference = 'Stop'
if ($Pass.IsPresent -and -not [string]::IsNullOrWhiteSpace($CommandLine)) {
    throw 'Use either -CommandLine or -Pass, not both.'
}
if (-not $Pass.IsPresent -and [string]::IsNullOrWhiteSpace($CommandLine)) {
    throw 'A complete device-test command is required unless -Pass is used.'
}

$cursor = Get-Item -LiteralPath $PSScriptRoot
$coordinator = $null
while ($null -ne $cursor) {
    $candidate = Join-Path $cursor.FullName 'shared-device-test-rotation\Invoke-DeviceTestTurn.ps1'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $coordinator = $candidate
        break
    }
    $cursor = $cursor.Parent
}
if (-not $coordinator) {
    throw 'Shared device-test coordinator was not found above the repository.'
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$effectiveCommand = if ($Pass.IsPresent) {
    "Write-Host 'Pure Live has no device work in this round; passing the phone.'"
} else {
    $CommandLine
}

& $coordinator `
    -Lane purelive `
    -WorkingDirectory $repositoryRoot `
    -CommandLine $effectiveCommand `
    -TimeoutMinutes $TimeoutMinutes `
    -TurnGraceSeconds $TurnGraceSeconds `
    -PollSeconds $PollSeconds
exit $LASTEXITCODE
