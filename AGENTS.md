# Repository Guidelines

## Project structure

- `lib/core/`: streaming-site adapters, danmaku protocols, IPTV parsing and shared domain logic.
- `lib/common/`: services, widgets, models, styles and localization helpers.
- `lib/modules/`: GetX feature modules such as playback, settings, backup and search.
- `lib/player/`, `lib/routes/`, `lib/plugins/`: playback backends, routing and integrations.
- `assets/`: runtime images, icons, translations, WebDAV tutorial media and version metadata.
- `test/`: Flutter tests named `*_test.dart`.
- `tool/`: reproducible local quality, interface, packaging, installation and release scripts.
- `docs/`: build, dependency and feature documentation.
- `android/`, `windows/`, `ios/`, `macos/`: platform projects. Primary maintained release targets are Android and Windows.

## Toolchain and commands

Read and follow [`BUILD_POLICY.md`](BUILD_POLICY.md) before starting any Flutter, Dart, Gradle, Java, test, build, package, or release command. It is the repository default for platform scope, serial staging, worker limits, caching, resource arbitration, and build records. Before merging an upstream revision, also follow [`UPSTREAM_REVIEW_POLICY.md`](UPSTREAM_REVIEW_POLICY.md) and run its high-risk diff gate.

Use Flutter `3.47.0` from `.fvmrc`. On Windows, call the repository wrapper so the same SDK is selected consistently:

```powershell
.\tool\flutterw.ps1 pub get --enforce-lockfile
.\tool\flutterw.ps1 analyze --no-pub --no-fatal-infos --no-fatal-warnings # once, after edits settle
.\tool\flutterw.ps1 test --no-pub --concurrency=12 test/example_test.dart
python .\tool\interface_probe.py
```

Focused development gate (pass only affected tests and run Analyze once after the edit is complete):

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1 -Scope Focused -TestPath test/example_test.dart -Analyze
```

Use `-Scope Full` only for a formal delivery or an explicitly requested complete regression. Flutter tests start at `--concurrency=12`.

Do not run `dart format .` across the whole repository. `lib/core/scripts/douyin_sign.dart` vendors raw JavaScript and is intentionally excluded by `tool/local_ci.ps1`. Format changed Dart files through the local gate.

Package locally with `tool/build_local_release.ps1`; both `-Target` and `-Configuration` are required, and one invocation builds exactly one platform/variant. Build Android, Windows, and other platforms as separate serial stages. GitHub workflows are manual fallback jobs, not the primary release path; see `docs/BUILD_AND_RELEASE.md`.

## Style and tests

- Follow `flutter_lints` and standard Dart naming: `lower_snake_case.dart`, `UpperCamelCase` types and `lowerCamelCase` members.
- Keep GetX module naming consistent: `*_page.dart`, `*_controller.dart`, `*_binding.dart`.
- Add focused tests for parser, adapter, settings migration and non-trivial service changes.
- Playback, PiP, floating-window and danmaku fixes default to a device-independent workflow: trace the state/event ordering, add a deterministic regression test, run static analysis and the affected local test suite, then build the target artifact when requested.
- Never connect to or operate a user's phone, start ADB, install an APK, or automate device UI unless the user explicitly requests device work in the current task. A connection mentioned in an earlier message is not standing permission.
- Before every device command, re-check the user's latest instruction. If the current task says to avoid phone operations, do not run even read-only ADB discovery, `dumpsys`, log collection, screenshots or package queries; continue from source and deterministic tests instead.
- Device smoke checks are optional release evidence rather than a prerequisite for diagnosing or repairing code. When a physical scenario has not been sampled, report that evidence layer separately without blocking the code fix or overstating runtime coverage.
- External interface probes are readiness checks; they do not replace authenticated stream, WebSocket danmaku or CDN playback regression.

## Commits and Pull Requests

- Use short imperative Conventional Commit-style subjects such as `feat(pip): ...`, `fix(windows): ...`, or `docs: ...`.
- Keep each commit focused and update generated files, lockfiles and documentation with the source change that requires them.
- Pull Requests must include motivation, verification commands/results, tested platforms, linked issues, and screenshots or recordings for UI changes.
- Sync a feature branch with the latest `master` and rerun affected checks before merge.

## Security and configuration

- Never commit signing files, `android/key.properties`, Cookie values, WebDAV credentials, private stream lists or real backup data.
- Keep Android JKS and other release keys outside the repository; inject them through local configuration or GitHub Secrets.
- Firebase client configuration is public application metadata, not a server credential. Administrative credentials and service-account keys must remain external.
- Report vulnerabilities through the private GitHub Security Advisory form described in `SECURITY.md`.
