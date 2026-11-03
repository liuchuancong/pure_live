import 'dart:io' show Directory, File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart' show PlayerHandle;

import 'package:pure_live/app/app.dart' show appPathsProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/player/player.dart' show capturePlayerFrame;

/// Saves the room's current frame as an image and answers the file written.
///
/// The capture and the write are the app's one implementation
/// (`capturePlayerFrame`, shared with the media preview's own verb); all that
/// lives here is the room's own name for its frames, so a picture taken off this
/// room reads as that in the viewer's screenshot folder
/// (Settings → 文件 → 截图): `pure_live_room_20261101_031500.png`.
Future<File?> captureRoomFrame(PlayerHandle handle, Directory folder) =>
    capturePlayerFrame(handle, folder, prefix: 'pure_live_room');

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
