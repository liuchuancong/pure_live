[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
    'BUILD_POLICY.md',
    'MAINTENANCE_POLICY.md',
    'UPSTREAM_REVIEW_POLICY.md',
    '.agents\skills\pure-live-build\SKILL.md',
    '.agents\skills\pure-live-maintenance\SKILL.md',
    '.github\ISSUE_TEMPLATE\bug_report.yml',
    '.github\ISSUE_TEMPLATE\config.yml',
    '.github\pull_request_template.md',
    'docs\BUG_TRIAGE_TEMPLATE.md',
    'docs\UPSTREAM_AUDIT_TEMPLATE.md',
    'tool\build_resource_guard.ps1',
    'tool\review_upstream_update.ps1',
    'tool\audit_repository.py',
    '.github\workflows\audit-upstream.yml',
    'tool\local_ci.ps1',
    'tool\build_local_release.ps1',
    'tool\verify_android_apk.ps1',
    'tool\publish_local_release.ps1',
    'tool\prefetch_windows_native.ps1',
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

$maintenanceSkillText = Get-Content -LiteralPath (Join-Path $repoRoot '.agents\skills\pure-live-maintenance\SKILL.md') -Raw
if ($maintenanceSkillText -notmatch '(?s)^---\s*\r?\nname:\s*pure-live-maintenance\s*\r?\ndescription:\s*.+?\r?\n---') {
    throw 'Pure Live maintenance skill frontmatter is incomplete.'
}
foreach ($marker in @('MAINTENANCE_POLICY.md', 'bug-provenance', 'semantic change ledger')) {
    if (-not $maintenanceSkillText.Contains($marker)) {
        throw "Pure Live maintenance skill marker is missing: $marker"
    }
}
if (-not $skillText.Contains('bugfix-android-release-default')) {
    throw 'Pure Live build skill must preserve the default Android Bug-fix release closure.'
}
if (-not $maintenanceSkillText.Contains('bugfix-android-release-default')) {
    throw 'Pure Live maintenance skill must preserve the default Android Bug-fix release closure.'
}

$buildPolicyText = Get-Content -LiteralPath (Join-Path $repoRoot 'BUILD_POLICY.md') -Raw
foreach ($marker in @('bugfix-android-release-default', 'local-build-first', 'github-secret-signing', 'serial-platform-stages', 'sign-staged-android', 'assets/releases.json')) {
    if (-not $buildPolicyText.Contains($marker)) {
        throw "Build policy delivery marker is missing: $marker"
    }
}

$maintenancePolicy = Get-Content -LiteralPath (Join-Path $repoRoot 'MAINTENANCE_POLICY.md') -Raw
foreach ($marker in @(
    'android-first',
    'windows-maintained',
    'feature-requests-upstream',
    'bug-provenance-required',
    'semantic-change-ledger',
    'evidence-layered',
    'rollback-required',
    'bugfix-android-release-default',
    'upstream-existing',
    'fork-regression',
    'integration-conflict',
    'external-drift',
    'environment-or-data',
    'not-reproduced',
    'accept',
    'adapt',
    'rewrite',
    'drop',
    'defer'
)) {
    if (-not $maintenancePolicy.Contains($marker)) {
        throw "Maintenance policy marker is missing: $marker"
    }
}

$featureRequestTemplate = Join-Path $repoRoot '.github\ISSUE_TEMPLATE\feature_request.yml'
if (Test-Path -LiteralPath $featureRequestTemplate) {
    throw 'Feature requests must route to the upstream project instead of a local Issue form.'
}
$issueConfig = Get-Content -LiteralPath (Join-Path $repoRoot '.github\ISSUE_TEMPLATE\config.yml') -Raw
$bugTemplate = Get-Content -LiteralPath (Join-Path $repoRoot '.github\ISSUE_TEMPLATE\bug_report.yml') -Raw
$pullRequestTemplate = Get-Content -LiteralPath (Join-Path $repoRoot '.github\pull_request_template.md') -Raw
if (-not $issueConfig.Contains('https://github.com/liuchuancong/pure_live/issues/new/choose')) {
    throw 'Issue configuration must route feature requests to the upstream project.'
}
foreach ($marker in @('maintenance-bug-only', 'upstream-comparison', 'community-verified', 'upstream_comparison', 'last_working')) {
    if (-not $bugTemplate.Contains($marker)) {
        throw "Bug report triage marker is missing: $marker"
    }
}
foreach ($marker in @('bug-provenance', 'semantic-audit', 'impact-matrix', 'evidence-layered', 'rollback', 'semantic_change_ledger', 'fork_feature_impact', 'quality_assessment', 'disposition')) {
    if (-not $pullRequestTemplate.Contains($marker)) {
        throw "Pull Request maintenance marker is missing: $marker"
    }
}

$readmeText = Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw
$contributingText = Get-Content -LiteralPath (Join-Path $repoRoot 'CONTRIBUTING.md') -Raw
$agentText = Get-Content -LiteralPath (Join-Path $repoRoot 'AGENTS.md') -Raw
$upstreamAuditTemplate = Get-Content -LiteralPath (Join-Path $repoRoot 'docs\UPSTREAM_AUDIT_TEMPLATE.md') -Raw
foreach ($entry in @(
    [pscustomobject]@{ Name = 'README'; Text = $readmeText; Markers = @('maintenance-readme-markers', 'android-first', 'windows-maintained', 'upstream-feature-routing', 'bugfix-release-default', 'MAINTENANCE_POLICY.md', 'issues/new/choose') },
    [pscustomobject]@{ Name = 'CONTRIBUTING'; Text = $contributingText; Markers = @('contribution-policy-markers', 'maintenance-bug-only', 'bug-triage', 'upstream-review', 'feature-routing', 'integration-conflict') },
    [pscustomobject]@{ Name = 'AGENTS'; Text = $agentText; Markers = @('Maintenance scope and triage', 'MAINTENANCE_POLICY.md', 'not-reproduced', 'bugfix-android-release-default') },
    [pscustomobject]@{ Name = 'upstream audit template'; Text = $upstreamAuditTemplate; Markers = @('file_review', 'semantic_change_ledger', 'issue_and_bug_mapping', 'fork_feature_impact', 'quality_assessment', 'disposition', 'conflict_resolution', 'regression_plan', 'verification_plan') }
)) {
    foreach ($marker in $entry.Markers) {
        if (-not $entry.Text.Contains($marker)) {
            throw "$($entry.Name) maintenance marker is missing: $marker"
        }
    }
}

$powerShellFiles = @(
    'tool\build_resource_guard.ps1',
    'tool\local_ci.ps1',
    'tool\build_local_release.ps1',
    'tool\verify_android_apk.ps1',
    'tool\publish_local_release.ps1',
    'tool\prefetch_windows_native.ps1',
    'tool\flutterw.ps1',
    'tool\android_ui.ps1',
    'tool\review_upstream_update.ps1',
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

# ADB options such as `-p`, `-n` and `-f` overlap PowerShell common-parameter
# abbreviations. Keep every wrapper invocation array-shaped so device evidence
# capture cannot mask the original UI failure with a parameter-binding error.
$androidUiPath = Join-Path $repoRoot 'tool\android_ui.ps1'
$tokens = $null
$parseErrors = $null
$androidUiAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $androidUiPath,
    [ref] $tokens,
    [ref] $parseErrors
)
$adbCalls = @(
    $androidUiAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Invoke-Adb'
    }, $true)
)
$positionalAdbCalls = @($adbCalls | Where-Object { $_.Extent.Text -notmatch '-AdbArguments' })
if ($positionalAdbCalls.Count -gt 0) {
    $lines = ($positionalAdbCalls | ForEach-Object { $_.Extent.StartLineNumber }) -join ', '
    throw "android_ui.ps1 must pass ADB arguments through -AdbArguments arrays (lines: $lines)."
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
if ($androidAppBuild -notmatch '(?m)^\s*minSdk\s*=\s*26\s*$') {
    throw 'Android minSdk must match the FFmpegKit native API 26 floor.'
}
$androidManifest = Get-Content -LiteralPath (Join-Path $repoRoot 'android\app\src\main\AndroidManifest.xml') -Raw
if ($androidManifest -match 'overrideLibrary="com\.akashskypatel\.ffmpeg_kit_extended_flutter"') {
    throw 'Android manifest must not bypass the FFmpegKit native minSdk requirement.'
}
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
    "Join-Path `$PSScriptRoot 'verify_android_apk.ps1'",
    "'--target-platform', 'android-arm64',",
    "'--no-pub',",
    "Join-Path `$PSScriptRoot 'prefetch_windows_native.ps1'",
    '/DArtifactVersion=$artifactVersion',
    'build\windows\x64\install_manifest.txt',
    '$manifestSourceMarker = "\build\windows\x64\runner\$configurationDirectory\"',
    'Keep dependency resolution single-owner',
    'Retired QuickJS runtime files appeared in the Windows package',
    'automatic_follow_up = $false'
)) {
    if (-not $buildScript.Contains($marker)) { throw "Build script policy marker is missing: $marker" }
}

