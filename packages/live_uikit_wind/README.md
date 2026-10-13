# live_uikit_wind

The Wind design-language adapter for PureLive's unified UI system (`live_uikit`).
It renders the core's neutral control specifications with native `fluttersdk_wind`
widgets and maps the resolved design token into that library's theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **Wind**
implementation so an application can select `wind` at runtime and have its
controls drawn by `fluttersdk_wind`, without business pages importing it.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.wind` (stable id `wind`).
- Map the resolved `DesignToken` into the Wind theme and install it through a
  theme scope (never a nested application shell).
- Build native Wind widgets for: **button, switch, checkbox**.
- Declare exactly those controls in `windUiCapabilities` so the core resolver
  reports a `controlUnsupported` downgrade for the rest (§16/§17).

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Controls not built here (card, text field, slider, segmented, progress, select,
tab bar) fall back to the core shared token renderer — they still render
on-theme.

## Public entry point

`package:live_uikit_wind/live_uikit_wind.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.wind: windUiAdapter},
  fallback: SharedLanguageAdapter(),
);
```

The library reuses the core's localization, so this package adds no delegates.

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `fluttersdk_wind` ^1.8.1 (the native widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_wind
```

`test/adapter/wind_ui_contract_test.dart` verifies the stable id/display name,
that the declared capabilities match the controls the adapter overrides, and the
core resolver's native-versus-`controlUnsupported` dispatch (§16/§17).

## Known limitations

- Only button, switch and checkbox are native; every other control uses the shared
  renderer.
- No widget-level or cross-style integration tests yet.
