# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- Added the token set section 5.4 asks a style adapter to map: `ColorRole` (13 semantic roles), `ControlState`,
  `FocusShape`, `SpaceToken`, `RadiusToken`, `Density`, `TypeRole`, `MotionProfile`, `ControlKind`,
  `FocusVisual`, `InputMode` and `PlatformProfile`.
- Added `DesignTokens` with `resolveDesignTokens`, which applies the rules that are not negotiable rather than
  leaving each surface to rediscover them: text scaling is never reduced below 1.0, a remote input raises the
  small type roles to a ten-foot-readable floor, `reduceMotion` zeroes durations instead of shortening them,
  and a remote never scales a focused control (growth moves the rows below the focus, which reads as the
  interface flinching).
- Added the aimability and focus checks `ControlKind.isAimable` and `FocusVisual.isFindable`, with a separate
  inline floor for chips because their row padding participates in the hit area. These exist so a too-small
  target fails a test instead of failing someone's thumb.
- Added `AppearanceSettings` (`style` / `brightness` / `density` / `reduceMotion` / `textScale` /
  `preferredInput` / `background`) as the one persisted blob a settings screen writes. The style stays a
  **string**, so a pick made by a build that registers a newer style is still loadable here, and an absent
  `density` means "follow the platform" rather than "standard".
- `BackgroundConfig` gained nothing risky: an unknown kind still reads as `none` instead of throwing, which is
  what a hand-edited or future-version row has to degrade to.
- `PureLiveSpacing` and `PureLiveRadius` keep the numbers ui_kit already renders, so adopting the enums is not
  a silent restyle. Dart cannot fold an enum field access into a constant expression, so the two spellings are
  literals with a test asserting they stay equal.
- Still no Flutter import, on purpose: a token that needed a BuildContext could only be reviewed as a
  screenshot.
