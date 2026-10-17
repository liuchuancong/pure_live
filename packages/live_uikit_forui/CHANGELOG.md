# Changelog

## Unreleased

### Changed

- `ForuiLanguageAdapter` implements `LanguageAdapter` end to end in this package: all
  seventeen controls are drawn from `forui` — fourteen as one-for-one widget mappings, and
  `segmented`, `tab bar` and `tab view` composed out of the library's own parts or the
  widgets layer — and both structural surfaces are owned, the application hosted on
  `WidgetsApp` with `FTheme` above the routed tree and the shell composed from `FSidebar`
  with its bottom form delegated to `navBar`. `foruiCapabilities` and `foruiSurfaces`
  declare that set, the README, the specification, the registration snippet and the tests
  state the same thing, and each builder records the spec fields `forui` 0.27.5 has no
  slot for instead of painting them by hand.

## 0.1.0

- Initial version.
- ForUI adapter for `live_uikit`: native `FButton`/`FButton.icon`, `FCard`,
  `FTextField`, `FSwitch` and `FCheckbox` builders; the remaining five controls fall
  back to the shared token renderer with `controlUnsupported` diagnostics.
- Theme mapping installs forui's neutral light/dark variant from the resolved token;
  recoloring is pinned as unmappable by test.
- Registration API (`foruiUiAdapter`, `createForuiUiAdapter`, `foruiUiAdapterId`,
  `foruiLocalizationsDelegates`).
