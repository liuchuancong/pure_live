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
  theme scope (never a second application widget inside the host).
- Build native Wind widgets for all seventeen: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast, dialog, tab view**. Six of them are a fork widget
  (`WButton`, `WCard`, `WInput`, `WSwitch`, `WCheckbox`, `WSelect`); the other
  eleven are built out of this library's own surface parts and theme values —
  `WDiv`/`WCard` panels, the `WAnchor` its own controls are built on, `WText`/
  `WIcon` leaves and its Tailwind colour, radius, border and shadow maps — because
  `fluttersdk_wind` ships no slider, segmented track, progress bar, tab strip,
  frame, bar, row, navigation bar, toast, dialog or page switcher (§9). For the
  dialog only the surface is this package's: the route, the barrier, the
  fade-and-scale and the dismissal stay in core's `showLiveDialog`, and the tab
  view is Flutter's `PageView` inside the library's own full-size column.
- Declare the whole contract in `windCapabilities`: a Wind page reports no
  `controlUnsupported` downgrade, and no control of it is a token renderer
  (§16/§17).
- Own the app host: the library ships no application widget, so the host is
  Flutter's `WidgetsApp` with a `WindTheme` scope above the routed tree — which is
  what takes the page transition, the scroll physics and the dialog barrier out of
  Material's hands (§ surfaces). The shell is composed here too: the library has
  no navigation widget, so the column is its own panels and anchors.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Every control of the contract is drawn here: the eleven the fork has no widget for
are composed out of its own surface parts and theme values, so nothing in a Wind
page still paints from the token base. They read as Wind because their panels,
accent, radius and rules are the library's own, resolved inside the theme scope
this adapter installs. The app host is here too: the library ships no application
widget, so the host is Flutter's `WidgetsApp` with Wind's theme above the routed
tree (§ surfaces), and so is the app shell, composed from the library's styled
parts because it ships no navigation widget of its own.

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
  adapters: {LiveDesignLanguage.wind: windAdapter},
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

`test/adapter/wind_contract_test.dart` verifies the stable id/display name,
that the declared capabilities are the whole contract and match the controls the
adapter overrides, and that a language this build did not register still resolves
shared and reports `adapterMissing` (§16/§17).

Test coverage is present at four layers: `test/adapter/` (contract and
resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
`test/widgets/` (every control of the contract driven through the real dispatch
path, native and composed alike, the assertion that no `Token*` renderer survives
inside a Wind page, and the app host chain — `WidgetsApp` under `WindTheme` with no
`MaterialApp` in it), and `test/integration/` (resolution surface across
the contract and a switch to the shared `token` base and back with caller-owned
state preserved). What remains untested is the part that needs hardware: focus
traversal, Android TV D-pad, and the platform claims in §13.

## Known limitations

- The shell has no widget to map onto: the library ships styled parts and no
  navigation structure, so the rail is composed from `WDiv` panels and `WAnchor`
  cells, and its icon size follows the library's own `text-lg` class rather than
  the environment's `iconSize` (§ surfaces).
- `WButton` owns its focus handling inside `WAnchor`, so `focusNode`/`autofocus`
  cannot be honoured on the Wind button — and not on the composed rail or list row
  either, which take the same anchor (§9).
- `WInput` collapses keyboard type and obscuring into one `InputType` (§9).
- Wind's `primary` scale reaches this package as one flat accent
  (`WindThemeBuilder` expands the single token accent into every shade, §8.1), so
  a composed control has no tint step to select with: the accent is used as a mark
  (a fill, an underline, a label) and Wind's own greys carry the resting surface.
- The library has no transform parser (`WSwitch` records it), so an indeterminate
  progress run cannot travel the rail; it breathes with `animate-pulse` instead
  (§9 Progress).
