[CmdletBinding()]
param(
    [string] $BuildDirectory = 'build\windows\x64'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$packageConfigPath = Join-Path $repoRoot '.dart_tool\package_config.json'
if (-not (Test-Path -LiteralPath $packageConfigPath -PathType Leaf)) {
    throw 'Run flutter pub get before prefetching Windows native dependencies.'
}

$packageConfig = Get-Content -LiteralPath $packageConfigPath -Raw | ConvertFrom-Json
$firebasePackage = @($packageConfig.packages | Where-Object name -eq 'firebase_core') | Select-Object -First 1
if (-not $firebasePackage) {
    throw 'firebase_core is missing from .dart_tool/package_config.json.'
}

$firebaseRootUri = [Uri]$firebasePackage.rootUri
if (-not $firebaseRootUri.IsAbsoluteUri -or -not $firebaseRootUri.IsFile) {
    throw "firebase_core has an unsupported package URI: $($firebasePackage.rootUri)"
}
$firebaseRoot = $firebaseRootUri.LocalPath
$firebaseCmake = Join-Path $firebaseRoot 'windows\CMakeLists.txt'
$firebaseCmakeText = Get-Content -LiteralPath $firebaseCmake -Raw
if ($firebaseCmakeText -notmatch 'set\(FIREBASE_SDK_VERSION\s+"([0-9]+\.[0-9]+\.[0-9]+)"\)') {
    throw 'Firebase C++ SDK version was not found in firebase_core/windows/CMakeLists.txt.'
}

$sdkVersion = $Matches[1]
$archiveName = "firebase_cpp_sdk_windows_$sdkVersion.zip"
$downloadUrl = "https://dl.google.com/firebase/sdk/cpp/$archiveName"
$cacheBase = if ($env:PURE_LIVE_NATIVE_CACHE) {
    $env:PURE_LIVE_NATIVE_CACHE
} else {
    Join-Path $env:LOCALAPPDATA 'PureLive\native-cache'
}
$cacheRoot = Join-Path $cacheBase 'firebase-cpp-windows'
$archivePath = Join-Path $cacheRoot $archiveName
$partialPath = "$archivePath.partial"
$sdkContainer = Join-Path $cacheRoot "sdk-$sdkVersion"
$sdkRoot = Join-Path $sdkContainer 'firebase_cpp_sdk_windows'
$versionHeader = Join-Path $sdkRoot 'include\firebase\version.h'
$legacyArchive = Join-Path (Join-Path $repoRoot $BuildDirectory) $archiveName

New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

function Get-FirebaseSdkVersion {
    param([Parameter(Mandatory = $true)][string] $HeaderPath)

    if (-not (Test-Path -LiteralPath $HeaderPath -PathType Leaf)) { return $null }
    $header = Get-Content -LiteralPath $HeaderPath -Raw
    $parts = foreach ($name in @('MAJOR', 'MINOR', 'REVISION')) {
        if ($header -notmatch "#define\s+FIREBASE_VERSION_$name\s+([0-9]+)") { return $null }
        $Matches[1]
    }
    return $parts -join '.'
}

function Test-FirebaseArchive {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][long] $ExpectedLength
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    if ((Get-Item -LiteralPath $Path).Length -ne $ExpectedLength) { return $false }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            return $null -ne ($archive.Entries | Where-Object {
                $_.FullName -eq 'firebase_cpp_sdk_windows/include/firebase/version.h'
            } | Select-Object -First 1)
        } finally {
            $archive.Dispose()
        }
    } catch {
        return $false
    }
}

