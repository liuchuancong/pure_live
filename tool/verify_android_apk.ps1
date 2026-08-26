[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ApkPath,

    [string] $ExpectedAbi = 'arm64-v8a'
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
    "lib/$ExpectedAbi/libapp.so" = 1MB
    "lib/$ExpectedAbi/libflutter.so" = 5MB
    "lib/$ExpectedAbi/libmpv.so" = 10MB
    "lib/$ExpectedAbi/libijkffmpeg.so" = 1MB
    "lib/$ExpectedAbi/libffmpegkit.so" = 20MB
    "lib/$ExpectedAbi/libsqlite3.so" = 512KB
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

    Write-Host "Android APK integrity passed: ABI=$ExpectedAbi, Flutter assets=$($flutterAssets.Count), asset bytes=$flutterAssetBytes"
} finally {
    $archive.Dispose()
}
