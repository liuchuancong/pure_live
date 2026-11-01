import 'dart:io' show Directory, File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/app/app.dart' show appPathsProvider;
import 'package:pure_live/l10n/translations.dart';

/// Saves the room's current frame as an image and answers the file written.
///
/// The frame comes from media_core's own capture chain: the engine's capture
/// first (the decoded frame at its real resolution) and the rendered surface as
/// the fallback, which is why the handle's own `canCaptureScreenshot` is the gate —
/// when it is false there is no route at all and the caller hides the action
/// rather than offering one that cannot work.
///
/// The file lands in the viewer's screenshot folder (Settings → 文件 → 截图),
/// named for the room and the moment so two frames of one room do not collide.
Future<File?> captureRoomFrame(PlayerHandle handle, Directory folder) async {
  if (!handle.canCaptureScreenshot) return null;
  final shot = await handle.captureScreenshot(options: const ScreenshotOptions(timeout: Duration(seconds: 4)));
  if (shot == null || shot.isEmpty) return null;
  try {
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, _fileName(DateTime.now(), shot.format)));
    await file.writeAsBytes(shot.bytes, flush: true);
    return file;
  } on Object {
    // A folder that refuses the write answers "no file" like any other failed
    // capture; the toast then says the capture did not land.
    return null;
  }
}

/// `pure_live_room_20261101_031500.png`.
String _fileName(DateTime now, ScreenshotFormat format) {
  String two(int value) => value.toString().padLeft(2, '0');
  final stamp = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  return 'pure_live_room_$stamp.${format.fileExtension}';
}

/// Captures [handle]'s frame and says how it went.
///
/// One action for both entries (the picture's bar button and the page's `S`
/// key): the file name when it landed, the reason when it did not — a capture
/// that fails silently reads as a broken button.
Future<void> takeRoomScreenshot(BuildContext context, WidgetRef ref, PlayerHandle handle) async {
  final file = await captureRoomFrame(handle, ref.read(appPathsProvider).screenshots);
  if (!context.mounted) return;
  final t = context.t;
  showDsToast(
    context: context,
    title: file == null ? t.room.screenshotFailed : t.room.screenshotSaved(name: file.uri.pathSegments.last),
    status: file == null ? DsStatus.danger : DsStatus.success,
  );
}
