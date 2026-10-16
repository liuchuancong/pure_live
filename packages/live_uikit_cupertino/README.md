# live_uikit_cupertino

The Cupertino UI design-language adapter for PureLive's unified UI system
(`live_uikit`). It renders the core's neutral control specifications with native
`cupertino_ui` widgets and maps the resolved design token into that library's
theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **Cupertino UI**
implementation so an application can select `cupertino` at runtime and have its
controls drawn by `cupertino_ui`, without business pages importing it.

`cupertino_ui` is a fork of Flutter's Cupertino widgets, so this adapter mirrors
the core's Cupertino coverage rather than inventing a new one.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.cupertino` (stable id
  `cupertino`).
- Map the resolved `DesignToken` into the Cupertino theme and install it through a
  theme scope (never a nested application shell).
- Build native Cupertino widgets for: **button, text field, switch, slider,
  scaffold, app bar, list row, nav bar, app host**.
- Declare exactly those controls in `cupertinoCapabilities` so the core resolver
  reports a `controlUnsupported` downgrade for the rest (§16/§17).
- Expose `cupertinoLocalizationsDelegates` (the fork's own Cupertino
  localizations, distinct from Flutter's) for the composition root to install.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Controls not built here (card, checkbox, segmented, progress, select, tab bar)
fall back to the core shared token renderer — they still render on-theme.

## Public entry point

`package:live_uikit_cupertino/live_uikit_cupertino.dart` — exports only the
registration API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/live_uikit_cupertino.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.cupertino: cupertinoAdapter},
  fallback: SharedLanguageAdapter(),
);

// In the app shell, append the fork's delegates to the core's:
//   MaterialApp(
//     localizationsDelegates: [
//       ...liveLocalizationsDelegates,
//       ...cupertinoLocalizationsDelegates,
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
flutter test packages/live_uikit_cupertino
```

`test/adapter/cupertino_contract_test.dart` verifies the stable id/display
name, that the declared capabilities match the controls the adapter overrides, and
the core resolver's native-versus-`controlUnsupported` dispatch (§16/§17).

## Known limitations

- Only button, text field, switch and slider are native; every other control uses
  the shared renderer.
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every native control driven through the real dispatch path), and
  `test/integration/` (resolution surface for all ten controls and a switch to the
  the shared `token` base and back with caller-owned state preserved). What remains
  untested is the part that needs hardware: focus traversal, Android TV D-pad, and
  the platform claims in §13.
