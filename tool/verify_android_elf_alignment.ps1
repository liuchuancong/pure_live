[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $InputPath,

    [string] $ExpectedAbi = 'arm64-v8a',

    [int64] $MinimumLoadAlignment = 0x4000
)

$ErrorActionPreference = 'Stop'
$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path

function Find-LlvmReadElf {
    $sdkRoots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android\Sdk' })
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
        Select-Object -Unique

    $candidates = foreach ($sdkRoot in $sdkRoots) {
        $ndkRoot = Join-Path $sdkRoot 'ndk'
        if (-not (Test-Path -LiteralPath $ndkRoot -PathType Container)) { continue }
        Get-ChildItem -LiteralPath $ndkRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $tool = Join-Path $_.FullName 'toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe'
            if (Test-Path -LiteralPath $tool -PathType Leaf) {
                [pscustomobject]@{ Version = $_.Name; Path = $tool }
            }
        }
    }

    $selected = $candidates | Sort-Object {
        $parsed = [version]'0.0'
        if ([version]::TryParse($_.Version, [ref]$parsed)) { $parsed } else { [version]'0.0' }
    } -Descending | Select-Object -First 1
    if (-not $selected) {
        throw 'Android ELF verification requires llvm-readelf.exe from an installed Android NDK.'
    }
    return $selected.Path
}

function Get-ElfLoadAlignment {
    param(
        [Parameter(Mandatory = $true)][string] $ReadElf,
        [Parameter(Mandatory = $true)][string] $FilePath
    )

    $headers = @(& $ReadElf -lW $FilePath 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "llvm-readelf failed for $FilePath"
    }
    $alignments = @()
    foreach ($line in $headers) {
        $trimmed = ([string]$line).Trim()
        if (-not $trimmed.StartsWith('LOAD ', [StringComparison]::Ordinal)) { continue }
        $columns = @($trimmed -split '\s+' | Where-Object { $_ })
        if ($columns.Count -lt 2 -or $columns[-1] -notmatch '^0x[0-9a-fA-F]+$') {
            throw "Unexpected LOAD program-header format in ${FilePath}: $trimmed"
        }
        $alignments += [Convert]::ToInt64($columns[-1].Substring(2), 16)
    }
    if ($alignments.Count -eq 0) {
        throw "ELF contains no LOAD program headers: $FilePath"
    }
    return $alignments
}

$readElf = Find-LlvmReadElf
$temporaryRoot = $null
$nativeFiles = @()

try {
    if (Test-Path -LiteralPath $resolvedInput -PathType Container) {
        $nativeFiles = @(Get-ChildItem -LiteralPath $resolvedInput -Recurse -File -Filter '*.so')
    } elseif ([IO.Path]::GetExtension($resolvedInput) -in @('.apk', '.aar', '.zip')) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
            'pure-live-elf-' + [Guid]::NewGuid().ToString('N')
        )
        New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
        $archive = [IO.Compression.ZipFile]::OpenRead($resolvedInput)
        try {
            $nativeEntries = @($archive.Entries | Where-Object {
                $_.FullName -match "^(?:lib|jni)/$([regex]::Escape($ExpectedAbi))/([^/]+\.so)$"
            })
            foreach ($entry in $nativeEntries) {
                $destination = Join-Path $temporaryRoot ([IO.Path]::GetFileName($entry.FullName))
                $sourceStream = $entry.Open()
                $destinationStream = [IO.File]::Create($destination)
                try {
                    $sourceStream.CopyTo($destinationStream)
                } finally {
                    $destinationStream.Dispose()
                    $sourceStream.Dispose()
                }
                $nativeFiles += Get-Item -LiteralPath $destination
            }
        } finally {
            $archive.Dispose()
        }
    } else {
        throw "Android ELF verification expects an APK, AAR, ZIP or directory: $resolvedInput"
    }

    if ($nativeFiles.Count -eq 0) {
        throw "No $ExpectedAbi native libraries were found in: $resolvedInput"
    }

    $results = foreach ($nativeFile in $nativeFiles | Sort-Object Name) {
        $alignments = @(Get-ElfLoadAlignment -ReadElf $readElf -FilePath $nativeFile.FullName)
        $minimum = [int64](($alignments | Measure-Object -Minimum).Minimum)
        [pscustomobject][ordered]@{
            library = $nativeFile.Name
            load_segments = $alignments.Count
            minimum_load_alignment = ('0x{0:x}' -f $minimum)
            compatible = $minimum -ge $MinimumLoadAlignment
        }
    }

    $incompatible = @($results | Where-Object { -not $_.compatible })
    if ($incompatible.Count -gt 0) {
        $summary = ($incompatible | ForEach-Object {
            "$($_.library)=$($_.minimum_load_alignment)"
        }) -join ', '
        throw (
            "Android 16 KB page-size ELF alignment failed for $ExpectedAbi; " +
            "required >= $('0x{0:x}' -f $MinimumLoadAlignment), found $summary"
        )
    }

    Write-Host (
        "Android ELF alignment passed: ABI=$ExpectedAbi, libraries=$($results.Count), " +
        "minimum LOAD alignment >= $('0x{0:x}' -f $MinimumLoadAlignment)"
    )
    [pscustomobject][ordered]@{
        abi = $ExpectedAbi
        library_count = $results.Count
        minimum_required_alignment = ('0x{0:x}' -f $MinimumLoadAlignment)
        llvm_readelf = $readElf
        libraries = @($results)
    }
} finally {
    if ($temporaryRoot) {
        $resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
        $expectedPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if ($resolvedTemporaryRoot.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $resolvedTemporaryRoot)) {
            Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
        }
    }
}
