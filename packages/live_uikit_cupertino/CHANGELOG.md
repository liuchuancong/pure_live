# Changelog

All notable changes to `live_uikit_cupertino_ui` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to semantic versioning for released packages.

## Unreleased

### Added

- Cupertino UI `LanguageAdapter` (`CupertinoUiLanguageAdapter`, stable id
  `cupertino`) registered by the composition root via `createCupertinoUiAdapter()`
  / `cupertinoUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Cupertino theme scope
  (`theme/`).
- Native builders for button, text field, switch and slider; every other control
  falls back to the core shared token renderer.
- `cupertinoUiCapabilities` declaring the natively rendered controls.
- `cupertinoUiLocalizationsDelegates` for the fork's own Cupertino localizations.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- The widget suite now asserts that a caller's `FocusNode` is the node the fork's text
  field takes focus with (`requestFocus()` then `hasFocus`), so a page that drives its
  own focus works in this language. §9/§16 lists the cases that exist rather than the ones
  that were planned, and §19's keyboard/accessibility line now says which half is
  proven and which still needs a device.
- Both focus halves are asserted: the field takes the caller's node into its focus
  tree, and the button carries the caller's node plus its `autofocus` flag.
- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe, which
  the shared token renderer now honours. This adapter does not map it: its button is
  the library's own widget, and §9 records that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected` instead of being painted by the core's token
  box; textless rendering comes for free from the shared `buttonLabel`, while
  `selected` stays documented as unmapped here (§9, `docs/decisions/0004`).

- Button honours `expand` and `tooltip` (through the core's language-neutral
  `LiveTooltip`, since this fork has no hint slot); the text field passes
  `textInputAction`, `prefix`, `suffix` and the inline `Style` through and draws the
  `errorText` caption the way the token renderer does.
- Added `test/theme/` and `test/widgets/` assertions for those fields, and a new
  `test/integration/` suite for the resolution surface and the switch to the core base and
  back.

### Fixed

- Slider: a null `onChanged` reaches the fork as null instead of as a no-op listener, so a
  dead slider no longer renders as draggable (§9/§15).

### Known limitations

- Only button, text field, switch and slider are native.
- Focus traversal, Android TV D-pad and touch-target sizing on device still need hardware.
