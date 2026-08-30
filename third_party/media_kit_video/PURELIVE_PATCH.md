# PureLive media_kit_video patch

- Upstream: `https://github.com/Predidit/media-kit.git`
- Base commit: `994465d9bfca3f39d0b41199d16e7fd93fe97881`
- Package version: `media_kit_video 1.2.5`
- License: MIT; the upstream `LICENSE` is retained in this directory.

## Why this copy exists

On Android, `AndroidVideoController` owns the `vo`, `wid` and Surface lifecycle.
PureLive's room-scoped audio mode also needs to select `vid=no` without replacing
the player or reopening the live stream. Sending that property independently
could race a rotation, PiP or Surface resize update and leave the UI waiting for
a video track or Surface that had already vanished.

This patch adds `VideoController.setVideoOutputEnabled` and makes the Android
controller the single owner of both the requested video-output state and the
Surface lifecycle. Track properties are issued from the controller's lock via
media_kit's asynchronous mpv request. The synchronous string-property FFI call
is deliberately avoided for headphone switching because a busy live demuxer
can block Flutter's isolate before the audio presentation or timeout paints.
Video mode always selects `vid=auto`, including while WID is temporarily zero;
only an explicit audio-only request selects `vid=no`. This avoids a startup
deadlock where disabling video before a Surface callback also prevented the
callback that would restore it. Surface replacement follows Flutter's
`SurfaceProducer` contract: every availability/resize queries `getSurface()`, a
changed Java Surface receives a new JNI global reference, and the old WID is
detached exactly once before delayed reference deletion. Geometry-only updates
do not reset `vo`, and Surface changes do not seek a live stream merely to
refresh rendering. The Android Surface-size MethodChannel request remains
outside the controller lock. Desktop platforms retain media_kit's existing
`setVideoTrack` behavior.

On Windows, PureLive also exposes a throttled `frameRevision` liveness signal.
The native D3D11 mailbox emits it only after a fence-confirmed frame has been
promoted for Flutter consumption; software rendering emits it after a completed
render. This lets `PlayerManager` distinguish “libmpv still says playing” from
“the presentation surface has stopped advancing”, recreate the renderer once,
then fall through to the existing CDN-line recovery. The signal carries no
pixels, is limited to two events per second, and does not alter normal frame
delivery or aspect-ratio policy.

`VideoController.setSize` also accepts an opt-in `force` flag on every platform
(only the Windows native implementation changes behavior). PureLive uses it on
the first layout after a Windows `Texture` remount so the current native output
receives a viewport even when its controller cache still contains equal width
and height. Normal resize calls keep the upstream equality fast path. Together
with the frame-progress fence, this prevents a 0×0 replacement output from
being treated as presentation-ready after an overlay route or transport retry.

## Maintenance

When updating the pinned media-kit revision:

1. Replace this directory with the new upstream package.
2. Reapply the controller API, Android state-owner patch, and Windows
   fence-confirmed frame-progress callback.
3. Compare every file against the new upstream commit; only the files described
   above, `pubspec.yaml`, this note and the policy helper should differ.
4. Run `flutter analyze`, the full test suite, Windows release build and Android
   ARM64 release build.
5. On Android, repeat video/audio toggles plus rotation, PiP and room re-entry.
6. On Windows, verify a deliberately stalled renderer is recreated once, a
   stalled CDN advances to the next line, a 0×0 candidate never replaces the
   active texture, remounting reasserts viewport size, and explicit pause never
   triggers the watchdog.
