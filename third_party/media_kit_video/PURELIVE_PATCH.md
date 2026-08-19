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
a Surface refresh seek after the video track had already vanished.

This patch adds `VideoController.setVideoOutputEnabled` and makes the Android
controller the single owner of both the requested video-output state and the
Surface lifecycle. Track properties are issued from the controller's lock via
media_kit's asynchronous mpv request. The synchronous string-property FFI call
is deliberately avoided for headphone switching because a busy live demuxer
can block Flutter's isolate before the audio presentation or timeout paints.
Video mode always selects `vid=auto`, including while WID is temporarily zero;
only an explicit audio-only request selects `vid=no`. This avoids a startup
deadlock where disabling video before a Surface callback also prevented the
callback that would restore it. The best-effort Surface refresh seek and the
Android Surface-size MethodChannel request run outside the lock. Desktop
platforms retain media_kit's existing
`setVideoTrack` behavior.

## Maintenance

When updating the pinned media-kit revision:

1. Replace this directory with the new upstream package.
2. Reapply the small controller API and Android state-owner patch.
3. Compare every file against the new upstream commit; only the files described
   above, `pubspec.yaml`, this note and the policy helper should differ.
4. Run `flutter analyze`, the full test suite, Windows release build and Android
   ARM64 release build.
5. On Android, repeat video/audio toggles plus rotation, PiP and room re-entry.
