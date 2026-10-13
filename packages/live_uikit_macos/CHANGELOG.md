# Changelog

All notable changes to `live_uikit_macos` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- macOS `LanguageAdapter` (`MacosLanguageAdapter`, stable id `macos`) registered by
  the composition root via `createMacosUiAdapter()` / `macosUiAdapter`.
- Theme mapping from the resolved `DesignToken` to `MacosThemeData`, installed
  through a `MacosTheme` scope (`theme/`).
- Native macOS builders for button, text field, checkbox and slider; other
  controls fall back to the core shared token renderer.
- `macosUiCapabilities` declaring the natively rendered controls.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Known limitations

- No widget-level or cross-style integration tests yet; card, switch, segmented,
  progress, select and tab bar use the shared renderer.
