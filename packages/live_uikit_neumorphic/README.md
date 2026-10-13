# live_uikit_neumorphic

The Neumorphic design-language adapter for PureLive's unified UI system
(`live_uikit`). It renders the core's neutral control specifications with native
`flutter_neumorphic_ui_kit` widgets and maps the resolved design token into that
library's theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **Neumorphic**
implementation so an application can select `neumorphic` at runtime and have its
controls drawn by `flutter_neumorphic_ui_kit`, without business pages importing
that package.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.neumorphic`
  (stable id `neumorphic`).
- Map the resolved `DesignToken` into the Neumorphic theme and install it through
  a theme scope (never a nested application shell).
- Build native Neumorphic widgets for: **button, card, text field, switch,
  checkbox, slider**.
- Declare exactly those controls in `neumorphicUiCapabilities` so the core
  resolver reports a `controlUnsupported` downgrade for the rest (§16/§17).

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Controls not built here (segmented, progress, select, tab bar) fall back to the
core shared token renderer — they still render on-theme.

## Public entry point

`package:live_uikit_neumorphic/live_uikit_neumorphic.dart` — exports only the
registration API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.neumorphic: neumorphicUiAdapter},
  fallback: SharedLanguageAdapter(),
);
```

The library reuses the core's localization, so this package adds no delegates.

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `flutter_neumorphic_ui_kit` ^1.0.1 (the native widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_neumorphic
```

`test/adapter/neumorphic_ui_contract_test.dart` verifies the stable id/display
name, that the declared capabilities match the controls the adapter overrides, and
the core resolver's native-versus-`controlUnsupported` dispatch (§16/§17).

## Known limitations

- Segmented, progress, select and tab bar use the shared renderer, not native
  Neumorphic widgets.
- No widget-level or cross-style integration tests yet.
