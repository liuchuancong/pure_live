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
