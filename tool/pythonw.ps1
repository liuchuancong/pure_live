[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

$ErrorActionPreference = 'Stop'

# Runs a Python entrypoint with an interpreter that actually starts.
#
# On Windows the bare `python` name often resolves to something that cannot run a script at all: an MSYS2
# build without its standard library dies with "No module named 'encodings'" before the entrypoint loads, and
# the App Launcher stub opens the Store. Every gate that shells out to it then reports a failure that is not
# the script's. The probe is the cheap fix, because a candidate is only accepted when it can print its own
# version - a broken install cannot fake that.
#
# Set PURE_LIVE_PYTHON to an executable (optionally followed by its own arguments) on machines where the
# probe cannot find a usable interpreter: a virtualenv, or a newer interpreter than the launcher offers.
# A List of arrays, not `@() += ,@(...)`: array += flattens the inner array, which would leave single
# characters to be treated as executables.
$candidates = [System.Collections.Generic.List[object]]::new()
if ($env:PURE_LIVE_PYTHON) {
    $candidates.Add(@([string[]]($env:PURE_LIVE_PYTHON -split '\s+')))
}
$candidates.Add(@('python'))
$candidates.Add(@('python3'))
$candidates.Add(@('py', '-3'))

$resolved = $null
foreach ($candidate in $candidates) {
    if ($candidate.Count -eq 0 -or [string]::IsNullOrWhiteSpace($candidate[0])) { continue }
    $executable = $candidate[0]
    $prefix = @($candidate | Select-Object -Skip 1)
    # No quote characters inside the probe source: Windows PowerShell strips inner double quotes when it hands
    # an argument to a native command, which would turn the probe into a SyntaxError and reject a good
    # interpreter. Encoding the version as one integer keeps the argument quote-free.
    $probe = @($prefix) + @('-c', 'import sys; print(sys.version_info[0] * 100 + sys.version_info[1])')
    try {
        # The probe must not die on stderr: the py launcher writes "Installed Pythons found by py Launcher"
        # there on success, and a Stop-preference native stderr line would be thrown as NativeCommandError.
        $probePreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $version = & $executable @probe 2>$null
    } catch {
        $version = $null
    } finally {
        $ErrorActionPreference = $probePreference
    }
    if ($LASTEXITCODE -ne 0 -or "$version" -notmatch '^\s*\d+\s*$') { continue }
    $versionNumber = [int]("$version".Trim())
    $resolved = [pscustomobject]@{
        Executable = $executable
        Prefix     = $prefix
        Version    = '{0}.{1}' -f [math]::Floor($versionNumber / 100), ($versionNumber % 100)
    }
    break
}

if (-not $resolved) {
    Write-Host 'No usable Python interpreter found. Tried python, python3 and "py -3"; set PURE_LIVE_PYTHON to pin one.'
    $global:LASTEXITCODE = 1
    exit 1
}

Write-Host "Python interpreter: $($resolved.Executable) $($resolved.Prefix -join ' ') ($($resolved.Version))"

$all = @($resolved.Prefix) + @($Arguments)
$previousPreference = $ErrorActionPreference
try {
    # A native command's nonzero exit code must not be turned into a PowerShell error before the caller can
    # read it; the exit code is the single source of truth for success here.
    $ErrorActionPreference = 'Continue'
    & $resolved.Executable @all
    $pythonExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousPreference
}

$global:LASTEXITCODE = $pythonExitCode
if ($pythonExitCode -ne 0) {
    exit $pythonExitCode
}
