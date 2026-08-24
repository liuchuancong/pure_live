[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
    'BUILD_POLICY.md',
    '.agents\skills\pure-live-build\SKILL.md',
    'tool\build_resource_guard.ps1',
    'tool\local_ci.ps1',
    'tool\build_local_release.ps1',
    'android\gradle.properties'
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relativePath) -PathType Leaf)) {
        throw "Build policy file is missing: $relativePath"
    }
}

$skillText = Get-Content -LiteralPath (Join-Path $repoRoot '.agents\skills\pure-live-build\SKILL.md') -Raw
if ($skillText -notmatch '(?s)^---\s*\r?\nname:\s*pure-live-build\s*\r?\ndescription:\s*.+?\r?\n---') {
    throw 'Pure Live build skill frontmatter is incomplete.'
}

$powerShellFiles = @(
    'tool\build_resource_guard.ps1',
    'tool\local_ci.ps1',
    'tool\build_local_release.ps1',
    'tool\flutterw.ps1',
    'tool\validate_build_policy.ps1'
)
foreach ($relativePath in $powerShellFiles) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $repoRoot $relativePath),
        [ref] $tokens,
        [ref] $parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        $details = ($parseErrors | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }) -join '; '
        throw "PowerShell parse error in ${relativePath}: $details"
    }
}

$properties = @{}
foreach ($line in Get-Content -LiteralPath (Join-Path $repoRoot 'android\gradle.properties')) {
    if ($line -match '^([^#!][^=]+)=(.*)$') {
        $properties[$Matches[1].Trim()] = $Matches[2].Trim()
    }
}
$requiredGradle = [ordered]@{
    'org.gradle.daemon' = 'true'
    'org.gradle.parallel' = 'true'
    'org.gradle.caching' = 'true'
    'org.gradle.configuration-cache' = 'true'
    'org.gradle.configuration-cache.problems' = 'fail'
    'org.gradle.vfs.watch' = 'true'
    'org.gradle.workers.max' = '16'
    'kotlin.incremental' = 'true'
}
foreach ($entry in $requiredGradle.GetEnumerator()) {
    if ($properties[$entry.Key] -ne $entry.Value) {
        throw "Gradle policy mismatch: $($entry.Key)=$($properties[$entry.Key])"
    }
}
if ($properties['org.gradle.jvmargs'] -notmatch '-Xmx6g' -or
    $properties['org.gradle.jvmargs'] -notmatch 'MaxMetaspaceSize=1g' -or
    $properties['org.gradle.jvmargs'] -notmatch 'UseParallelGC') {
    throw 'Gradle JVM policy must use 6 GiB heap, 1 GiB Metaspace and Parallel GC.'
}
if ($properties['kotlin.daemon.jvmargs'] -notmatch '-Xmx4g') {
    throw 'Kotlin daemon policy must use a 4 GiB heap.'
}

$androidAppBuild = Get-Content -LiteralPath (Join-Path $repoRoot 'android\app\build.gradle.kts') -Raw
foreach ($marker in @(
    'it.name.contains("flutter", ignoreCase = true)',
    'it.name.startsWith("assemble")',
    'notCompatibleWithConfigurationCache('
)) {
    if (-not $androidAppBuild.Contains($marker)) {
        throw "Android Flutter configuration-cache compatibility marker is missing: $marker"
    }
}

$buildScript = Get-Content -LiteralPath (Join-Path $repoRoot 'tool\build_local_release.ps1') -Raw
foreach ($marker in @(
    "[ValidateSet('AndroidArm64', 'WindowsX64')]",
    "[ValidateSet('Debug', 'Release')]",
    '$gradleWorkers = if ($DedicatedBuild) { 20 } else { 16 }',
    'Enter-PureLiveHeavyTaskSlot',
    'Invoke-PureLiveLoggedFlutter',
    '[Parameter(Mandatory = $true)][int] $ExitCode',
    'PSNativeCommandUseErrorActionPreference',
    'PureLive-$artifactVersion-android-arm64-v8a-release.apk',
    '/DArtifactVersion=$artifactVersion',
    'automatic_follow_up = $false'
)) {
    if (-not $buildScript.Contains($marker)) { throw "Build script policy marker is missing: $marker" }
}

$flutterWrapper = Get-Content -LiteralPath (Join-Path $repoRoot 'tool\flutterw.ps1') -Raw
foreach ($marker in @(
    'PSNativeCommandUseErrorActionPreference',
    '$ErrorActionPreference = ''Continue''',
    '$flutterExitCode = $LASTEXITCODE'
)) {
    if (-not $flutterWrapper.Contains($marker)) {
        throw "Flutter wrapper native-process guard is missing: $marker"
    }
}
if ($buildScript -match '--no-daemon' -or
    $buildScript -match 'org\.gradle\.daemon=false' -or
    $buildScript -match 'org\.gradle\.vfs\.watch=false') {
    throw 'Build script disables a required Gradle reuse feature.'
}

$qualityScript = Get-Content -LiteralPath (Join-Path $repoRoot 'tool\local_ci.ps1') -Raw
foreach ($marker in @("[ValidateSet('Focused', 'Full')]", '[int] $TestConcurrency = 12', 'Enter-PureLiveHeavyTaskSlot')) {
    if (-not $qualityScript.Contains($marker)) { throw "Quality script policy marker is missing: $marker" }
}
if ([regex]::Matches($qualityScript, [regex]::Escape('& $flutterw analyze')).Count -ne 1) {
    throw 'Quality script must contain exactly one Flutter Analyze invocation.'
}

$featureWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\feature-build.yml') -Raw
if ([regex]::Matches($featureWorkflow, '(?m)^\s+default:\s+true\s*$').Count -ne 0) {
    throw 'Feature workflow platform/release inputs must default to false.'
}
if ($featureWorkflow -match 'stage-build-' -or $featureWorkflow -match 'stage-apple-') {
    throw 'Feature workflow must use precise single-platform stage tags.'
}
foreach ($marker in @(
    'needs: [quality, android]',
    'needs: [quality, windows]',
    'needs: [quality, linux]',
    'cancel-in-progress: false',
    'flutter test --concurrency=12',
    '--target-platform android-arm64',
    'PureLive-${VERSION}-android-arm64-v8a-release.apk',
    'steps.version.outputs.artifact_version',
    'stage-macos-'
)) {
    if (-not $featureWorkflow.Contains($marker)) { throw "Feature workflow policy marker is missing: $marker" }
}

$localAndroidWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\local-signed-android.yml') -Raw
if ($localAndroidWorkflow -match '(?m)^\s+push:\s*$' -or $localAndroidWorkflow -match 'hosted-android') {
    throw 'Local signed Android workflow must stay manual and local-runner only.'
}
foreach ($marker in @('run_full_regression:', "'-SkipQuality'", "'-FullRegression'")) {
    if (-not $localAndroidWorkflow.Contains($marker)) {
        throw "Local Android retry quality marker is missing: $marker"
    }
}

$publisherWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\publish-staged-release.yml') -Raw
foreach ($marker in @(
    'name: pure-live-ios',
    'ios-arm64-trollstore.ipa',
    'Verify Android release signature',
    'certificate SHA-256 digest'
)) {
    if (-not $publisherWorkflow.Contains($marker)) {
        throw "Staged publisher verification marker is missing: $marker"
    }
}

Write-Host 'Build policy static validation passed.'
