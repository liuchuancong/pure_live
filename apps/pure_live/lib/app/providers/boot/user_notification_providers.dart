import 'package:media_core_notify/media_core_notify.dart'
    show
        DesktopNotifySettings,
        MediaCoreNotify,
        NotifyChannel,
        NotifyEvent,
        NotifySetup,
        NotifyTap,
        kNotifyChannelDownload,
        kNotifyChannelJobs,
        kNotifyChannelRecording,
        kNotifyChannelResults;

/// The channel a followed room's go-live notification lands on.
const NotifyChannel kLiveAlertChannel = NotifyChannel(
  id: 'pure_live_live_alerts',
  name: '开播提醒 / Live alerts',
  description: '关注的主播开播时通知 / When a followed room goes live',
);

/// The process identity the Windows runner sets at startup; the toast and
/// the app must agree on it or the system attributes the toast to nobody.
const String kWindowsAppUserModelId = 'com.liuchuancong.pure_live';

/// The stable activation guid a toast click is routed by. It must never
/// change between runs, so it is a constant rather than derived.
const String kWindowsNotifyGuid = '8f3a2d54-9c1b-4e7a-b6d2-2f9c41a07e88';

/// The setup every enable path uses, so the live-alert channel exists and a
/// tap can open the room it names. The desktop identity is what makes the
/// Windows/Linux pipeline initialise at all — without it every notification
/// is silently dropped there.
const NotifySetup _notifySetup = NotifySetup(
  channels: [
    kNotifyChannelRecording,
    kNotifyChannelDownload,
    kNotifyChannelJobs,
    kNotifyChannelResults,
    kLiveAlertChannel,
  ],
  onTap: _onNotifyTap,
  desktop: DesktopNotifySettings(
    appName: 'Pure Live',
    linuxActionName: 'Open Pure Live',
    windowsAppUserModelId: kWindowsAppUserModelId,
    windowsGuid: kWindowsNotifyGuid,
  ),
);

/// The payload prefix a live alert carries.
const String kLiveAlertPayloadPrefix = 'live:';

/// Handles one tapped live alert: [identityKey] is `platform:roomId`.
typedef LiveAlertTapHandler = void Function(String identityKey);

/// Set by the primary window's alert watcher while it is mounted; a tap
/// before it is set (a cold start) opens the app without a room.
LiveAlertTapHandler? liveAlertTapHandler;

/// The one id a room's alert reuses, so a second broadcast replaces the
/// first instead of stacking.
int liveAlertNotificationId(String identityKey) => 0x50000000 + (identityKey.hashCode & 0x0fffffff);

void _onNotifyTap(NotifyTap tap) {
  final payload = tap.payload;
  if (payload == null || !payload.startsWith(kLiveAlertPayloadPrefix)) return;
  liveAlertTapHandler?.call(payload.substring(kLiveAlertPayloadPrefix.length));
}

/// Turns user-facing notifications on once per process.
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
    await MediaCoreNotify.enable(setup: _notifySetup);
  } on Object {
    // A notification is how the viewer finds out; it is not the job.
  }
}

/// Asks for the notification permission where the platform has one. Called
/// when the first recording starts or live alerts are turned on, so the
/// prompt arrives with the reason the viewer just gave, not at boot.
Future<void> requestUserNotificationPermission() async {
  try {
    if (!MediaCoreNotify.enabled) await MediaCoreNotify.enable(setup: _notifySetup);
    await MediaCoreNotify.requestPermission();
  } on Object {
    // A refused or unavailable permission hides the notification only.
  }
}

/// Posts one followed room's go-live notification. Returns whether the
/// platform took it; a room's alert replaces its previous one.
Future<bool> postLiveAlert({required String identityKey, required String title, required String body}) {
  if (!MediaCoreNotify.enabled) return Future<bool>.value(false);
  return MediaCoreNotify.post(
    NotifyEvent(
      title: title,
      body: body,
      channel: kLiveAlertChannel,
      payload: '$kLiveAlertPayloadPrefix$identityKey',
      id: liveAlertNotificationId(identityKey),
    ),
  );
}
