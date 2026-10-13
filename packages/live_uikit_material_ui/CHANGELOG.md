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

### Known limitations

- No widget-level or cross-style integration tests yet; select and tab bar are not
  native.
