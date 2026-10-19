import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:media_core_mediasession/media_core_mediasession.dart' show MediaSessionBootstrap;
import 'package:media_core_notify/media_core_notify.dart'
    show DesktopNotifySettings, MediaCoreNotify, NotifySetup;

/// Turns on the two playback surfaces media_core owns outside the window: the
/// system media controls (now-playing notification, lock screen, Windows
/// SMTC, Linux MPRIS) and the user-facing job notifications (a recording or a
/// download announces how it ended, and one line says what is running).
///
/// Neither is a per-page concern. [MediaSessionBootstrap.install] puts the
/// driver on `PlayerKernel.audioDriverFactory`, so every room opened after
/// this call drives the media surface with no further wiring, and
/// [MediaCoreNotify.enable] installs the core's job reporter, so the recording
/// and download back-ends report their outcomes on their own. One call at
/// start-up, before the first window opens, is the whole integration.
///
/// Both are best-effort: the surfaces are a convenience, never a reason the
/// app fails to boot. A platform that refuses (no `audio_service` manifest
/// entry, a web build, a Windows host whose toast identity is not registered)
/// is logged and skipped; playback itself is untouched. Call it unawaited.
Future<void> enablePlaybackSurfaces({
  String appTitle = 'PureLive',
  void Function()? onError,
}) async {
  if (kIsWeb) {
    return;
  }
  try {
    await MediaCoreNotify.enable(
      setup: NotifySetup(
        // Windows attributes a toast to an app by its user-model id and routes
        // a click back by the activation guid; both must match how the app is
        // packaged (the unpackaged installer registers this id with its start
        // menu shortcut). The id mirrors the desktop instance channel's own id
        // (platforms/desktop/entry/desktop_launch.dart) so the running app and
        // its notifications carry one name.
        desktop: defaultTargetPlatform == TargetPlatform.windows
            ? const DesktopNotifySettings(
                appName: 'PureLive',
                windowsAppUserModelId: 'live.pure.desktop',
                windowsGuid: '{4f2b7a51-9d3e-5c6a-8b12-0a7f3c1d6e94}',
              )
            : null,
      ),
    );
  } on Object {
    onError?.call();
  }
  try {
    await MediaSessionBootstrap.enable();
  } on Object {
    onError?.call();
  }
}

/// Releases both surfaces — used on a controlled shutdown so a stale
/// now-playing entry does not outlive the process.
Future<void> disablePlaybackSurfaces() async {
  await MediaSessionBootstrap.disable();
  await MediaCoreNotify.disable();
}