$windowsInstaller = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\packaging\exe\local_release.iss') -Raw
foreach ($marker in @(
    '[InstallDelete]',
    'Type: filesandordirs; Name: "{app}\data"',
    'Type: files; Name: "{app}\*.dll"',
    'Name: "{app}\AppData"; Flags: uninsneveruninstall'
)) {
    if (-not $windowsInstaller.Contains($marker)) {
        throw "Windows installer upgrade-cleanup marker is missing: $marker"
    }
}

$windowsFlutterRunner = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\runner\flutter_window.cpp') -Raw
if ($windowsFlutterRunner -notmatch '(?s)FlutterWindow::~FlutterWindow\(\)\s*\{.*?Destroy\(\);.*?\}') {
    throw 'Windows FlutterWindow must destroy its child controller while derived teardown guards are still alive.'
}
foreach ($marker in @(
    'flutter_controller_destroying_ = true;',
    'flutter_controller_.reset();',
    'flutter_controller_ && !flutter_controller_destroying_'
)) {
    if (-not $windowsFlutterRunner.Contains($marker)) {
        throw "Windows Flutter controller teardown guard is missing: $marker"
    }
}

$androidVerifier = Get-Content -LiteralPath (Join-Path $repoRoot 'tool\verify_android_apk.ps1') -Raw
foreach ($marker in @(
    'assets/flutter_assets/AssetManifest.bin',
    'assets/flutter_assets/assets/version.json',
    'libffmpegkit.so',
    'libsqlite3.so',
    '$flutterAssets.Count -lt 1000',
    'verify_android_elf_alignment.ps1',
    'zipalign.exe',
    '-P 16'
)) {
    if (-not $androidVerifier.Contains($marker)) {
        throw "Android APK integrity marker is missing: $marker"
    }
}

