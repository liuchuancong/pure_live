# live_uikit_macos

The macOS design-language adapter for PureLive's unified UI system (`live_uikit`).
It renders the core's neutral control specifications with native `macos_ui`
widgets and maps the resolved design token into `MacosThemeData`.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **macOS**
implementation so an application can select `macos` at runtime and have its
controls drawn by `macos_ui`, without business pages importing `macos_ui`.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.macos` (stable id `macos`).
- Map the resolved `DesignToken` into a `MacosThemeData` and install it through a
  `MacosTheme` scope (never a nested `MacosApp`).
- Build native macOS widgets for: **button, text field, checkbox, slider**.
- Declare exactly those controls in `macosUiCapabilities` so the core resolver
  reports a `controlUnsupported` downgrade for the rest (§16/§17).

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Controls not built here (card, switch, segmented, progress, select, tab bar) fall
back to the core shared token renderer — they still render on-theme.

## Public entry point

`package:live_uikit_macos/live_uikit_macos.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.macos: macosUiAdapter},
  fallback: SharedLanguageAdapter(),
);
```

`macos_ui` reuses the core's Material/Cupertino localization, so this package adds
no delegates of its own (§14).

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `macos_ui` ^2.2.2 (the native macOS widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_macos
```

`test/adapter/macos_ui_contract_test.dart` verifies the stable id/display name,
that the declared capabilities match the controls the adapter overrides, and the
core resolver's native-versus-`controlUnsupported` dispatch (§16/§17).

## Known limitations

- Card, switch, segmented, progress, select and tab bar use the shared renderer,
  not native macOS widgets.
- No widget-level or cross-style integration tests yet.
- macOS styling can be selected on any platform, but native macOS window
  integration should not be assumed off-macOS (§13).
