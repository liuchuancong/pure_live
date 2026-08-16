[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $repoRoot 'build\media_kit_libs_android_video\v1.2.7'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$assets = @(
    @{ Name = 'default-arm64-v8a.jar'; Sha256 = '13e882d96b8cd235425172b022e4a94dfcae5f07985dff85c8d648e7369fa2d1' }
)
$baseUrl = 'https://github.com/Predidit/libmpv-android-video-build/releases/download/v1.2.7'

foreach ($asset in $assets) {
    $path = Join-Path $destination $asset.Name
    $valid = (Test-Path -LiteralPath $path) -and
        ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -eq $asset.Sha256)
    if (-not $valid) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
        & curl.exe -L --fail --retry 10 --retry-all-errors --continue-at - --output $path "$baseUrl/$($asset.Name)"
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $asset.Sha256) {
        Remove-Item -LiteralPath $path -Force
        throw "SHA-256 mismatch for $($asset.Name)"
    }
    Write-Host "Verified $($asset.Name)"
}

# The ffmpeg_kit build hook uses Dart HttpClient, which may stall on GitHub's
# release-asset redirect on some Windows networks. Seed its deterministic
# shared cache with curl so Android builds remain resumable and observable.
$ffmpegCache = Join-Path $repoRoot '.dart_tool\hooks_runner\shared\ffmpeg_kit_extended_flutter\build\ffmpeg_kit_cache\android'
$ffmpegName = 'bundle-base-shared-lgpl-release.aar'
$ffmpegPath = Join-Path $ffmpegCache $ffmpegName
$ffmpegPartial = "$ffmpegPath.partial"
$ffmpegSha256 = 'c3cc680706a24669a41cb078f2d9983aac3d17188ebef1db50c73b388471000d'
$ffmpegUrl = "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/v0.10.5-android/$ffmpegName"
New-Item -ItemType Directory -Force -Path $ffmpegCache | Out-Null
$ffmpegValid = (Test-Path -LiteralPath $ffmpegPath) -and
    ((Get-FileHash -LiteralPath $ffmpegPath -Algorithm SHA256).Hash.ToLowerInvariant() -eq $ffmpegSha256)
if (-not $ffmpegValid) {
    Remove-Item -LiteralPath $ffmpegPath,$ffmpegPartial -Force -ErrorAction SilentlyContinue
    & curl.exe -L --fail --retry 10 --retry-all-errors --continue-at - --output $ffmpegPartial $ffmpegUrl
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    $actual = (Get-FileHash -LiteralPath $ffmpegPartial -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ffmpegSha256) {
        Remove-Item -LiteralPath $ffmpegPartial -Force
        throw "SHA-256 mismatch for $ffmpegName"
    }
    Move-Item -LiteralPath $ffmpegPartial -Destination $ffmpegPath -Force
}
Write-Host "Verified $ffmpegName"
