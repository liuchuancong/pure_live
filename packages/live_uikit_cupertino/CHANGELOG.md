# Changelog

All notable changes to `live_uikit_cupertino` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to semantic versioning for released packages.

## Unreleased

### Added

- Cupertino UI `LanguageAdapter` (`CupertinoLanguageAdapter`, stable id
  `cupertino`) registered by the composition root via `createCupertinoAdapter()`
  / `cupertinoAdapter`. It `implements` the core interface directly — there is no
  base class to extend — and covers the whole contract.
- Theme mapping from the resolved `DesignToken` into a Cupertino theme scope
  (`theme/`).
- Builders for all seventeen controls. Twelve map one-for-one onto a `cupertino_ui`
  widget (button, text field, switch, checkbox, slider, segmented, progress,
  scaffold, app bar, list row, nav bar, dialog); five are composed from the fork's
  own parts where the library has no widget for the job — card
  (`CupertinoListSection.insetGrouped`), select (`CupertinoMenuAnchor` of
  `CupertinoMenuItem`s), toast (`CupertinoPopupSurface`), tab bar (a row of
  `CupertinoButton`s) and tab view (`PageView` with `CupertinoScrollBehavior`).
- Both structural surfaces: the app host (`cu.CupertinoApp`) and the composed app
  shell (`cupertinoSurfaces`).
- `cupertinoCapabilities` declaring all seventeen controls and
  `cupertinoSurfaces` declaring both surfaces.
- `cupertinoLocalizationsDelegates` for the fork's own Cupertino localizations.
- Contract/capability/resolver tests (`test/adapter/`), theme tests
  (`test/theme/`), widget tests (`test/widgets/`) and an integration suite
  (`test/integration/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- Documentation realigned to the current contract throughout this package's files:
  `LanguageAdapter` is an abstract interface implemented directly, the resolver
  returns this adapter or raises `LiveUiResolutionException` for a language this
  build did not register, `requireControl`/`requireSurface` raise
  `LiveUiCapabilityException` for a declaration without a matching override, and the
  only runtime diagnostic is `unsupportedEffect`. The README, `live-uikit-cupertino.md`
  and the source/test doc comments now state that every control and surface is
  served here, mapped onto a library widget or composed from its parts.
- The widget suite asserts that a caller's `FocusNode` is the node the fork's text
  field takes focus with (`requestFocus()` then `hasFocus`), so a page that drives its
  own focus works in this language. §9/§16 lists the cases that exist rather than the
  ones that were planned, and §19's keyboard/accessibility line now says which half is
  proven and which still needs a device.
- Both focus halves are asserted: the field takes the caller's node into its focus
  tree, and the button carries the caller's node plus its `autofocus` flag.
- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe. This
  adapter does not map it: its button is the library's own widget and paints its own
  surface, and §9 records that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected`. Icon-only content is composed here (the
  glyph alone, never the empty label); `selected` stays documented as unmapped
  because Cupertino's button has no toggled affordance (§9, `docs/decisions/0004`).
- Button honours `expand` and `tooltip` (through the core's language-neutral
  `LiveTooltip`, since this fork has no hint slot); the text field passes
  `textInputAction`, `prefix`, `suffix` and the inline `Style` through and draws the
  `errorText` caption under the field.
- A segmented track of fewer than two labels and a bottom bar that is empty, has a
  single destination, or has an out-of-range index are drawn as the library's own
  inert press cells rather than handed to `CupertinoSegmentedControl`/`CupertinoTabBar`,
  which assert those shapes away (§15).

### Fixed

- Slider: a null `onChanged` reaches the fork as null instead of as a no-op listener, so a
  dead slider no longer renders as draggable (§9/§15).

### Known limitations

- The button maps neither `selected` nor an inline `style`, and the card maps neither
  `bordered` nor `focusNode`/`autofocus`; each builder records why (§9).
- Focus traversal, Android TV D-pad and touch-target sizing on device still need hardware.
