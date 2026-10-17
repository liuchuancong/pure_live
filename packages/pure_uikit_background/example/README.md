# live_uikit_background example

A single-page gallery that exercises every caller-owned knob of the
package:

- All five `BackgroundConfig` variants — `Solid`, `Gradient`, `Image`,
  `Video`, `BackgroundLayerStack` — plus the `ProviderImageSource`
  extension point.
- Switches for `hasBackground` (proves `LiveBackground(config: null)`
  keeps the widget shape stable), `paused`, `underlay`, `fallback`,
  `letterboxBlurSigma` and `overlay` — the exact set of fields the
  package refuses to fill in on your behalf.
- Sliders for `overlay.opacity`, `blurSigma` and `letterboxSigma`.
- A fake "video source" backed by an `AnimationController` that shows
  how `LiveBackground.paused` is forwarded to
  `BackgroundVideoSource.buildView`.

## Running

The example is registered in the workspace root, so from the repo root:

```powershell
flutter pub get
cd packages/live_uikit_background/example
flutter run -d <device>       # any platform: windows, linux, chrome, ...
```

Or, if you want to keep the workspace untouched, run it as a normal
Flutter app:

```powershell
cd packages/live_uikit_background/example
flutter create .              # generates platform folders on demand
flutter run
```

## What to look for

- Flip **wallpaper off** → the hero panel keeps its structure; the
  child card stays mounted.
- Flip **underlay off** on the Image variant → the palette gradient
  disappears and you see through the loading state.
- Flip **fallback off** → when the network image fails (the URL is
  intentionally invalid), the layer collapses to transparent instead
  of painting a caller-supplied surface.
- Flip **letterbox fill** on the Image variant → when on, a blurred
  cover copy of the same (failing) image sits under the primary
  image; the sigma slider changes the blur of that fill.
- Toggle **paused** on the Video variant → the animated hue gradient
  freezes; that value is fed by the caller, not by `AppLifecycleState`.
