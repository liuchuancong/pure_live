# Claude Code guidance

Read [`AGENTS.md`](AGENTS.md) before changing this repository. It is the canonical guide for project structure, toolchain selection, tests, packaging, contribution rules and secret handling.

Key entry points:

- Full local gate: `PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1`
- Local packages: `PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1`
- Build and release details: [`docs/BUILD_AND_RELEASE.md`](docs/BUILD_AND_RELEASE.md)
- Dependency constraints: [`docs/DEPENDENCY_AUDIT.md`](docs/DEPENDENCY_AUDIT.md)

Use the repository wrapper in `tool/flutterw.ps1`, preserve `pubspec.lock`, and keep credentials and signing material outside Git.
