import 'package:media_core_notify/media_core_notify.dart' show MediaCoreNotify;

/// Turns user-facing job notifications on once per process.
///
/// `media_core_notify` installs its job reporter into the core's
/// `MediaJobReporting` slot when enabled, so a recording that ends — saved,
/// partial or failed — reaches the system tray without the recorder knowing
/// about notifications at all. The running line stays with the job engine.
///
/// Best-effort: a platform without a notification pipeline leaves every
/// call a no-op, and a host that never named an app identity (a Windows
/// toast needs one) gets a `false` answer that costs only the toast.
Future<void> enableUserNotifications() async {
  try {
    await MediaCoreNotify.enable();
  } on Object {
    // A notification is how the viewer finds out; it is not the job.
  }
}

/// Asks for the notification permission where the platform has one. Called
/// when the first recording starts, so the prompt arrives with the reason
/// the viewer just gave, not at boot.
Future<void> requestUserNotificationPermission() async {
  try {
    if (!MediaCoreNotify.enabled) await MediaCoreNotify.enable();
    await MediaCoreNotify.requestPermission();
  } on Object {
    // A refused or unavailable permission hides the notification only.
  }
}
