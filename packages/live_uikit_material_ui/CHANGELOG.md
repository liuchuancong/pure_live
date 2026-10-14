# Changelog

All notable changes to `live_uikit_material_ui` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to semantic versioning for released packages.

## Unreleased

### Added

- Material UI `LanguageAdapter` (`MaterialUiLanguageAdapter`, stable id
  `materialUi`) registered by the composition root via `createMaterialUiAdapter()`
  / `materialUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Material theme scope
  (`theme/`).
- Native builders for button, card, text field, switch, checkbox, slider,
  segmented and progress; select and tab bar fall back to the core shared token
  renderer.
- `materialUiCapabilities` declaring the natively rendered controls.
- `materialUiLocalizationsDelegates` for the fork's own Material localizations.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Changed

- `LanguageButtonSpec` gained `style`, the caller's top layer of the recipe, which
  the shared token renderer now honours. This adapter does not map it: its button is
  the library's own widget, and §9 records that trade.
- An icon-only or toggled button now reaches this adapter through
  `LanguageButtonSpec.iconOnly`/`.selected` instead of being painted by the core's token
  box; textless rendering comes for free from the shared `buttonLabel`, while
  `selected` stays documented as unmapped here (§9, `docs/decisions/0004`).

- The theme scope now installs the fork ink surface (`mu.Material`, transparent) under
  `mu.Theme`, so a host no longer has to nest one before the fork's controls can build.
- Button honours `expand` and `tooltip`; the slider keeps the caller `focusNode`; the card
  honours `dense`, the inline `Style` and interactive-only focus; the text field applies
  the inline `Style`; the segmented control uses the fork's `expandedInsets`.
- `LanguageProgressSpec.showLabel` degradation is documented at the builder rather than
  hand-drawn (§15).
- Added `test/widgets/` assertions for variant mapping, seam interactive-state parity,
  progress indeterminate and `barColor` tint, the disabled-slider fallback, RTL layout, and
  the SDK-widget-absent check; new `test/integration/` suite for the §11 switch in both
  directions with caller-owned state preserved.

### Fixed

- Checkbox and segmented: a null `onChanged` now disables the control instead of
  installing a closure that swallowed the value, which left a dead control rendering as
  live (§9/§15).

### Known limitations

- Select and tab bar are served by the shared token renderer, not by native
  `material_ui` widgets; a disabled slider falls back for the same reason (§9).
- Focus traversal, Android TV D-pad and the platform claims in §13 still need hardware;
  a cross-adapter switch is an application-level test because §3.3 forbids
  adapter-to-adapter dependencies.
