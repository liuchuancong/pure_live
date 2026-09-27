# Claude Code guidance

[AGENTS.md](AGENTS.md) is the repository entrypoint. Follow its task-scoped links instead of loading every maintenance/build document for every edit. Verification and delivery routing is in [docs/AGENT_WORKFLOW.md](docs/AGENT_WORKFLOW.md).

## Branch and WSL environment

These points narrow AGENTS.md for Claude sessions only.

- `master` is the repository's only branch: at the user's request (2026-09-27) the `claude` and `upstream-port` branches were merged into it and deleted. Commit and push verified fixes to `origin/master`; the in-app update check reads `assets/version.json` from `master`, so bump it only together with a published release.
- Claude builds and tests in WSL, not through the Windows PowerShell tooling. Load the environment with `source ~/tools/purelive-env.sh`, then use `flutter`, `dart` and `android/gradlew` directly. It pins the same Flutter as `.fvmrc`, Temurin 26.0.2.1 (the documented Gradle runtime; Windows builds use `C:\Users\123\claude-work\jdk\jdk-26.0.2.1+1` via `JAVA_HOME`/`PURE_LIVE_JAVA_HOME`) and the WSL Android SDK. `tool/*.ps1` scripts and `tool/flutterw.ps1` are Windows-only; mirror their checks by hand when a WSL equivalent is needed.
- `ANDROID_USER_HOME` points to a copy of the Windows debug keystore, so WSL debug/test APKs overwrite-install builds made on Windows without clearing app data.
- The resource and single-heavy-task rules in BUILD_POLICY.md still apply (WSL: 15 cores, 125 GB RAM).
