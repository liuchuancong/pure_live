# live_uikit_macos

The macOS design-language adapter for PureLive's unified UI system (`live_uikit`).
It renders the core's neutral control specifications with native `macos_ui`
widgets and maps the resolved design token into `MacosThemeData`.

## Purpose

`live_uikit` defines the design-language-agnostic contracts, tokens and runtime
dispatch, together with the `LanguageAdapter` interface that every design language
implements. This package supplies the **macOS** implementation so an application
can select `macos` at runtime and have its controls drawn by `macos_ui`, without
business pages importing `macos_ui`.

## Responsibilities

- Implement `LanguageAdapter` for `LiveDesignLanguage.macos` (stable id `macos`).
  `MacosLanguageAdapter` implements that interface directly and answers every
  member of it: `language`, `id`, `displayName`, `capabilities`, `surfaces`,
  `wrap`, the seventeen control builders, `appHost` and `shell`.
- Map the resolved `DesignToken` into a `MacosThemeData` and install it through a
  `MacosTheme` scope (never a nested `MacosApp`).
- Build native macOS widgets for all seventeen controls — **button, card, text field,
  switch, checkbox, slider, segmented, progress, select, tab bar, scaffold, app bar,
  list row, nav bar, toast, dialog, tab view**. Eleven of them are a one-for-one
  mapping onto the library's own widget: `PushButton`, `MacosTextField`,
  `MacosSwitch`, `MacosCheckbox`, `MacosSlider`, `MacosSegmentedControl`,
  `ProgressBar` / `ProgressCircle`, `MacosPopupButton`, `MacosScaffold`, `ToolBar`
  and `MacosListTile`. Six are composed out of that library's own parts, because
  `macos_ui` 2.2.2 has no widget of that shape: the card and the toast surface are
  its `MacosSheet` panel mounted inline, since the library carries no card, no box
  and no transient message, and so is a dialog whose actions its `MacosAlertDialog`
  has no slots for; the tab bar and the nav bar are rows of the library's `MacosTab`
  cell with its `MacosIcon` in front, because `MacosTabView` is a whole tab *view*
  with one body per tab, the real segmented control has a text-only cell, and the
  library has no bottom bar; and the tab view under the strip is the same refusal —
  that widget fuses the strip with its bodies and selects through a
  `MacosTabController` of its own, while this contract keeps the index with the
  caller, so the pane is the library's own treatment around an `IndexedStack` (§9).
- Own **both** structural surfaces (§ surfaces): the app host is the library's own
  `MacosApp`, and the app shell is its navigation list — `SidebarItems` of
  `SidebarItem` rows, the selected one painted with the system-accent chip — set
  inside a column the shell draws beside the page. The shell is composed rather
  than mapped, and the reason is a real constraint of this library: in `macos_ui`
  2.2.2 neither `Sidebar` nor `SidebarItem` is a widget at all, both are plain
  descriptors, and the only reader of `Sidebar` is `MacosWindow`, which is not what
  this package mounts. So the shell contributes one sidebar and no window chrome,
  `MacosScaffold` keeps the page frame, a `bottom` request goes back through this
  package's `navBar`, and a shell with fewer than two destinations — or one asked
  for `none` — draws no navigation.
- Declare that coverage rather than imply it: `macosCapabilities` lists all
  seventeen controls and `macosSurfaces` lists both surfaces. The core resolver
  checks the declaration against the method, so a control or surface declared
  without a matching override is a `LiveUiCapabilityException` (§16/§17).

## What this package must not own

- Global theme preferences, persistence, or the style-selector UI.
- Shared design-token definitions or global configuration storage.
- State management (Riverpod/GetX), navigation, business pages, or playback.
- Direct dependencies on other style adapters.

