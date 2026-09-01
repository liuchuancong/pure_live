[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ApkPath,

    [string] $ExpectedAbi = 'arm64-v8a',

    [ValidateSet('Debug', 'Release')]
    [string] $BuildMode = 'Release',

    [string] $ExpectedVersionName = '',

    [string] $ExpectedBaseVersionCode = '',

    [int] $ExpectedAbiVersionOffset = 0
)

$ErrorActionPreference = 'Stop'
$resolvedApk = (Resolve-Path -LiteralPath $ApkPath).Path
Add-Type -AssemblyName System.IO.Compression.FileSystem

$requiredEntries = [ordered]@{
    'assets/flutter_assets/AssetManifest.bin' = 1024
    'assets/flutter_assets/NOTICES.Z' = 1024
    'assets/flutter_assets/assets/version.json' = 50
    'assets/flutter_assets/assets/releases.json' = 50
    'assets/flutter_assets/assets/translations/zh.json' = 1024
    'assets/flutter_assets/assets/images/banner.png' = 1024
    'assets/flutter_assets/assets/emo/json/bilibili.json' = 1024
    "lib/$ExpectedAbi/libflutter.so" = 5MB
    "lib/$ExpectedAbi/libmpv.so" = 10MB
    "lib/$ExpectedAbi/libijkffmpeg.so" = 1MB
    "lib/$ExpectedAbi/libffmpegkit.so" = 20MB
    "lib/$ExpectedAbi/libsqlite3.so" = 512KB
}

if ($BuildMode -eq 'Release') {
    $requiredEntries["lib/$ExpectedAbi/libapp.so"] = 1MB
} else {
    # Flutter Debug is JIT-based: application code lives in kernel/snapshot
    # assets, so requiring the AOT-only libapp.so rejects a healthy debug APK.
    $requiredEntries['assets/flutter_assets/kernel_blob.bin'] = 1MB
    $requiredEntries['assets/flutter_assets/isolate_snapshot_data'] = 1MB
}

$archive = [IO.Compression.ZipFile]::OpenRead($resolvedApk)
try {
    $entries = @{}
    foreach ($entry in $archive.Entries) {
        $entries[$entry.FullName] = $entry
    }

    foreach ($required in $requiredEntries.GetEnumerator()) {
        if (-not $entries.ContainsKey($required.Key)) {
            throw "Android APK is incomplete; required entry is missing: $($required.Key)"
        }
        if ($entries[$required.Key].Length -lt $required.Value) {
            throw "Android APK entry is unexpectedly small: $($required.Key) ($($entries[$required.Key].Length) bytes)"
        }
    }

    $flutterAssets = @($archive.Entries | Where-Object {
        $_.FullName.StartsWith('assets/flutter_assets/', [StringComparison]::Ordinal) -and
            -not $_.FullName.EndsWith('/', [StringComparison]::Ordinal)
    })
    $flutterAssetBytes = ($flutterAssets | Measure-Object -Property Length -Sum).Sum
    if ($flutterAssets.Count -lt 1000 -or $flutterAssetBytes -lt 10MB) {
        throw "Android APK Flutter asset bundle is incomplete: $($flutterAssets.Count) files, $flutterAssetBytes bytes"
    }

    $abis = @($archive.Entries |
        Where-Object { $_.FullName -match '^lib/([^/]+)/[^/]+$' } |
        ForEach-Object { if ($_.FullName -match '^lib/([^/]+)/') { $Matches[1] } } |
        Sort-Object -Unique)
    if ($abis.Count -ne 1 -or $abis[0] -ne $ExpectedAbi) {
        throw "Android APK ABI set is invalid: expected only $ExpectedAbi, found $($abis -join ', ')"
    }
} finally {
    $archive.Dispose()
}

$sdkRoots = @(
    $env:ANDROID_SDK_ROOT,
    $env:ANDROID_HOME,
    $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android\Sdk' })
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique
$buildTools = $(foreach ($sdkRoot in $sdkRoots) {
    Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Directory -ErrorAction SilentlyContinue
}) | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not $buildTools) {
    throw 'Android APK verification requires Android SDK build-tools.'
}

