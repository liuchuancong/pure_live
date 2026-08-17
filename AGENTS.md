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

Use Flutter `3.47.0` from `.fvmrc`. On Windows, call the repository wrapper so the same SDK is selected consistently:

```powershell
.\tool\flutterw.ps1 pub get --enforce-lockfile
.\tool\flutterw.ps1 analyze --no-fatal-infos --no-fatal-warnings
.\tool\flutterw.ps1 test
python .\tool\interface_probe.py
```

Preferred complete gate:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1
```

Do not run `dart format .` across the whole repository. `lib/core/scripts/douyin_sign.dart` vendors raw JavaScript and is intentionally excluded by `tool/local_ci.ps1`. Format changed Dart files through the local gate.

Package locally with `tool/build_local_release.ps1`; see `docs/BUILD_AND_RELEASE.md`. GitHub workflows are manual fallback jobs, not the primary release path.

## Style and tests

- Follow `flutter_lints` and standard Dart naming: `lower_snake_case.dart`, `UpperCamelCase` types and `lowerCamelCase` members.
- Keep GetX module naming consistent: `*_page.dart`, `*_controller.dart`, `*_binding.dart`.
- Add focused tests for parser, adapter, settings migration and non-trivial service changes.
- Playback, PiP, floating-window and danmaku UI changes require platform smoke checks in addition to unit tests.
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