$androidElfVerifier = Get-Content -LiteralPath (Join-Path $repoRoot 'tool\verify_android_elf_alignment.ps1') -Raw
foreach ($marker in @(
    'llvm-readelf.exe',
    'minimum LOAD alignment',
    'MinimumLoadAlignment = 0x4000'
)) {
    if (-not $androidElfVerifier.Contains($marker)) {
        throw "Android 16 KB ELF verifier marker is missing: $marker"
    }
}

$fplayerPluginBuildPath = Join-Path $repoRoot 'plugins\flv_lzc\android\build.gradle'
$fplayerPluginBuild = Get-Content -LiteralPath $fplayerPluginBuildPath -Raw
$androidRootBuild = Get-Content -LiteralPath (Join-Path $repoRoot 'android\build.gradle.kts') -Raw
$fplayerCoreVersion = '1.0.4-purelive16k'
$fplayerCoreRelativePath =
    "plugins\flv_lzc\android\libs\io\github\flutterplayer\fplayer-core\$fplayerCoreVersion\fplayer-core-$fplayerCoreVersion.aar"
$fplayerCorePath = Join-Path $repoRoot $fplayerCoreRelativePath
foreach ($marker in @(
    'url = uri("$projectDir/libs")',
    'includeModule("io.github.flutterplayer", "fplayer-core")',
    "io.github.flutterplayer:fplayer-core:$fplayerCoreVersion"
)) {
    if (-not $fplayerPluginBuild.Contains($marker)) {
        throw "Local 16 KB fplayer dependency marker is missing: $marker"
    }
}
foreach ($marker in @(
    'maven(rootProject.file("../plugins/flv_lzc/android/libs"))',
    'includeModule("io.github.flutterplayer", "fplayer-core")'
)) {
    if (-not $androidRootBuild.Contains($marker)) {
        throw "Android app local fplayer repository marker is missing: $marker"
    }
}
if ($fplayerPluginBuild.Contains("io.github.flutterplayer:fplayer-core:1.0.4'")) {
    throw 'The 4 KB-aligned Maven fplayer-core 1.0.4 artifact must not be restored.'
}
if (-not (Test-Path -LiteralPath $fplayerCorePath -PathType Leaf)) {
    throw "Local 16 KB fplayer AAR is missing: $fplayerCoreRelativePath"
}
$expectedFplayerCoreHash = '3643B36BC906F1FED56B313AC98669EEAA9DA0D2262409808429C5B614C676DA'
$actualFplayerCoreHash = (Get-FileHash -LiteralPath $fplayerCorePath -Algorithm SHA256).Hash
if ($actualFplayerCoreHash -ne $expectedFplayerCoreHash) {
    throw "Local 16 KB fplayer AAR hash mismatch: $actualFplayerCoreHash"
}

$androidSigningWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\sign-staged-android.yml') -Raw
foreach ($marker in @(
    'assets/flutter_assets/AssetManifest.bin',
    'assets/flutter_assets/assets/version.json',
    'libffmpegkit.so',
    'libsqlite3.so',
    'Flutter asset file count is incomplete',
    'verify_android_16kb',
    'zipalign" -c -P 16 4',
    'Android 16 KB ELF alignment failed',
    'verify_android_16kb "$final_apk"'
)) {
    if (-not $androidSigningWorkflow.Contains($marker)) {
        throw "Android signing workflow integrity marker is missing: $marker"
    }
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

$publishScript = Get-Content -LiteralPath (Join-Path $repoRoot 'tool\publish_local_release.ps1') -Raw
foreach ($marker in @(
    'ReplaceExistingRelease',
    'gh release delete-asset',
    'gh release edit $Tag --draft',
    'git push --force origin "refs/tags/$Tag"'
)) {
    if (-not $publishScript.Contains($marker)) {
        throw "Corrected-release replacement marker is missing: $marker"
    }
}

$qualityScript = Get-Content -LiteralPath (Join-Path $repoRoot 'tool\local_ci.ps1') -Raw
foreach ($marker in @("[ValidateSet('Focused', 'Full')]", '[int] $TestConcurrency = 12', 'Enter-PureLiveHeavyTaskSlot')) {
    if (-not $qualityScript.Contains($marker)) { throw "Quality script policy marker is missing: $marker" }
}
if (-not $qualityScript.Contains("audit_repository.py') --output `$repositoryAuditPath")) {
    throw 'Quality gate must run the whole-repository audit.'
}
if ([regex]::Matches($qualityScript, [regex]::Escape('& $flutterw analyze')).Count -ne 1) {
    throw 'Quality script must contain exactly one Flutter Analyze invocation.'
}

$featureWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\feature-build.yml') -Raw
if ([regex]::Matches($featureWorkflow, '(?m)^\s+default:\s+true\s*$').Count -ne 0) {
    throw 'Feature workflow platform/release inputs must default to false.'
}

$allPlatformWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\build_pure_live_release.yml') -Raw
if ([regex]::Matches($allPlatformWorkflow, '(?m)^\s+default:\s+true\s*$').Count -ne 0) {
    throw 'All-platform workflow platform/release inputs must default to false.'
}
foreach ($workflowText in @($featureWorkflow, $allPlatformWorkflow)) {
    foreach ($marker in @('choco install innosetup --version=6.7.1', 'dart pub global activate fastforge 0.6.0')) {
        if (-not $workflowText.Contains($marker)) {
            throw "Windows packaging dependency is not pinned: $marker"
        }
    }
    if ($workflowText.Contains('git clone https://github.com/SlotSun/fastforge.git')) {
        throw 'Windows workflow must not install Fastforge from a mutable branch.'
    }
}
foreach ($marker in @(
    'needs: [quality, android]',
    'needs: [quality, android, windows]',
    'needs: [quality, android, windows, linux]',
    "needs.android.result == 'success'",
    "needs.windows.result == 'success'",
    "needs.linux.result == 'success'"
)) {
    if (-not $allPlatformWorkflow.Contains($marker)) {
        throw "All-platform workflow is missing serial-stage marker: $marker"
    }
}

$upstreamPolicy = Get-Content -LiteralPath (Join-Path $repoRoot 'UPSTREAM_REVIEW_POLICY.md') -Raw
$upstreamReviewScript = Get-Content -LiteralPath (Join-Path $repoRoot 'tool\review_upstream_update.ps1') -Raw
$upstreamAuditWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\audit-upstream.yml') -Raw
foreach ($marker in @(
    'review_upstream_update.ps1',
    'normal-live-layout-visible',
    'manual-workflow-defaults-off',
    'semantic-change-ledger',
    'fork-feature-impact',
    'disposition-required',
    'bug-provenance-required'
)) {
    if (-not $upstreamPolicy.Contains($marker)) {
        throw "Upstream review policy marker is missing: $marker"
    }
}
foreach ($marker in @(
    'ApproveHighRisk',
    'ReportOnly',
    "@('merge-base', `$baseSha, `$upstreamSha)",
    'incoming_range',
    'audit_document_valid',
    'audit_document_required_markers',
    'audit_document_missing_commits',
    'audit_document_missing_files',
    'semantic_change_ledger',
    'issue_and_bug_mapping',
    'fork_feature_impact',
    'quality_assessment',
    'disposition',
    'regression_plan',
    'credential_material_in_added_lines'
)) {
    if (-not $upstreamReviewScript.Contains($marker)) {
        throw "Upstream review script marker is missing: $marker"
    }
}
foreach ($marker in @('workflow_dispatch:', 'fetch-depth: 0', '-ReportOnly', 'audit_repository.py', 'contents: read')) {
    if (-not $upstreamAuditWorkflow.Contains($marker)) {
        throw "Upstream audit workflow is missing required marker: $marker"
    }
}

$repositoryAuditScript = Get-Content -LiteralPath (Join-Path $repoRoot 'tool\audit_repository.py') -Raw
foreach ($marker in @(
    'mutable_action_reference',
    'mutable_git_dependency',
    'predictive_back_disabled',
    'global_back_interceptor_forbidden',
    'live_back_invariant_missing',
    'untracked_file_count',
    'mutable_git_clone',
    'unlocked_workflow_pub_get'
)) {
    if (-not $repositoryAuditScript.Contains($marker)) {
        throw "Whole-repository audit marker is missing: $marker"
    }
}

$androidManifest = Get-Content -LiteralPath (Join-Path $repoRoot 'android\app\src\main\AndroidManifest.xml') -Raw
if ($androidManifest -match 'enableOnBackInvokedCallback="false"') {
    throw 'Android predictive back must not be disabled.'
}
$livePage = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\modules\live_play\pages\live_play_page.dart') -Raw
$liveController = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\modules\live_play\controllers\live_play_controller.dart') -Raw
if (-not $livePage.Contains('LivePlayBackScope(') -or -not $liveController.Contains('exitPresentationForSystemBack')) {
    throw 'Live room route-local back handling is missing.'
}
if ($liveController.Contains('BackButtonInterceptor') -or $liveController.Contains('clearListener();`r`n    return false')) {
    throw 'Live room must not use the legacy global back interceptor or pre-pop listener teardown.'
}

$generalSettings = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\modules\settings\pages\general_settings_page.dart') -Raw
if (-not $generalSettings.Contains('Platform.isAndroid || Platform.isWindows') -or
    -not $generalSettings.Contains('_showRefreshRateModeDialog(context)')) {
    throw 'Android and Windows must both expose the shared refresh-rate policy.'
}
$backupPage = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\modules\backup\backup_page.dart') -Raw
$fileUtils = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\plugins\file_utils.dart') -Raw
if (-not $backupPage.Contains('LogFileWriter.resolveLogDirectory()') -or
    -not $backupPage.Contains('await FileUtils.openFileOrUrl(logDir.path)') -or
    -not $fileUtils.Contains('ProcessStartMode.detached')) {
    throw 'Desktop/MSIX directory opening must use the canonical log directory and checked shell launch.'
}

$normalLayout = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\modules\live_play\widgets\layout\live_play_content.dart') -Raw
foreach ($marker in @('live-play-portrait-stack', 'live-play-desktop-panel', 'live-play-video-only-layout')) {
    if (-not $normalLayout.Contains($marker)) {
        throw "Normal live-room layout invariant marker is missing: $marker"
    }
}
$liveVideoFrame = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\modules\live_play\widgets\layout\live_play_video.dart') -Raw
if (-not $liveVideoFrame.Contains('this.expandToParent = false') -or
    -not $liveVideoFrame.Contains('return AspectRatio(aspectRatio: 16 / 9, child: child)')) {
    throw 'Ordinary landscape rooms must retain the legacy 16:9 video-frame contract.'
}
$playerManager = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\player\core\player_manager.dart') -Raw
if ($playerManager.Contains('return FittedBox(') -or $playerManager.Contains('StreamBuilder<List<int?>>')) {
    throw 'Native video adapters must remain the single aspect/BoxFit authority.'
}
$mediaKitAdapter = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\player\adapters\media_kit_adapter.dart') -Raw
if (-not $mediaKitAdapter.Contains('_player.stream.videoParams.listen') -or
    $mediaKitAdapter.Contains('_player.stream.width.listen') -or
    $mediaKitAdapter.Contains('_player.stream.height.listen')) {
    throw 'MediaKit geometry must publish one display-corrected decoder snapshot.'
}
$portraitSupport = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\player\core\portrait_stream_support.dart') -Raw
foreach ($marker in @(
    'stabilityDelay = const Duration(milliseconds: 500)',
    'portraitThreshold = 0.90',
    'landscapeThreshold = 1.10',
    'resolveCompactWindowAspectRatio',
    'resolveAndroidPipAspectRatio',
    '1 / 2.39',
    'minimumDanmakuHeight = 200'
)) {
    if (-not $portraitSupport.Contains($marker)) {
        throw "Portrait-source presentation invariant marker is missing: $marker"
    }
}
$fullscreenPolicy = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\player\utils\fullscreen.dart') -Raw
if (-not $fullscreenPolicy.Contains('supportsOrientationLockForLogicalDisplay') -or
    -not $fullscreenPolicy.Contains('logicalDisplaySize.shortestSide < 600')) {
    throw 'Android large-screen orientation policy must remain adaptive.'
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
    'Prefetch verified Firebase C++ SDK',
    'steps.version.outputs.artifact_version',
    "!inputs.build_windows || needs.windows.result == 'success'",
    "!(inputs.build_macos || inputs.build_ios) || needs.apple.result == 'success'",
    'stage-macos-'
)) {
    if (-not $featureWorkflow.Contains($marker)) { throw "Feature workflow policy marker is missing: $marker" }
}

