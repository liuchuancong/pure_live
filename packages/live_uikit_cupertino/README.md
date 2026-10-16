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
- Build native Cupertino widgets for all seventeen: **button, card, text field,
  switch, checkbox, slider, segmented, progress, select, tab bar, scaffold, app
  bar, list row, nav bar, toast, dialog, tab view**. Twelve are a one-for-one
  mapping; five are composed out of the fork's own parts because it has no widget
  for the job —
  `card` is `CupertinoListSection.insetGrouped` (the library ships no card and no
  box), `select` is a `CupertinoMenuAnchor` of `CupertinoMenuItem`s behind a
  `CupertinoButton` (iOS chooses from a pull-down menu, and `CupertinoPicker` is a
  wheel that cannot be one inline widget), `toast` is the library's
  `CupertinoPopupSurface` HUD panel (`CupertinoToast` is a community widget, not
  part of this fork), `tab bar` is a row of `CupertinoButton`s, because the
  fork's one index-controlled strip is the *bottom* bar the nav bar already takes,
  and `tab view` is a `PageView` wearing `CupertinoScrollBehavior`, because
  `CupertinoTabView` is a per-tab `Navigator` that takes its pages from a route
  table while the contract hands them over built (§9). The dialog is mapped:
  `CupertinoAlertDialog` is a plain widget with no route in it, so the core keeps
  the barrier, the fade and the dismissal and this draws only the card.
- Own both structural surfaces (§ surfaces): the host is `cu.CupertinoApp`, and
  the shell is an iOS sidebar composed out of the fork's own surface pieces — a
  `CupertinoListSection` of `CupertinoListTile` rows — because the library ships
  no rail widget: `CupertinoTabScaffold` binds a bottom bar to a
  `CupertinoTabView` body per tab, and `CupertinoTabBar` is that same bar on its
  own, which the nav bar already uses.
- Declare the whole contract in `cupertinoCapabilities`: a Cupertino page reports
  no `controlUnsupported` downgrade, and nothing inside a Cupertino frame is a
  token renderer (§16/§17).
- Expose `cupertinoLocalizationsDelegates` (the fork's own Cupertino
  localizations, distinct from Flutter's) for the composition root to install.

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Every control of the contract is built here, in Cupertino's own idiom: where the
fork has no widget, the builder composes one out of the library's parts rather
than falling through to the core shared token renderer.

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
- A track of fewer than two segments and a bottom bar with no destinations are
  drawn by the shared renderer: `CupertinoSegmentedControl` and `CupertinoTabBar`
  assert both away, so a spec they would throw on is not a crash in the library
  (§15).
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every native control driven through the real dispatch path), and
  `test/integration/` (resolution surface across the contract and a switch to the
  the shared `token` base and back with caller-owned state preserved). What remains
  untested is the part that needs hardware: focus traversal, Android TV D-pad, and
  the platform claims in §13.
