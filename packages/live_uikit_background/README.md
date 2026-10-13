# live_uikit_background

Cross-cutting background subsystem for Pure Live.

## Purpose

Give every page (home, rooms list, settings, player) and every
`live_uikit_*` style adapter one shared way to describe and paint a
background — solid, gradient, image or video — without re-implementing
BoxFit, blur compositing, letterbox fill, failure surfaces or video
pause plumbing at each call site.

**Design rule:** this is a plugin package. Every "what should happen
when..." question is answered by a field the caller sets. The package
holds no defaults, no auto-detection, and no framework-side policy.

## Responsibilities

- Own the sealed `BackgroundConfig` union and its variants.
- Own the `LiveBackground` widget that dispatches a config to the
  matching view and layers a `child` on top.
- Interpret the fields the caller sets: overlay scrim, underlay,
  fallback, placeholder color, letterbox fill sigma, media blur,
  pause signal, provider choice.
- Expose the `BackgroundVideoSource` seam the app composition root
  binds to `media_core` or any other player kernel.
- Expose `AppVisibleScope` / `AppVisibilityObserver` as **optional**
  helpers for callers who want a lifecycle-driven value to feed into
  `LiveBackground.paused`. The rendering pipeline does not consult
  them on its own.

## Explicitly NOT responsible for

- Choosing a player kernel. This package never imports `media_kit`,
  `video_player`, `chewie` or anything else that owns a decoder.
- Choosing an image cache. The built-in variants cover URL and asset
  only; for a cached provider the caller wraps their own
  `CachedNetworkImageProvider` (or any `ImageProvider`) in
  `ProviderImageSource`.
- Reading the app's lifecycle. `LiveBackground.paused` is caller-fed;
  the package does not install a `WidgetsBindingObserver` inside the
  render path.
- Deciding a fallback color, letterbox sigma, or auto-detecting which
  `BoxFit` "needs" a fill. Every such knob is a nullable field; when
  unset the corresponding layer is absent.
- Reading `dart:io` for local files. Callers needing local-file
  backgrounds build a `FileImage(File(path))` at the composition root
  and wrap it in `ProviderImageSource`.
- Business state, navigation, or theme resolution. Those live in the
  app / `live_uikit` / `live_preferences`.
- Per-style adapter rendering. Fluent / macOS / Glass / Wind etc.
  compose `LiveBackground` the same way pages do; they do not
  re-implement media handling.
- Theme-brightness-driven scrim colours. `BackgroundOverlay` takes
  an explicit color; if a page wants light-surface vs dark-surface
  washes it selects them itself from `LiveTheme` and hands the right
  color to the config. Keeping this out of the package preserves the
  "core does not know Material" rule.
- Page-transition overrides or `ThemeData` mutations for wallpaper
  transparency. Those live in the app composition root because they
  are navigation and theme concerns, not background painting.

## Workspace usage

Add the package as an internal dependency:

```yaml
dependencies:
  live_uikit_background:
```

The package lives at `packages/live_uikit_background` and is
registered in the root `pubspec.yaml` workspace list.

## Basic usage

```dart
import 'package:flutter/material.dart';
import 'package:live_uikit_background/live_uikit_background.dart';

class HeroScaffold extends StatelessWidget {
  const HeroScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    // Everything on screen here is caller-chosen: the underlay
    // gradient, the letterbox fill sigma, the blur sigma, the scrim
    // color and the failure surface. Nothing here is a package
    // default.
    return LiveBackground(
      config: ImageBackground(
        source: NetworkImageSource('https://example.com/hero.jpg'),
        fit: BoxFit.contain,
        placeholderColor: const Color(0xFF101014),
        underlay: GradientBackground(
          colors: [Color(0xFF12203A), Color(0xFF061220)],
        ),
        letterboxBlurSigma: 24, // omit → no blurred cover layer at all
        blurSigma: 0, // omit or 0 → sharp
        fallback: GradientBackground(
          colors: [Color(0xFF12203A), Color(0xFF061220)],
        ),
        overlay: BackgroundOverlay(color: Colors.black, opacity: 0.35),
      ),
      child: const Center(child: Text('Hello')),
    );
  }
}
```

Passing `null` for `config` renders the same widget shape with an
empty base layer, so a settings toggle that clears or sets the
wallpaper never remounts the page's Navigator subtree.