# Every external Action is immutable at review time. This also rejects an
# accidental extra/missing hex character, which previously made the Windows
# upload step reference a non-existent commit.
foreach ($workflow in Get-ChildItem -LiteralPath (Join-Path $repoRoot '.github\workflows') -Filter '*.yml' -File) {
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $workflow.FullName) {
        $lineNumber++
        if ($line -match 'uses:\s+([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)@([^\s#]+)') {
            $reference = $Matches[2]
            if ($reference -notmatch '^[0-9a-f]{40}$') {
                throw "External Action must use a 40-character commit: $($workflow.Name):$lineNumber ($reference)"
            }
        }
    }
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
    'certificate SHA-256 digest',
    'EXPECTED_ANDROID_CERT_SHA256',
    "android_source == 'preuploaded-release'",
    '.github/workflows/local-signed-android.yml',
    'Windows package source does not match the release commit',
    'gh release delete-asset'
)) {
    if (-not $publisherWorkflow.Contains($marker)) {
        throw "Staged publisher verification marker is missing: $marker"
    }
}

$pubspecText = Get-Content -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') -Raw
if ($pubspecText -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$') {
    throw 'pubspec.yaml must expose a semantic version and numeric build.'
}
$displayVersion = $Matches[1]
$buildNumber = [int]$Matches[2]
$releaseTag = "v$displayVersion"
$versionFeed = Get-Content -LiteralPath (Join-Path $repoRoot 'assets\version.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$msixConfig = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\packaging\msix\make_config.yaml') -Raw
$windowsDisplayVersion = $versionFeed.platforms.windows.version
$windowsBuildNumber = [int]$versionFeed.platforms.windows.build_number
if ($msixConfig -notmatch "(?m)^msix_version:\s*$([regex]::Escape($windowsDisplayVersion))\.$windowsBuildNumber\s*$") {
    throw 'Windows MSIX version must match the Windows platform entry in assets/version.json.'
}
if ($versionFeed.version -ne $displayVersion -or [int]$versionFeed.build_number -ne $buildNumber) {
    throw 'assets/version.json top-level version must match pubspec.yaml.'
}
if ($versionFeed.platforms.android.version -ne $displayVersion -or
    [int]$versionFeed.platforms.android.build_number -ne $buildNumber) {
    throw 'assets/version.json Android version must match the current application version.'
}
if ($versionFeed.download_url -ne "https://github.com/liuchuancong/pure_live/releases/tag/$releaseTag") {
    throw 'assets/version.json must advertise the maintained repository release.'
}
foreach ($workflowName in @('feature-build.yml', 'stage-hosted-artifacts.yml', 'publish-staged-release.yml')) {
    $workflowText = Get-Content -LiteralPath (Join-Path $repoRoot ".github\workflows\$workflowName") -Raw
    $acceptedDefaults = @("default: $releaseTag", "default: '$releaseTag'", "default: `"$releaseTag`"")
    $hasCurrentDefault = @($acceptedDefaults | Where-Object { $workflowText.Contains($_) }).Count -gt 0
    if (-not $hasCurrentDefault) {
        throw "Workflow default tag is stale: $workflowName (expected $releaseTag)"
    }
}

$environmentText = Get-Content -LiteralPath (Join-Path $repoRoot '.env.prod') -Raw
$generatedEnvironment = Get-Content -LiteralPath (Join-Path $repoRoot 'lib\gen\env.g.dart') -Raw
if ($environmentText -notmatch '(?m)^PURELIVE_UPDATE_OWNER=liuchuancong\s*$' -or
    $generatedEnvironment -notmatch "pureliveUpdateOwner = 'liuchuancong'") {
    throw 'Production and generated update repositories must both target liuchuancong/pure_live.'
}

Write-Host 'Build policy static validation passed.'
