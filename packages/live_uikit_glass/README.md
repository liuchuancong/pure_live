# live_uikit_glass

The Glass (glassmorphism) design-language adapter for PureLive's unified UI system
(`live_uikit`). It renders the core's neutral control specifications with
`glass_morphism_plus` — that library's own widgets where it has them, its frosted
surfaces and theme values where it does not — and maps the resolved design token
into the library's theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, the tokens, the runtime
dispatch and the diagnostics event. This package supplies the **Glass**
implementation so an application can select `glass` at runtime and have its
controls drawn by `glass_morphism_plus`, without business pages importing it.

`LanguageAdapter` is an `abstract interface class`: this package's
`GlassLanguageAdapter` implements it directly, answers every member of it, and
nothing is served on its behalf by another package.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.glass` (stable id `glass`).
- Map the resolved `DesignToken` into the Glass theme and install it through a
  theme scope (never a second application widget inside the host).
- Build native Glass widgets for all seventeen: **button, card, text field, switch,
  checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar, list
  row, nav bar, toast, dialog, tab view**. Four of those are mappings to a library
  widget — `button` is `GlassButton`, `card` is `GlassCard`, `text field` is
  `GlassTextField` and `list row` is `GlassListTile`; the other thirteen are
  composed out of `GlassContainer` sheets and the `GlassTheme` values they read
  (blur, tint, corner radius, stroke, shadow), with geometry and colour from the
  component tokens, because `glass_morphism_plus` ^0.1.0 is a surface library: it
  publishes frosted sheets and the theme that describes them and ships no toggle,
  box, rail, track, indicator, field menu, strip, page frame, header, destination
  bar, message, overlay or page switcher. Each builder's own doc comment says
  whether it maps or composes (§9).
- Own both structural surfaces (§ surfaces). The app host: the library ships no
  application widget, so the host is Flutter's `WidgetsApp` with `GlassTheme` above
  the routed tree — which is what decides the page transition, the scroll physics
  and the surface a dialog's modal barrier covers. The app shell:
  `glass_morphism_plus` has no navigation structure either — only frosted surfaces
  (`GlassContainer`/`GlassTile`/`GlassDivider`) and the Material `GlassAppBar` — so
  the column is composed, not mapped: a full-height frosted `GlassContainer` track
  with a brighter sheet on the selected destination (the nav bar and tab bar built
  vertically), its tap and hover routed through the core's `LiveBox` because a
  tappable `GlassContainer` brings its own ink and focus node, the bottom form
  handed back through `navBar`, and `trailing` pinned to the foot of the column.
- Declare the whole contract in `glassCapabilities` and both surfaces in
  `glassSurfaces`: every control a Glass page asks for and every surface it sits in
  is answered by this adapter, so a resolved Glass language reports no capability
  failure, and `LiveUiCapabilityException` fires only if the declaration ever
  drifts from the overrides (§16/§17).
- Keep the dialog and the tab view surfaces rather than behaviour: the library has
  neither an overlay nor a page switcher, so `dialog` is a frosted panel inside the
  route the core owns and `tab view` is the framework's `PageView` on a frosted
  sheet, because iOS — the phone this language is the frosted reading of — swipes
  between tab pages. The route, the barrier, the transition, the timeout and the
  caller's index stay the core's and the caller's.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Every control of the contract and both structural surfaces are built here. What
`glass_morphism_plus` has no widget for is composed from its own frosted surfaces
and theme values rather than borrowed from another library, so a Glass page is
drawn end to end in this language — and a language this build did not register is
a `LiveUiResolutionException` at boot, not a window painted by somebody else.

## Public entry point

`package:live_uikit_glass/live_uikit_glass.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.glass: glassAdapter},
);
```

`LanguageRegistry` takes the adapters and nothing else; `UiConfig.language` is
required, and `LiveUiResolver.resolve(language)` either hands back this adapter or
raises `LiveUiResolutionException`.

The library reuses the core's localization, so this package adds no delegates.
The host does need them installed: with no Material application widget above it,
the strings the composed controls and the library's own field ask for arrive
through `liveLocalizationsDelegates` and nothing else.

## Dependencies

- `live_uikit` (the contracts, tokens, resolver and diagnostics)
- `glass_morphism_plus` ^0.1.0 (the frosted surfaces, controls and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_glass
```

`test/adapter/glass_contract_test.dart` verifies the stable id/display name, that
the declared capabilities and surfaces are the whole contract, that every control
and surface resolves to this adapter through the core resolver, and that a
language this build did not register raises `LiveUiResolutionException`
(§16/§17).

## Known limitations

- Four controls are the library's own widgets; the other thirteen are composed from
  its `GlassContainer` surface and `GlassTheme` values, because
  `glass_morphism_plus` ^0.1.0 ships no switch, box, slider, segmented track,
  indicator, dropdown, tab strip, page frame, header, destination bar, message,
  dialog or page switcher.
- `GlassAppBar` is deliberately not used for `app bar`: it is a Material `AppBar`
  with a frosted `flexibleSpace`, it asserts `No MaterialLocalizations found.`
  outside a Material host, it takes the loose constraints a bar is handed rather
  than its own height, and its `bottom` slot wants a `PreferredSizeWidget` instead
  of the dispatched strip (§9).
- The composed controls route their tap, hover, press and focus through the core's
  `LiveBox` rather than through `GlassContainer.onTap`, because the library's ink
  host builds a Material widget with a focus node of its own that the spec's
  `focusNode` could not reach; `GlassButton`, `GlassCard` and `GlassListTile`
  expose no focus slot either, so those spec fields are recorded as unmappable
  (§15).
- `errorText` has no slot in `GlassTextField`, so it is drawn as a caption under
  the field rather than as a border state; `selected` and `bordered` have no
  frosted equivalent on the card, and `selected` and the inline `style` have no
  affordance on the button (§9).
- A Glass `select` opens its option list in flow, under the field, since the
  contract wants a widget that renders where it is placed and the caller owns the
  overlay (§9).
- Test coverage is present at four layers: `test/adapter/` (contract, capability
  and surface declarations plus the resolver), `test/theme/` (§8.1 mapping and the
  §8.3 runtime re-skin), `test/widgets/` (every control driven through the real
  dispatch path, the composed app shell and the app host pumped with no Material
  app above it), and `test/integration/` (the whole resolution surface, and a
  re-theme that must not cost the caller its controller). What remains untested is
  the part that needs hardware: focus traversal, Android TV D-pad, and the
  platform claims in §13.
- The frosted `blur` radius stays a fixed `16` rather than a token value: the
  library exposes it as a plain double with no affordance introspection, and the
  effect budget is governed by `UiConfig.transparency`, which reports
  `unsupportedEffect` — the one code `LiveUiDiagnosticCode` has — when the device
  cannot afford it (§8.1/§13).