Two spec shapes are assembled here instead of handed to the library's widget,
because `macos_ui` refuses them rather than because this adapter did not try: a
slider with no callback (`MacosSlider.onChanged` is required and non-nullable, so
the inert form is drawn from the library's `ProgressBar` rail plus its published
thumb colour), and a select whose current value is not one of its items or whose
items repeat (`MacosPopupButton` asserts "exactly one", so the off-list value
becomes the library's own nothing-chosen state and shows the placeholder) (§9/§15).

## Public entry point

`package:live_uikit_macos/live_uikit_macos.dart` — exports only the registration
API (§6). Do not import `src/` from another package.

## Installation and usage

A Pub-workspace member; business packages depend only on `live_uikit`. The
application composition root registers the adapter. `LanguageRegistry` takes the
adapter map and nothing else:

```dart
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';

const registry = LanguageRegistry(
  adapters: {LiveDesignLanguage.macos: macosAdapter},
);
```

`UiConfig.language` is required, and a language this build did not register raises
`LiveUiResolutionException` instead of rendering in another one's skin.
`macos_ui` reuses the core's Material/Cupertino localization, so this package adds
no delegates of its own (§14).

## Dependencies

- `live_uikit` (the contracts, tokens and runtime dispatch)
- `macos_ui` ^2.2.2 (the native macOS widgets and theme)
- Flutter SDK

## Testing

```powershell
flutter pub get
flutter test packages/live_uikit_macos
```

`test/adapter/macos_contract_test.dart` verifies the stable id and display name,
that the declared capabilities and surfaces are the whole contract, and the core
resolver's dispatch of every control to this adapter (§16/§17).

## Known limitations

- The card, the toast surface, the two strips and the page switcher are composed
  from `macos_ui`'s own parts (`MacosSheet`, `MacosTab`, `MacosIcon`, and the
  library's pane metrics around an `IndexedStack`) because the library carries no
  card, no box, no transient message, no bodyless tab strip and no bottom bar; they
  are macOS by its own visual vocabulary, but they are not one widget the library
  ships.
- A dialog becomes the library's `MacosAlertDialog` only when its actions fit that
  widget's two `large` `PushButton` slots. With no actions, with more than two, or
  with an action of another shape there is no slot to put it in, and the surface is
  composed from `MacosSheet` so the caller's buttons keep their own row and order.
- The shell's sidebar is fixed-width: `macos_ui` 2.2.2 has no mountable sidebar
  widget — `Sidebar` and `SidebarItem` are both descriptor classes, read by
  `MacosWindow` and `SidebarItems` respectively — so drag-resizing, the window
  breakpoint and the descriptor's `top`/`bottom` slots are unreachable, and the
  footer is pinned by the shell's own column. The library also has no disabled row
  (`SidebarItem` has no such field, `SidebarItems.onChanged` is required), so a
  disabled destination is made inert by the shell, and its `assert(currentIndex >= 0)`
  means a sidebar cannot show "nothing selected": an id that matches none selects the
  first row. Its rows size themselves to `134 + visualDensity`, so the rail is
  floored at 154 logical px instead of the token's 88.
- Test coverage is present at four layers: `test/adapter/` (contract and
  resolver), `test/theme/` (§8.1 mapping plus the §8.3 runtime re-skin),
  `test/widgets/` (every control driven through the real dispatch path, mapped and
  composed alike, plus the host and both shell forms), and `test/integration/`
  (resolution of the whole contract and a re-theme that leaves caller-owned state
  in the caller's hands). What remains
  untested is the part that needs hardware: focus traversal, Android TV D-pad, and
  the platform claims in §13.
- `PushButton`, `MacosSlider`, `MacosSwitch`, `MacosCheckbox` and `MacosSheet` take
  no caller focus node, so `focusNode`/`autofocus` are unmappable on the button,
  slider, switch, checkbox and card; the segmented track has no disabled state (an
  inert spec is wrapped in `IgnorePointer`) and no `expand` slot, the progress
  indicator has no `showLabel` slot, the tab strip ignores `spacing`, the page frame
  has no floating-action or keyboard slot (the core's overlay geometry places the
  action) and no `bottom` bar under the `ToolBar` (the bar is stacked with it), and
  the page switcher draws neither `onIndexChanged` nor `duration` because a macOS
  pane is never dragged and never animates (§9/§15).
- macOS styling can be selected on any platform, but native macOS window
  integration should not be assumed off-macOS (§13).
