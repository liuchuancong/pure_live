# live_uikit_wind

The Wind design-language adapter for PureLive's unified UI system (`live_uikit`).
It renders the core's neutral control specifications with `fluttersdk_wind`'s own
parts and maps the resolved design token into that library's theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, the tokens, and the
runtime dispatch that sends each control to the adapter selected for it. This
package supplies the **Wind** implementation so an application can select `wind`
at runtime and have its controls drawn by `fluttersdk_wind`, without business
pages importing it.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.wind` (stable id `wind`).
- Map the resolved `DesignToken` into the Wind theme and install it through a
  theme scope (never a second application widget inside the host).
- Build the control set in Wind — all seventeen: **button, card, text field,
  switch, checkbox, slider, segmented, progress, select, tab bar, scaffold, app
  bar, list row, nav bar, toast, dialog, tab view**. Six of them are a library
  widget (`WButton`, `WCard`, `WInput`, `WSwitch`, `WCheckbox`, `WSelect`); the
  other eleven are built out of this library's own surface parts and theme
  values — `WDiv`/`WCard` panels, the `WAnchor` its own controls are built on,
  `WText`/`WIcon` leaves and its Tailwind colour, radius, border and shadow
  maps — because `fluttersdk_wind` ships no slider, segmented track, progress
  bar, tab strip, frame, bar, row, navigation bar, toast, dialog or page
  switcher (§9). For the dialog only the surface is this package's: the route,
  the barrier, the fade-and-scale and the dismissal stay in core's
  `showLiveDialog`, and the tab view is Flutter's `PageView` inside the
  library's own full-size column.
- Declare the whole contract in `windCapabilities`: a Wind page reports no
  downgrade to report, and none of its controls is drawn by the core
  (§16/§17).
- Own the app host: the library ships no application widget, so the host is
  Flutter's `WidgetsApp` with a `WindTheme` scope above the routed tree — which is
  what takes the page transition, the scroll physics and the dialog barrier out of
  Material's hands (§ surfaces). The shell is composed here too: the library has no
  navigation widget, so the rail is its own panels and anchors.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Every control of the contract is drawn here: the eleven the library has no widget
for are composed out of its own surface parts and theme values, so every panel of
a Wind page is one this package placed. They read as Wind because their panels,
accent, radius and rules are the library's own, resolved inside the theme scope
this adapter installs. The app host is here too: the library ships no application
widget, so the host is Flutter's `WidgetsApp` with Wind's theme above the routed
tree (§ surfaces), and so is the app shell, composed from the library's styled
parts because it ships no navigation widget of its own.

## Public entry point

`package:live_uikit_wind/live_uikit_wind.dart` — exports only the registration
API (§6): `windUiAdapter`, `createWindUiAdapter()`, and `windUiAdapterId`. Do not
import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter — that is the whole integration:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

const registry = LanguageRegistry(adapters: {LiveDesignLanguage.wind: windAdapter});
```

The library reuses the core's localization, so this package adds no delegates.

- Build native Wind controls for **button, card, text field, switch, checkbox, select**. Each
  is one of the library's own widgets, reached by its own gesture mechanism, and each is
  declared in `windUiCapabilities`.
- Build native Wind controls for **slider, segmented, progress**. The library has no widget
  for those jobs, so each is composed from its parts: a `WDiv` panel for the track, the
  `WAnchor` its own controls are built on for the one that takes input, `WText` for the
  value a segment or a label carries. They are declared in `windUiCapabilities` alongside
  the six mapped controls (§9).
- Build native Wind controls for **tab bar, scaffold, app bar, list row, nav bar, toast,
  dialog, tab view**. The library ships none of these as widgets, so each is composed from
  its parts: `WDiv`/`WCard` panels, the `WAnchor`, `WText`/`WIcon` leaves. A tab strip is a
  strip on its own here — the library's only tab control welds a strip to a content panel —
  and the dialog is its surface only, with the route and the barrier owned by core
  (§ surfaces).
- The app host and the shell are built here too. The library ships no application widget, so
  the host is Flutter's `WidgetsApp` with Wind's theme above the routed tree, which is what
  takes the page transition, the scroll physics and the barrier out of Material's hands. The
  shell is composed from the library's own styled parts, because it ships no navigation
  structure (§ surfaces).

## Dependencies

- `live_uikit` (the contracts and the dispatch)
- `fluttersdk_wind` ^1.8.1 (the library this adapter renders in)
- Flutter SDK

## Architecture

- `src/adapter/` — `WindLanguageAdapter` (implements the finalized
  `LanguageAdapter` interface directly), capability declaration, and registration
  helper.
- `src/theme/` — `DesignToken` → Wind theme mapper and the Wind theme scope.
- `src/widgets/` — per-control builders for the contract: `button`, `card`,
  `textField`, `switchWidget`, `checkbox`, `slider`, `segmented`, `progress`,
  `select`, `tabBar`, `scaffold`, `appBar`, `listRow`, `navBar`, `toast`,
  `dialog`, `tabView`.
- `src/internal/` — the Wind surface primitives that the composed controls and the
  surfaces are assembled out of.
- `src/motion/` — tap and focus primitives; `src/perf/` — capability probes.

The adapter does not inject a second `MaterialApp`/`WidgetsApp` inside the host; it
wraps the supplied child in the Wind theme scope (§10).

## Degradation

- A control this package builds never degrades: it is drawn by the library's own
  widget or from its own parts, and every one of the seventeen is declared in
  `windUiCapabilities`, so a Wind page reports no downgrade at all.
- `unsupportedEffect` (§15) covers effects the device can't afford. Wind declares
  the ones it implements — `ripple`, `pressScale`, `stateLayer`, `hoverGlow`,
  `blur`, `elevatedShadow` — in `WindUiCapabilityManifest`; `glow` and `marquee`
  are not implemented and yield that diagnostic. This package reports what the
  device can afford, it does not decide what to draw.
- The theme scope is installed by `wrap`, so no builder needs a context lookup for
  colors.
- A language with no adapter here fails resolution with
  `LiveUiResolutionException` — there is no default look to render in, so the app
  registers the adapters it uses (§ resolution).

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_wind
```

`test/adapter/wind_contract_test.dart` verifies the stable id/display name and
that the capability declaration matches the controls `WindLanguageAdapter`
actually overrides (§17). It also asserts that a language this build did not
register is a hard failure rather than a rendering (§ resolution).

Test coverage is present at four layers: `test/adapter/` (contract and
resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
`test/widgets/` (every control of the contract driven through the real dispatch
path, mapped and composed alike, the assertion that nothing outside this library
draws a control of a Wind page, and the app host chain — `WidgetsApp` under
`WindTheme` with no `MaterialApp` in it), and `test/integration/` (resolution
surface across the whole contract, and a live theme switch with caller-owned
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
- No real-device or Android TV focus verification has been performed yet (§12/§13).

## Related

- `docs/design-language-adapter-target-spec.md` — authoritative target spec.
- `packages/live_uikit/` — core contracts, tokens, dispatch, resolution failures.
- `packages/README.md` — package family and adapter promotion process.
