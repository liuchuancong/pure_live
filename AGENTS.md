# Repository Guidelines

## Project Structure & Module Organization

- `lib/`: Flutter/Dart source
  - `lib/core/`: site integrations, danmaku, IPTV, shared helpers
  - `lib/common/`: shared services/widgets/models/styles and i18n (`lib/common/l10n/`)
  - `lib/modules/`: feature modules (GetX), e.g. `live_play/`, `settings/`, `search/`
  - `lib/routes/`, `lib/player/`, `lib/plugins/`: routing, playback, and integrations
- `assets/`: icons/images/emotes plus app config like `assets/version.json`
- `test/`: Flutter tests (`*_test.dart`)
- Platform folders: `android/`, `ios/`, `macos/`, `windows/`, `linux/`

## Build, Test, and Development Commands

Use Flutter `3.38.3` (see `.fvmrc`; with FVM, prefix commands with `fvm`).

- `flutter pub get`: install dependencies
- `flutter run`: run on a device/emulator
- `flutter analyze`: static analysis/lints (`analysis_options.yaml`)
- `dart format .`: auto-format Dart code
- `flutter test`: run the test suite
- Packaging examples (see `run.MD` and `.github/workflows/release.yml`):
  - Android: `flutter build apk --split-per-abi`
  - Windows: `dart run msix:create`
  - macOS: `flutter build macos --release`

## Coding Style & Naming Conventions

- Keep code `dart format`-clean; follow `flutter_lints` defaults.
- Dart conventions: `lower_snake_case.dart` files, `UpperCamelCase` types, `lowerCamelCase` members.
- Module files typically follow `*_page.dart`, `*_controller.dart`, `*_binding.dart` (GetX bindings/routing).

## Testing Guidelines

- Framework: `flutter_test`. Place tests under `test/` and name files `*_test.dart`.
- Add or update tests for bug fixes and non-trivial logic (services, parsers, site adapters).

## Commit & Pull Request Guidelines

- Git history favors short, imperative messages like `fix(*)`, `fix(scope)`, and occasional Chinese summaries.
- PRs should include: what changed, repro steps, linked issues, screenshots/recordings for UI changes, and platforms tested (e.g. Android/Windows).

## Security & Configuration Tips

- Do not commit real signing material or credentials. Keep local-only files (e.g. `android/key.properties`) out of PRs.
- Supabase settings live in `assets/keystore/supabase.json`; if you use your own backend, change it locally and avoid publishing private keys.
