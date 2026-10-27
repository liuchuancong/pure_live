import 'dart:io' show Directory, File, Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart' show PlayerHandleLifecycle;
import 'package:media_core_notify/media_core_notify.dart' show MediaCoreNotify, NotifyEvent;
import 'package:pure_live/features/room/room.dart' show roomProvider;
import 'package:pure_live/l10n/translations.dart' show t;

/// The tray's 截图: the primary window's current room frame, saved under the
/// user's Pictures folder. Feedback lands in the system notification area —
/// the tray is most useful while the window is hidden, where a toast would
/// have no one to talk to.
Future<void> captureRoomScreenshot(WidgetRef ref) async {
  final room = ref.read(roomProvider);
  final handle = room.handle;
  final detail = room.room;
  if (handle == null || detail == null) {
    await _notify(t.settings.trayScreenshotFailed);
    return;
  }
  try {
    final shot = await handle.captureScreenshot();
    final bytes = shot?.bytes;
    if (bytes == null || bytes.isEmpty) {
      await _notify(t.settings.trayScreenshotFailed);
      return;
    }
    final path = await _write(bytes, platform: detail.ref.platform, roomId: detail.ref.roomId);
    await _notify(t.settings.trayScreenshotSaved(path: path));
  } on Object {
    await _notify(t.settings.trayScreenshotFailed);
  }
}

Future<String> _write(List<int> bytes, {required String platform, required String roomId}) async {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  final root = home == null ? Directory.systemTemp.path : '$home${Platform.pathSeparator}Pictures';
  final directory = Directory('$root${Platform.pathSeparator}PureLive');
  await directory.create(recursive: true);
  final stamp = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  final name =
      'PureLive-$platform-$roomId-${stamp.year}${two(stamp.month)}${two(stamp.day)}-${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}.png';
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> _notify(String body) async {
  if (!MediaCoreNotify.enabled) return;
  await MediaCoreNotify.post(NotifyEvent(title: t.settings.trayScreenshot, body: body));
}