$zipAlign = Join-Path $buildTools.FullName 'zipalign.exe'
if (-not (Test-Path -LiteralPath $zipAlign -PathType Leaf)) {
    throw "Android APK verification requires zipalign.exe: $zipAlign"
}
& $zipAlign -c -P 16 4 $resolvedApk
if ($LASTEXITCODE -ne 0) {
    throw "Android APK ZIP alignment is not 16 KB compatible: $resolvedApk"
}

$elfAlignment = & (Join-Path $PSScriptRoot 'verify_android_elf_alignment.ps1') `
    -InputPath $resolvedApk `
    -ExpectedAbi $ExpectedAbi

$aapt2 = $(foreach ($sdkRoot in $sdkRoots) {
    Get-ChildItem -LiteralPath (Join-Path $sdkRoot 'build-tools') -Recurse -File -Filter 'aapt2.exe' -ErrorAction SilentlyContinue
}) | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $aapt2) {
    throw 'Android APK manifest verification requires aapt2 from Android SDK build-tools.'
}

$badging = @(& $aapt2.FullName dump badging $resolvedApk)
if ($LASTEXITCODE -ne 0) {
    throw "aapt2 failed while reading APK metadata: $resolvedApk"
}
$packageLine = $badging | Where-Object { $_ -like 'package:*' } | Select-Object -First 1
$versionCodeMatch = if ($packageLine) { [regex]::Match($packageLine, "(?<![A-Za-z])versionCode='(\d+)'") } else { $null }
$versionNameMatch = if ($packageLine) { [regex]::Match($packageLine, "(?<![A-Za-z])versionName='([^']*)'") } else { $null }
if (-not $packageLine -or -not $versionCodeMatch.Success -or -not $versionNameMatch.Success) {
    throw 'Android APK manifest version metadata was not found.'
}
$manifestVersionCode = [int64]$versionCodeMatch.Groups[1].Value
$manifestVersionName = $versionNameMatch.Groups[1].Value
if ($ExpectedVersionName -and $manifestVersionName -ne $ExpectedVersionName) {
    throw "Android APK versionName mismatch: expected $ExpectedVersionName, found $manifestVersionName"
}

$baseVersionCode = $null
if ($ExpectedBaseVersionCode) {
    $parsedBaseVersionCode = 0L
    if (-not [int64]::TryParse($ExpectedBaseVersionCode, [ref]$parsedBaseVersionCode)) {
        throw "Expected base Android versionCode is not an integer: $ExpectedBaseVersionCode"
    }
    $baseVersionCode = $parsedBaseVersionCode
    $expectedManifestVersionCode = $baseVersionCode + [int64]$ExpectedAbiVersionOffset
    if ($manifestVersionCode -ne $expectedManifestVersionCode) {
        throw "Android APK versionCode mismatch: expected $expectedManifestVersionCode (base $baseVersionCode + ABI offset $ExpectedAbiVersionOffset), found $manifestVersionCode"
    }
}

$apkFile = Get-Item -LiteralPath $resolvedApk
$apkHash = (Get-FileHash -LiteralPath $resolvedApk -Algorithm SHA256).Hash
Write-Host (
    "Android APK integrity passed: ABI=$ExpectedAbi, version=$manifestVersionName, " +
    "manifestVersionCode=$manifestVersionCode, Flutter assets=$($flutterAssets.Count), asset bytes=$flutterAssetBytes"
)

[pscustomobject][ordered]@{
    package_name = $(if ($packageLine -match "^package:\s+name='([^']+)'") { $Matches[1] } else { '' })
    version_name = $manifestVersionName
    base_version_code = $baseVersionCode
    abi_version_code_offset = $ExpectedAbiVersionOffset
    manifest_version_code = $manifestVersionCode
    abi = $ExpectedAbi
    native_library_count = $elfAlignment.library_count
    minimum_elf_load_alignment = $elfAlignment.minimum_required_alignment
    size_bytes = $apkFile.Length
    sha256 = $apkHash
}
