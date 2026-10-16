# live_uikit_fluent

The Fluent Design language adapter for PureLive's unified UI system (`live_uikit`).
It renders the core's neutral control specifications with native `fluent_ui`
widgets and maps the resolved design token into `FluentThemeData`.

See `live-uikit-fluent.md` in this directory for the full architecture and
integration specification.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens, runtime
dispatch and the shared token renderer. This package supplies the **Fluent**
implementation of that contract so an application can select `fluent` at runtime
and have its controls drawn by `fluent_ui`, without any business page importing
`fluent_ui` directly.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.fluent` (stable id `fluent`).
- Map the resolved `DesignToken` into a `FluentThemeData` and install it through a
  `FluentTheme` scope (never a nested `FluentApp`).
- Build native Fluent widgets for: **button, card, text field, switch, checkbox,
  slider, progress, select, scaffold, list row, toast, app host**.
- Declare exactly those controls in `fluentCapabilities` so the core resolver can
  report a `controlUnsupported` downgrade for the rest (§16/§17).
- Expose `fluentLocalizationsDelegates` for the composition root to install.

## What this package must not own

- Global theme preferences or their persistence, and the style-selector UI.
- Shared design-token definitions or global configuration storage.
- Any state management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters, or on `fluent_ui` leaking into
  business packages.

Controls not built here (segmented, tab bar) fall back to the core shared
token renderer — they still render on-theme, they are simply not Fluent-native.

## Public entry point

`package:live_uikit_fluent/live_uikit_fluent.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

PureLive uses a single Pub workspace; this package is already a workspace member.
Business packages depend only on `live_uikit`. The **application composition root**
registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.fluent: fluentAdapter},
  fallback: SharedLanguageAdapter(),
);

// In the app shell, append Fluent's delegates to the core's:
//   MaterialApp(
//     localizationsDelegates: [
//       ...liveLocalizationsDelegates,
//       ...fluentLocalizationsDelegates,
//     ],
//   )
```

Selecting the style at runtime is `UiConfig.language = LiveDesignLanguage.fluent`;
a `LiveButton` then draws through this adapter with no change to the page.

## Dependencies

- `live_uikit` (the contracts and shared renderer)
- `fluent_ui` ^4.16.1 (the native Fluent widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_fluent
```

`test/adapter/fluent_capabilities_test.dart` verifies the stable id/display
name, that the declared capabilities match the controls the adapter overrides, and
that the core resolver serves a declared control natively while reporting a
`controlUnsupported` diagnostic for an undeclared one (§16 unit tests / §17).

## Known limitations

- Segmented and tab bar are served by the shared token renderer; `select` and
  `progress` are native (`fluent.ComboBox<T>` keeps the spec's typed value).
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every native control driven through the real dispatch path), and
  `test/integration/` (resolution surface for all ten controls and a switch to the
  the shared `token` base and back with caller-owned state preserved). What remains
  untested is the part that needs hardware: focus traversal, Android TV D-pad, and
  the platform claims in §13.
- Fluent can be selected on every supported platform, but native Windows chrome
  and system integrations must not be assumed elsewhere (§13).
