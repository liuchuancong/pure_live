# Changelog

All notable changes to this package are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Sealed `BackgroundConfig` union (`SolidBackground`,
  `GradientBackground`, `ImageBackground`, `VideoBackground`,
  `BackgroundLayerStack`) with a per-variant `BackgroundOverlay`.
- Sealed `ImageSource` union covering network, asset and file sources.
- `BackgroundVideoSource` contract that keeps the package bound to no
  specific player kernel; the app wires `media_core` through it.
- `LiveBackground` dispatcher widget plus the per-variant
  `*BackgroundView` widgets and a shared `BackgroundOverlayView`.
- `AppVisibleScope` / `AppVisibilityObserver` pair that bridges
  `WidgetsBindingObserver` into the background rendering tree so video
  backgrounds pause when the app is not visible.
- `resolveBackgroundFallback` and `defaultBackgroundFallback` for
  uniform failure handling on image and video sources.
- Package-level `README.md`, this `CHANGELOG.md`, and a mirrored
  `test/src/` suite.

### Unreleased (2026-10 follow-up)

- `ImageBackground.underlay` and `VideoBackground.underlay`: a
  persistent bottom layer (usually a palette gradient or solid) that
  keeps the surface themed during cold-start, behind letterbox bars
  and after a load failure.
- `ImageBackground.blurSigma` and `VideoBackground.blurSigma`: a
  Gaussian blur applied to the media surface only, with `sigma == 0`
  short-circuiting the filter so the compositor skips a `saveLayer`.
  Uses `TileMode.decal` to avoid smearing border pixels outward.
- Automatic letterbox fill in `ImageBackgroundView`: when `BoxFit`
  would leave bars (`contain`, `fitWidth`, `fitHeight`, `none`,
  `scaleDown`), a blurred, cover-fitted copy of the same image is
  painted below the primary image so the bars read as theme rather
  than as flat color.
- `gaplessPlayback: true` on the image widget so swapping a URL
  keeps the previous frame visible until the new one decodes.
- `LiveBackground(config: null)` renders the same widget shape as a
  populated config with an empty base layer, so toggling a wallpaper
  on/off no longer remounts the caller's subtree.
- New `blurBackground` and `blurLetterboxCover` helpers exported
  internally via `lib/src/rendering/background_blur.dart`.

### Unreleased (2026-10 plugin-boundary pass)

Removed every policy the previous pass had baked in. The plugin now
holds no defaults; the caller decides.

- **Removed `defaultBackgroundFallback`, `kBackgroundFallbackColor`
  and `resolveBackgroundFallback`** (and the whole `lib/src/fallback/`
  module). When the caller omits `fallback`, the failure surface is
  empty; the package does not invent a color.
- **Removed the auto letterbox detection and `kWallpaperLetterboxBlurSigma`
  constant**. `ImageBackground.letterboxBlurSigma` is a nullable
  field; the caller opts in and picks the sigma. Setting
  `BoxFit.contain` alone no longer triggers a second paint.
- **Removed `VideoBackground.backgroundColor`** (which defaulted to
  opaque black). Callers who want a specific pre-frame colour set
  `underlay: SolidBackground(...)`.
- **Removed the automatic lifecycle read from
  `VideoBackgroundView`.** `LiveBackground` now carries a caller-fed
  `paused: bool` field. `AppVisibleScope` and `AppVisibilityObserver`
  remain exported as *optional* helpers callers can compose into
  their own `paused` derivation; the render pipeline never consults
  them.
- **Removed `FileImageSource`.** Loading a local file requires
  `dart:io` and a policy about missing paths, both of which are
  caller concerns. Callers wrap their own `FileImage(File(path))`,
  `MemoryImage(bytes)`, `ResizeImage`, `CachedNetworkImageProvider`,
  etc. in the new `ProviderImageSource` variant, which the rendering
  layer hands verbatim to Flutter's `Image` widget.
- Added an assertion rejecting a negative
  `ImageBackground.letterboxBlurSigma`.
- Added a test that verifies the caller-supplied `ImageProvider`
  reaches the `Image` widget unchanged, and a test that verifies
  `LiveBackground(paused: true)` is forwarded to
  `BackgroundVideoSource.buildView`.

## Deliberately NOT adopted from the reference material

The following patterns from the pasted reference were considered and
left in the app composition root because they would violate
`docs/architecture/live-uikit.md` §1.2 or `docs/engineering/package-standards.md`
§7.1 (dependency direction):

- `Obx` / GetX / Riverpod bindings.
- `ThemeData` overrides for wallpaper canvas transparency
  (`WallpaperCanvasTransparency`, `wallpaperChromeTheme`).
- `PageTransitionsTheme` swap for fade-through transitions
  (`wallpaperPageTransitions`, `WallpaperFadeThroughTransitionsBuilder`).
- `media_kit.Video(controls: ..., wakelock: false)` binding — this is
  what a real `BackgroundVideoSource` implementation should do.
- Live-playback poster-frame swap — domain state, not a background
  concern.
- Theme-brightness-driven scrim colour — Material coupling that the
  caller can express directly via `BackgroundOverlay.color`.
