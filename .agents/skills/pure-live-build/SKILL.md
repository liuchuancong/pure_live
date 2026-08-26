---
name: pure-live-build
description: Plan or execute Pure Live Flutter validation, Android/Windows builds, packaging, or releases with the repository's resource limits, serial platform staging, caches, and build records.
---

# Pure Live Build

Before selecting or running a validation/build command, read [`../../../BUILD_POLICY.md`](../../../BUILD_POLICY.md). Treat it as the authoritative default for this repository.

## Workflow

1. Extract only the platform, architecture, configuration, validation scope, packaging, and publication actions explicitly requested in the current task.
   For an upstream sync, freeze the full upstream SHA and run
   `tool/review_upstream_update.ps1` under `UPSTREAM_REVIEW_POLICY.md` before
   merging. The range must be merge-base-to-upstream, every incoming commit and
   file must be classified, and any incoming change requires a committed audit
   document plus explicit approval at the gate. After merging, run
   `python tool/audit_repository.py` before tests or packaging.
2. Keep one platform/variant per build invocation. Queue Android, Windows, Linux, macOS, and iOS stages serially.
3. During development, use focused tests and target-platform Debug. Run Analyze once after edits settle.
4. Use full regression and target-platform Release only for formal delivery.
   A failed packaging stage may use `-SkipQuality` only when the same app source
   already passed full regression and the retry changes build/Gradle/release
   plumbing only; cite that prior run in the delivery report.
5. Before staging or signing Android, run `tool/verify_android_apk.ps1`. Require the
   complete Flutter asset bundle, the single requested ABI, and the FFmpegKit,
   SQLite, MediaKit, Flutter, IJK and app native libraries; package metadata and
   signature checks alone are insufficient.
6. Android packaging consumes the package config produced by the preceding
   quality/dependency stage and uses `--no-pub`; do not regenerate unrelated
   desktop/Apple plugin links inside the Android Gradle invocation.
5. Enter the repository heavy-task guard before Gradle, Java, Dart, Flutter, or broad-search work. Default to 16 Gradle workers; use 20 only for an explicitly dedicated build. Start Flutter tests at concurrency 12. Classify work by sustained CPU/build-client activity so an `rg` process merely waiting on stdin does not block the queue indefinitely.
6. Preserve incremental outputs and caches. Do not add a clean step unless evidence identifies damaged or incompatible generated state.
   Keep Configuration Cache in strict failure mode. Mark a confirmed incompatible
   Flutter aggregate task with `notCompatibleWithConfigurationCache` so Gradle
   discards only that entry instead of persisting incomplete state in warning mode.
   For Windows packaging, stage only files in the current CMake
   `install_manifest.txt` plus the reviewed runner-runtime allowlist; never copy
   the complete incremental Release directory, which can retain DLLs from removed plugins.
7. Report the generated build record and artifacts, then stop. Do not append another platform, full regression, package, upload, or release stage unless it was included in the current request.

Use `tool/local_ci.ps1` for focused/full validation and `tool/build_local_release.ps1` for the single explicitly selected local target.
