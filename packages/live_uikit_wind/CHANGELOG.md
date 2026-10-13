# Changelog

All notable changes to `live_uikit_wind` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres
to semantic versioning for released packages.

## Unreleased

### Added

- Wind `LanguageAdapter` (`WindLanguageAdapter`, stable id `wind`) registered by
  the composition root via `createWindUiAdapter()` / `windUiAdapter`.
- Theme mapping from the resolved `DesignToken` into a Wind theme scope (`theme/`).
- Native builders for button, switch and checkbox; every other control falls back
  to the core shared token renderer.
- `windUiCapabilities` declaring the natively rendered controls.
- Contract/capability/resolver test (`test/adapter/`).
- `README.md` documenting purpose, boundaries, usage, testing and limitations.

### Known limitations

- No widget-level or cross-style integration tests yet; only button, switch and
  checkbox are native.
