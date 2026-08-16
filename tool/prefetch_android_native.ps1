[CmdletBinding()]
param()

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

$mediaKitName = 'default-arm64-v8a.jar'
Install-VerifiedAsset `
    -Name $mediaKitName `
    -Destination (Join-Path $repoRoot "build\media_kit_libs_android_video\v1.2.7\$mediaKitName") `
    -CachePath (Join-Path $persistentRoot "media-kit\v1.2.7\$mediaKitName") `
    -Url "https://github.com/Predidit/libmpv-android-video-build/releases/download/v1.2.7/$mediaKitName" `
    -Sha256 '13e882d96b8cd235425172b022e4a94dfcae5f07985dff85c8d648e7369fa2d1'

# The ffmpeg_kit build hook uses Dart HttpClient, which may stall on GitHub's
# release-asset redirect on some Windows networks. Seed its deterministic
# shared cache from a verified machine cache before invoking Flutter.
$ffmpegName = 'bundle-base-shared-lgpl-release.aar'
Install-VerifiedAsset `
    -Name $ffmpegName `
    -Destination (Join-Path $repoRoot ".dart_tool\hooks_runner\shared\ffmpeg_kit_extended_flutter\build\ffmpeg_kit_cache\android\$ffmpegName") `
    -CachePath (Join-Path $persistentRoot "ffmpeg-kit\v0.10.5-android\$ffmpegName") `
    -Url "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/v0.10.5-android/$ffmpegName" `
    -Sha256 'c3cc680706a24669a41cb078f2d9983aac3d17188ebef1db50c73b388471000d'
