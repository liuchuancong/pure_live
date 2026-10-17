# Changelog

All notable changes to `live_uikit_macos` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- macOS `LanguageAdapter` (`MacosLanguageAdapter`, stable id `macos`) registered by
  the composition root via `createMacosAdapter()` / `macosAdapter`. The class
  implements the core `LanguageAdapter` interface directly.
- Theme mapping from the resolved `DesignToken` to `MacosThemeData`, installed
  through a `MacosTheme` scope (`theme/`).
- A builder per control for all seventeen of them (`lib/src/widgets/`), each declared
  in `macosCapabilities`: button, card, text field, switch, checkbox, slider,
  segmented, progress, select, tab bar, scaffold, app bar, list row, nav bar, toast,
  dialog and tab view.
- Both structural surfaces, declared in `macosSurfaces` and drawn by their own
  builders: the app host is `MacosApp`, and the shell is the library's own
  `SidebarItems` navigation list set in a fixed-width column the shell draws itself.
- Contract/capability/resolver test (`test/adapter/`), theme mapping and re-skin test
  (`test/theme/`), widget tests for every control and both surfaces
  (`test/widgets/macos_native_controls_test.dart`), and an integration suite
  (`test/integration/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- This package answers the whole contract itself. `MacosLanguageAdapter` implements
  `LanguageAdapter` — an `abstract interface class` with seventeen control builders,
  `wrap` and the two structural-surface methods — and draws every member of it from
  `macos_ui`: a library widget where the library has one, composed from that library's
  own parts where it does not, as `macosCapabilities` and `macosSurfaces` declare.
- The documentation now states the contract as the code implements it. Eleven controls
  take a `macos_ui` widget — `PushButton`, `MacosTextField`, `MacosSwitch`,
  `MacosCheckbox`, `MacosSlider`, `MacosSegmentedControl`, `ProgressBar` /
  `ProgressCircle`, `MacosPopupButton`, `MacosScaffold`, `ToolBar` and `MacosListTile` —
  and six are composed out of that library's own parts, because `macos_ui` 2.2.2 has no
  widget of that shape: card, tab bar, nav bar, toast, tab view, and a dialog whose
  actions `MacosAlertDialog` has no slots for. `README.md` and
  `live-uikit-macos.md` §2/§3/§4/§7/§9/§15/§16/§17/§18/§19/§20 say which is which, and
  each builder's doc comment names its own case.
- Resolution prose follows the core: `LiveUiResolver.resolve` returns this adapter or
  throws `LiveUiResolutionException`, `requireControl`/`requireSurface` throw
  `LiveUiCapabilityException` when a declaration and an override disagree, and the only
  diagnostic left is `unsupportedEffect`, which reports an effect the device cannot
  afford rather than a missing implementation.
- The widget suite now asserts that a caller's `FocusNode` is the node the library's text
  field takes focus with (`requestFocus()` then `hasFocus`), so a page that drives its
  own focus works in this language. §16 lists the cases that exist rather than the ones
  that were planned, and §19's keyboard/accessibility line now says which half is
  proven and which still needs a device.
- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe. This adapter
  does not map it: its button is the library's own widget, which paints its own surface,
  and §9 records that trade.
- An icon-only or toggled button reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected`. `iconOnly` is honoured — the builder paints
  the bare glyph with the tooltip as its accessible label — while `selected` stays
  documented as unmapped here, since `PushButton` has no selected affordance
  (§9, `docs/decisions/0004`).
- The slider passes `min`/`max` to the library instead of relying on its 0..1 defaults;
  the text field takes `textInputAction`, `maxLines`, `prefix`/`suffix` and the inline
  `Style`, and draws the error caption; the button takes `expand`, `tooltip` and the
  accessible `semanticLabel`.
- Added `test/theme/` and `test/widgets/` assertions for those fields, and the
  `test/integration/` suite covering resolution of the whole contract and the typed
  `select` value coming back through the library's own pop-up button.

### Fixed

- Checkbox: a null `onChanged` disables the box instead of installing a closure that
  swallowed the value (§9/§15).
- A disabled slider is drawn from this library's own parts — `ProgressBar` as the rail
  plus its published `MacosColors.sliderThumbColor` thumb, under an `IgnorePointer` —
  because `MacosSlider.onChanged` is required and non-nullable, and the previous closure
  made a dead slider look live (§9/§15).
- Select: a current value the item list does not carry, and repeated or null item values,
  are filtered before `MacosPopupButton` is built, so its "exactly one" assert is
  satisfied and an off-list value reads as nothing chosen rather than crashing (§9/§15).
- Tab bar: a tab given a glyph keeps it. `MacosTab` has no icon slot, so the strip is
  assembled with `MacosIcon` in front of each cell instead of being handed to
  `MacosSegmentedControl` (§9).

### Known limitations

- Card, tab bar, nav bar, toast, tab view and any dialog its `MacosAlertDialog` cannot
  take are composed from `macos_ui`'s own parts, because the library carries no card, no
  box, no transient message, no bodyless tab strip and no bottom bar (§9).
- The shell is composed for the same reason: in `macos_ui` 2.2.2 `Sidebar` and
  `SidebarItem` are descriptor classes rather than widgets, and the only reader of
  `Sidebar` is `MacosWindow`, so the sidebar column is neither drag-resizable nor
  window-breakpoint aware, `trailing` is pinned by the shell's own column, and a disabled
  destination is made inert by the shell because `SidebarItem` has no disabled field (§9).
- `PushButton`, `MacosSlider`, `MacosSwitch`, `MacosCheckbox`, `MacosListTile` and the
  card's `MacosSheet` accept no caller focus node, so `focusNode`/`autofocus` are
  unmappable on the button, slider, switch, checkbox, list row and card (§9).
- The segmented track has no disabled state (an inert spec is wrapped in `IgnorePointer`)
  and no `expand` slot; the progress widgets have no `showLabel` slot; the tab strip
  ignores `spacing`; the page frame has no floating-action, `extendBodyBehindAppBar` or
  `avoidKeyboard` slot; the `ToolBar` has no `bottom` slot, so a strip is stacked under
  it; and the page switcher draws neither `onIndexChanged` nor `duration`, because a
  macOS pane is never dragged and never animates a body swap (§9).