$headerOutput = (& curl.exe -L --fail --silent --show-error --head `
    --retry 5 --retry-all-errors --connect-timeout 30 $downloadUrl 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) {
    throw "Firebase SDK metadata request failed: $headerOutput"
}
$contentLengths = [regex]::Matches($headerOutput, '(?im)^content-length:\s*([0-9]+)\s*$')
if ($contentLengths.Count -eq 0) {
    throw 'Firebase SDK response did not contain Content-Length.'
}
$expectedLength = [long]$contentLengths[$contentLengths.Count - 1].Groups[1].Value

if (-not (Test-FirebaseArchive -Path $archivePath -ExpectedLength $expectedLength)) {
    if (Test-Path -LiteralPath $archivePath) {
        Rename-Item -LiteralPath $archivePath -NewName "$archiveName.invalid-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))"
    }

    if (Test-Path -LiteralPath $legacyArchive -PathType Leaf) {
        $legacyLength = (Get-Item -LiteralPath $legacyArchive).Length
        $partialLength = if (Test-Path -LiteralPath $partialPath) {
            (Get-Item -LiteralPath $partialPath).Length
        } else {
            0
        }
        if ($legacyLength -gt $partialLength -and $legacyLength -lt $expectedLength) {
            if (Test-Path -LiteralPath $partialPath) {
                Rename-Item -LiteralPath $partialPath -NewName "$archiveName.partial.invalid-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))"
            }
            Move-Item -LiteralPath $legacyArchive -Destination $partialPath
        }
    }

    for ($attempt = 1; $attempt -le 4; $attempt++) {
        $currentLength = if (Test-Path -LiteralPath $partialPath) {
            (Get-Item -LiteralPath $partialPath).Length
        } else {
            0
        }
        Write-Host "Fetching Firebase C++ SDK $sdkVersion ($currentLength/$expectedLength bytes, attempt $attempt/4)..."
        & curl.exe -L --fail --silent --show-error --http1.1 `
            --retry 12 --retry-all-errors --retry-delay 2 --retry-max-time 1800 `
            --connect-timeout 30 --continue-at - --output $partialPath $downloadUrl
        $curlExitCode = $LASTEXITCODE
        $downloadedLength = if (Test-Path -LiteralPath $partialPath) {
            (Get-Item -LiteralPath $partialPath).Length
        } else {
            0
        }
        if ($curlExitCode -eq 0 -and $downloadedLength -eq $expectedLength) { break }
        if ($downloadedLength -gt $expectedLength) {
            throw "Firebase SDK archive exceeded the advertised size: $downloadedLength > $expectedLength."
        }
        if ($attempt -eq 4) {
            throw "Firebase SDK download remained incomplete: $downloadedLength/$expectedLength bytes (curl $curlExitCode)."
        }
    }

    if (-not (Test-FirebaseArchive -Path $partialPath -ExpectedLength $expectedLength)) {
        throw 'Firebase SDK archive failed size or ZIP structure validation.'
    }
    Move-Item -LiteralPath $partialPath -Destination $archivePath
    $archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    "$archiveHash  $archiveName" | Set-Content -LiteralPath "$archivePath.sha256" -Encoding ascii
}

if ((Get-FirebaseSdkVersion -HeaderPath $versionHeader) -ne $sdkVersion) {
    if (Test-Path -LiteralPath $sdkContainer) {
        Rename-Item -LiteralPath $sdkContainer -NewName "sdk-$sdkVersion.invalid-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))"
    }
    $temporaryExtract = Join-Path $cacheRoot "sdk-$sdkVersion.extracting-$PID"
    New-Item -ItemType Directory -Force -Path $temporaryExtract | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $temporaryExtract)
    $temporaryHeader = Join-Path $temporaryExtract 'firebase_cpp_sdk_windows\include\firebase\version.h'
    if ((Get-FirebaseSdkVersion -HeaderPath $temporaryHeader) -ne $sdkVersion) {
        throw "Extracted Firebase SDK does not match $sdkVersion."
    }
    Move-Item -LiteralPath $temporaryExtract -Destination $sdkContainer
}

$env:FIREBASE_CPP_SDK_DIR = $sdkRoot
if ($env:GITHUB_ENV) {
    "FIREBASE_CPP_SDK_DIR=$sdkRoot" | Out-File -LiteralPath $env:GITHUB_ENV -Encoding utf8 -Append
}
Write-Host "Firebase C++ SDK $sdkVersion ready: $sdkRoot"