## Video backgrounds

Wire the app's player kernel through the `BackgroundVideoSource`
contract. The contract is intentionally thin: the source widget owns
its decoder's lifecycle (create on first `buildView`, pause when
`paused=true`, dispose on element teardown) and its BoxFit/alignment
handling because a real decoder knows the frame's intrinsic size.

```dart
class MyMediaCoreSource implements BackgroundVideoSource {
  const MyMediaCoreSource(this.loop);
  final String loop;

  @override
  Widget buildView({
    required bool paused,
    required bool looping,
    required bool muted,
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    return MyMediaCoreVideoView(
      url: loop,
      paused: paused,
      looping: looping,
      muted: muted,
      fit: fit,
      alignment: alignment,
      // Real implementations also disable controls and skip the
      // wakelock — those decisions belong to the media layer, not
      // to this package.
    );
  }
}

LiveBackground(
  // The caller's state manager decides when to pause.
  paused: !appIsResumed,
  config: VideoBackground(
    source: MyMediaCoreSource('asset:loop.mp4'),
    underlay: SolidBackground(color: const Color(0xFF0A0A0F)),
    fallback: SolidBackground(color: Colors.black),
  ),
);
```

If you want a subtree to derive `paused` from the framework's
lifecycle without writing your own observer, wrap it once with
`AppVisibilityObserver` and read the value:

```dart
class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return AppVisibilityObserver(
      child: Builder(
        builder: (context) {
          final visible = AppVisibleScope.isVisibleOf(context);
          return LiveBackground(
            paused: !visible,
            config: ...,
            child: ...,
          );
        },
      ),
    );
  }
}
```

## Public API entry point

`lib/live_uikit_background.dart` is the only supported import
surface. Everything under `lib/src/` is implementation and may change
without a major version bump.

Exported surface:

| Symbol | Kind | Role |
|---|---|---|
| `BackgroundConfig` | sealed class | Union root |
| `SolidBackground` / `GradientBackground` / `ImageBackground` / `VideoBackground` / `BackgroundLayerStack` | variants | Legal background shapes |
| `BackgroundOverlay` | value class | Scrim hanging off every variant |
| `ImageSource`, `NetworkImageSource`, `AssetImageSource`, `ProviderImageSource` | sealed union | Where an image is loaded from; `ProviderImageSource` is the extension point for `FileImage`, `CachedNetworkImageProvider`, `MemoryImage`, ... |
| `BackgroundLayer` | value class | One slice of a stack |
| `BackgroundVideoSource` | contract | Seam the app wires to media_core |
| `LiveBackground` | widget | The single dispatcher every page uses; carries the caller-owned `paused` signal |
| `AppVisibleScope`, `AppVisibilityObserver` | optional helpers | Lifecycle plumbing callers can compose if they want it; the rendering pipeline never reads them on its own |

## Dependencies

- Flutter SDK. The package imports `flutter/widgets.dart`,
  `flutter/painting.dart`, `flutter/foundation.dart` and `dart:ui`
  (for the blur `ImageFilter`); nothing else.
- No Riverpod, no GetX, no Freezed, no cached image package, no
  player kernel.

## Platform support

- Android / iOS / macOS / Windows / Linux / Web: solid, gradient and
  network/asset image backgrounds are fully supported.
- Local-file backgrounds are the caller's job: build a
  `FileImage(File(path))` (which pulls `dart:io` into the caller) and
  wrap it in `ProviderImageSource`. Keeping `dart:io` out of this
  package is what preserves the web target.
- `VideoBackground` requires the app to provide a
  `BackgroundVideoSource`; without one the caller's `fallback` (or
  nothing) is painted.

## Testing

```powershell
cd packages/live_uikit_background
flutter test
```

The `test/src/...` tree mirrors the source layout per
`docs/engineering/dart-model-and-codegen-standards.md` §9.

## Known limitations

- `BackgroundLayerStack` supports linear stacks only; per-layer
  shader effects and blend modes other than `BlendMode.srcOver` are
  approximated through `ColorFiltered`.
- No per-route visibility detection. Callers who need "pause when
  the page is pushed aside" must wire their route observer into the
  `paused` parameter themselves.
- No JSON serialization on the config models; persistence of user
  background choices is intentionally left to `live_preferences`.
