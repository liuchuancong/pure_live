# Changelog

All notable changes to `live_uikit_neumorphic` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to semantic versioning for released packages.

## Unreleased

### Added

- Neumorphic `LanguageAdapter` (`NeumorphicLanguageAdapter`, stable id
  `neumorphic`) registered by the composition root via `createNeumorphicUiAdapter()`
  / `neumorphicUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Neumorphic theme scope
  (`theme/`).
- Native builders for button, card, text field, switch, checkbox and slider; other
  controls fall back to the core shared token renderer.
- `neumorphicUiCapabilities` declaring the natively rendered controls.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Known limitations

- No widget-level or cross-style integration tests yet; segmented, progress,
  select and tab bar use the shared renderer.
