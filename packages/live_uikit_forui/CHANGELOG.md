# Changelog

## 0.1.0

- Initial version.
- ForUI adapter for `live_uikit`: native `FButton`/`FButton.icon`, `FCard`,
  `FTextField`, `FSwitch` and `FCheckbox` builders; the remaining five controls fall
  back to the shared token renderer with `controlUnsupported` diagnostics.
- Theme mapping installs forui's neutral light/dark variant from the resolved token;
  recoloring is pinned as unmappable by test.
- Registration API (`foruiUiAdapter`, `createForuiUiAdapter`, `foruiUiAdapterId`,
  `foruiLocalizationsDelegates`).
