# Changelog

All notable changes to `live_uikit_glass` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- Glass `LanguageAdapter` (`GlassLanguageAdapter`, stable id `glass`) registered by
  the composition root via `createGlassUiAdapter()` / `glassUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Glass theme scope (`theme/`).
- Native builders for button, card and text field; every other control falls back
  to the core shared token renderer.
- `glassUiCapabilities` declaring the natively rendered controls.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Known limitations

- No widget-level or cross-style integration tests yet; only button, card and text
  field are native, and blur effects must degrade gracefully where unsupported.
