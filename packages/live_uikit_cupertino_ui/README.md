# live_uikit_cupertino_ui

The Cupertino UI design-language adapter for PureLive's unified UI system
(`live_uikit`). It renders the core's neutral control specifications with native
`cupertino_ui` widgets and maps the resolved design token into that library's
theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **Cupertino UI**
implementation so an application can select `cupertinoUi` at runtime and have its
controls drawn by `cupertino_ui`, without business pages importing it.

`cupertino_ui` is a fork of Flutter's Cupertino widgets, so this adapter mirrors
the core's Cupertino coverage rather than inventing a new one.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.cupertinoUi` (stable id
  `cupertinoUi`).
- Map the resolved `DesignToken` into the Cupertino theme and install it through a
  theme scope (never a nested application shell).
- Build native Cupertino widgets for: **button, text field, switch, slider**.
- Declare exactly those controls in `cupertinoUiCapabilities` so the core resolver
  reports a `controlUnsupported` downgrade for the rest (§16/§17).
- Expose `cupertinoUiLocalizationsDelegates` (the fork's own Cupertino
  localizations, distinct from Flutter's) for the composition root to install.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Controls not built here (card, checkbox, segmented, progress, select, tab bar)
fall back to the core shared token renderer — they still render on-theme.

## Public entry point

`package:live_uikit_cupertino_ui/live_uikit_cupertino_ui.dart` — exports only the
registration API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino_ui/live_uikit_cupertino_ui.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.cupertinoUi: cupertinoUiAdapter},
  fallback: SharedLanguageAdapter(),
);

// In the app shell, append the fork's delegates to the core's:
//   MaterialApp(
//     localizationsDelegates: [
//       ...liveLocalizationsDelegates,
//       ...cupertinoUiLocalizationsDelegates,
//     ],
//   )
```

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `cupertino_ui` ^1.1.2 (the native widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_cupertino_ui
```

`test/adapter/cupertino_ui_contract_test.dart` verifies the stable id/display
name, that the declared capabilities match the controls the adapter overrides, and
the core resolver's native-versus-`controlUnsupported` dispatch (§16/§17).

## Known limitations

- Only button, text field, switch and slider are native; every other control uses
  the shared renderer.
- No widget-level or cross-style integration tests yet.
