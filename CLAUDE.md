# Claude Code guidance

Read [`AGENTS.md`](AGENTS.md) and [`BUILD_POLICY.md`](BUILD_POLICY.md) before changing this repository. They are the canonical guides for project structure, resource arbitration, test scope, serial platform builds, packaging, contribution rules and secret handling.

Key entry points:

- Focused local gate: `PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1 -Scope Focused -TestPath test/example_test.dart -Analyze`
- Formal full gate: `PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1 -Scope Full`
- Local single-target package: `PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 -Target AndroidArm64 -Configuration Debug -SkipQuality`
- Build and release details: [`docs/BUILD_AND_RELEASE.md`](docs/BUILD_AND_RELEASE.md)
- Dependency constraints: [`docs/DEPENDENCY_AUDIT.md`](docs/DEPENDENCY_AUDIT.md)

Use the repository wrapper in `tool/flutterw.ps1`, preserve `pubspec.lock`, and keep credentials and signing material outside Git.
