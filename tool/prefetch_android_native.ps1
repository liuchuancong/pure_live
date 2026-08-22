[CmdletBinding()]
param(
    # local_ci only needs the Windows Native Assets archive used by the
    # ffmpeg_kit build hook. Release builds leave this switch unset and also
    # prefetch the Android media-kit/FFmpeg artifacts.
    [switch] $SkipAndroidMedia
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$persistentRoot = if ($env:PURE_LIVE_NATIVE_CACHE) {
    $env:PURE_LIVE_NATIVE_CACHE
} elseif ($env:RUNNER_TOOL_CACHE) {
    Join-Path $env:RUNNER_TOOL_CACHE 'pure-live-native'
} else {
    Join-Path $env:LOCALAPPDATA 'PureLive\native-cache'
}

function Test-VerifiedFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Sha256
    )
    return (Test-Path -LiteralPath $Path) -and
        ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -eq $Sha256)
}

function Install-VerifiedAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$CachePath,
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Sha256
    )

    if (Test-VerifiedFile -Path $Destination -Sha256 $Sha256) {
        Write-Host "Verified $Name"
        return
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $CachePath) | Out-Null

    if (-not (Test-VerifiedFile -Path $CachePath -Sha256 $Sha256)) {
        $partial = "$CachePath.partial"
        Remove-Item -LiteralPath $CachePath,$partial -Force -ErrorAction SilentlyContinue
        & curl.exe -L --fail --retry 10 --retry-all-errors --connect-timeout 20 `
            --max-time 600 --continue-at - --output $partial $Url
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
        if (-not (Test-VerifiedFile -Path $partial -Sha256 $Sha256)) {
            Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
            throw "SHA-256 mismatch for $Name"
        }
        Move-Item -LiteralPath $partial -Destination $CachePath -Force
    }

    Copy-Item -LiteralPath $CachePath -Destination $Destination -Force
    if (-not (Test-VerifiedFile -Path $Destination -Sha256 $Sha256)) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw "SHA-256 mismatch after installing $Name"
    }
    Write-Host "Verified $Name (persistent cache: $persistentRoot)"
}

if (-not $SkipAndroidMedia) {
    $mediaKitAssets = @(
        @{ Name = 'default-arm64-v8a.jar'; Sha256 = '13e882d96b8cd235425172b022e4a94dfcae5f07985dff85c8d648e7369fa2d1' },
        @{ Name = 'default-armeabi-v7a.jar'; Sha256 = '7f522ed762ea6dfeba93a02e3837c5538790030b9965a03ed3a00276adc7b32c' },
        @{ Name = 'default-x86_64.jar'; Sha256 = 'aed0fffc99e5e554d48e1af90bc700133c25fbc02615bf1bf17db9299365c481' },
        @{ Name = 'default-x86.jar'; Sha256 = '9269643264a1c9689116467f313d5e1b23ea56a68d338ab940c5e8fcf07061c6' }
    )
    foreach ($asset in $mediaKitAssets) {
        Install-VerifiedAsset `
            -Name $asset.Name `
            -Destination (Join-Path $repoRoot "build\media_kit_libs_android_video\v1.2.7\$($asset.Name)") `
            -CachePath (Join-Path $persistentRoot "media-kit\v1.2.7\$($asset.Name)") `
            -Url "https://github.com/Predidit/libmpv-android-video-build/releases/download/v1.2.7/$($asset.Name)" `
            -Sha256 $asset.Sha256
    }

    $ffmpegAndroidName = 'bundle-base-shared-lgpl-release.aar'
    Install-VerifiedAsset `
        -Name $ffmpegAndroidName `
        -Destination (Join-Path $repoRoot ".dart_tool\hooks_runner\shared\ffmpeg_kit_extended_flutter\build\ffmpeg_kit_cache\android\$ffmpegAndroidName") `
        -CachePath (Join-Path $persistentRoot "ffmpeg-kit\v0.11.0-android\$ffmpegAndroidName") `
        -Url "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/v0.11.0-android/$ffmpegAndroidName" `
        -Sha256 '2b66caaaefbe5032ffe6e32d87e1af398653ec8dbbc193f4481dd4f562f2182d'
}

# The ffmpeg_kit Native Assets hook uses Dart HttpClient, which may stall on a
# GitHub release-asset redirect on some Windows networks. Seed both platform
# caches from verified persistent files before invoking Flutter. The checksums
# match the v0.11.0 builder release used by ffmpeg_kit_extended_flutter 0.6.0.
$ffmpegWindowsName = 'bundle-base-windows-x86_64-shared-lgpl.zip'
Install-VerifiedAsset `
    -Name $ffmpegWindowsName `
    -Destination (Join-Path $repoRoot ".dart_tool\hooks_runner\shared\ffmpeg_kit_extended_flutter\build\ffmpeg_kit_cache\windows\$ffmpegWindowsName") `
    -CachePath (Join-Path $persistentRoot "ffmpeg-kit\v0.11.0-windows\$ffmpegWindowsName") `
    -Url "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/v0.11.0-windows/$ffmpegWindowsName" `
    -Sha256 '2367fbc6ecd7c5df1995c5c0cf5d95f65a99396d4d3fe9d1968c683d3481c125'
