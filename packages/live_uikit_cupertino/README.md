# live_uikit_cupertino

The Cupertino UI design-language adapter for PureLive's unified UI system
(`live_uikit`). It renders every control and both structural surfaces of the core's
neutral contract with `cupertino_ui` — Flutter's Cupertino fork — mapping a library
widget where one exists and composing one from the library's own parts where it
does not, and it maps the resolved design token into that library's theme.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens and runtime
dispatch. This package supplies the **Cupertino UI** implementation: it `implements`
the `LanguageAdapter` interface for `LiveDesignLanguage.cupertino`, so an
application can select `cupertino` at runtime and have its whole UI drawn by
`cupertino_ui`, without any business page importing it.

`cupertino_ui` is a fork of Flutter's Cupertino widgets, so this adapter mirrors
Cupertino's own coverage rather than inventing a new one.

## Responsibilities

- Implement `LanguageAdapter` directly for `LiveDesignLanguage.cupertino` (stable
  id `cupertino`). `LanguageAdapter` is an abstract interface with no base
  implementation behind it, so every control and surface is built here.
- Map the resolved `DesignToken` into the Cupertino theme and install it through a
  theme scope (never a nested application shell).
- Build native Cupertino widgets for all seventeen: **button, card, text field,
  switch, checkbox, slider, segmented, progress, select, tab bar, scaffold, app
  bar, list row, nav bar, toast, dialog, tab view**. Twelve of them map one-for-one
  onto a `cupertino_ui` widget — `button` is `CupertinoButton` (`.filled` unless
  ghost), `text field` is `CupertinoTextField`, `switch` is `CupertinoSwitch`,
  `checkbox` is `CupertinoCheckbox`, `slider` is `CupertinoSlider`, `segmented` is
  `CupertinoSegmentedControl`, `progress` is `CupertinoLinearActivityIndicator` for
  a known fraction and `CupertinoActivityIndicator` for a null one, `scaffold` is
  `CupertinoPageScaffold`, `app bar` is `CupertinoNavigationBar`, `list row` is
  `CupertinoListTile`, `nav bar` is `CupertinoTabBar`, and `dialog` is
  `CupertinoAlertDialog` (a plain widget with no route in it, so the core keeps the
  barrier, the fade and the dismissal and this draws only the card). Five are
  composed out of the fork's own parts because it has no widget for the job —
  `card` is `CupertinoListSection.insetGrouped` (the library ships no card and no
  box), `select` is a `CupertinoMenuAnchor` of `CupertinoMenuItem`s behind a
  `CupertinoButton` (iOS chooses from a pull-down menu, and `CupertinoPicker` is a
  wheel that cannot be one inline widget), `toast` is the library's
  `CupertinoPopupSurface` HUD panel (`CupertinoToast` is a community widget, not
  part of this fork), `tab bar` is a row of `CupertinoButton`s, because the fork's
  one index-controlled strip is the *bottom* bar the nav bar already takes, and
  `tab view` is a `PageView` wearing `CupertinoScrollBehavior`, because
  `CupertinoTabView` is a per-tab `Navigator` that takes its pages from a route
  table while the contract hands them over built (§9).
- Own both structural surfaces (§ surfaces): the host is `cu.CupertinoApp`, and
  the shell is an iOS sidebar composed out of the fork's own surface pieces — a
  `CupertinoListSection` of `CupertinoListTile` rows — because the library ships
  no rail widget: `CupertinoTabScaffold` binds a bottom bar to a `CupertinoTabView`
  body per tab, and `CupertinoTabBar` is that same bar on its own, which the nav
  bar already uses.
- Declare the whole contract in `cupertinoCapabilities` and both surfaces in
  `cupertinoSurfaces`: every control and surface of the contract resolves to this
  adapter, so a well-formed Cupertino registry raises neither
  `LiveUiResolutionException` nor `LiveUiCapabilityException` (§16/§17).
- Expose `cupertinoLocalizationsDelegates` (the fork's own Cupertino localizations,
  distinct from Flutter's) for the composition root to install.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Every control of the contract is built here, in Cupertino's own idiom: where the
fork has no widget, the builder composes one out of the library's parts.

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
);

// In the app shell, append the fork's delegates to the core's:
//   MaterialApp(
//     localizationsDelegates: [
//       ...liveLocalizationsDelegates,
//       ...cupertinoLocalizationsDelegates,
//     ],
//   )
```

`LanguageRegistry` takes only `adapters`, so every language this build claims must
bring its own adapter; a language it did not register is a fault the resolver raises,
not a foreign skin painted over the page.

## Dependencies

- `live_uikit` (the contracts and runtime dispatch)
- `cupertino_ui` ^1.1.2 (the native widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_cupertino
```

`test/adapter/cupertino_contract_test.dart` verifies the stable id/display name,
that the declared capabilities are the whole contract and match the controls the
adapter overrides, and the core resolver's behaviour: a registered language resolves
to this adapter, every `requireControl`/`requireSurface` check passes, and a language
this build did not register raises `LiveUiResolutionException` (§16/§17).

## Known limitations

- The library has no navigation column, so the shell's rail is composed rather
  than mapped: `CupertinoTabScaffold` binds a bottom bar of two to five
  destinations to a `CupertinoTabView` body per tab — a body of its own, which the
  router-owned shell cannot accept — and `CupertinoTabBar` is that bar alone. The
  pane is therefore a `CupertinoListSection` of `CupertinoListTile` rows, tinted
  with the library's roles; note that `CupertinoThemeData` here has no
  `accentColor`, so the accent is its `primaryColor` (§ surfaces).
- `CupertinoListTile` has no disabled state, so a disabled destination is drawn
  inert by this package: kept in the layout, tinted with `tertiaryLabel`, given no
  `onTap`.
- The fork asserts a segmented track of at least two children and a bottom bar of
  at least one in-range destination, so a one-label track and a one-cell, empty or
  out-of-range bar are drawn here as the library's own inert press cells (a label
  in the unselected colour, reporting no tap) rather than handed to the widget that
  would throw (§15).
- The button carries no toggled or inline-style state: `LanguageButtonSpec.selected`
  and `LanguageButtonSpec.style` are recorded as unmapped, because Cupertino's
  button has no selected affordance to hand them to and painting a caller's `Style`
  would mean overlaying the library's own widget (§9).
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every control driven through the real dispatch path), and
  `test/integration/` (resolution surface across the contract, with caller-owned
  state preserved). What remains untested is the part that needs hardware: focus
  traversal, Android TV D-pad, and the platform claims in §13.
