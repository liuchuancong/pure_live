import 'dart:io' show Directory, File;

import 'package:media_core/media_core.dart'
    show PlayerHandle, PlayerHandleLifecycle, PlayerScreenshot, ScreenshotOptions, ScreenshotWriter;

/// Saves the frame a player is showing into [folder] and answers the file it
/// wrote, or null when nothing landed.
///
/// The frame comes from media_core's own capture chain — the engine's decoded
/// frame first, the rendered surface as the fallback — which is why the
/// handle's `canCaptureScreenshot` is the gate: with it false there is no route
/// at all, and a caller should hide the verb rather than offer one that cannot
/// work. The write is the package's own [ScreenshotWriter], so a saved frame is
/// created, named and logged the way every other capture in the app is.
///
/// [prefix] says which surface the frame came from, so two players writing into
/// one folder produce names a viewer can tell apart.
Future<File?> capturePlayerFrame(PlayerHandle handle, Directory folder, {required String prefix}) async {
  if (!handle.canCaptureScreenshot) return null;
  try {
    final PlayerScreenshot? shot;
    shot = await handle.captureScreenshot(options: const ScreenshotOptions(timeout: Duration(seconds: 4)));
    if (shot == null || shot.isEmpty) return null;
    final writer = ScreenshotWriter(
      directory: folder.path,
      fileNameBuilder: (capture) =>
          '${prefix}_${_stamp(capture.capturedAt ?? DateTime.now())}.${capture.format.fileExtension}',
    );
    return File(await writer.save(shot));
  } on Object {
    // A capture that throws or a folder that refuses the write both answer "no
    // file"; the caller's toast then says the capture did not land.
    return null;
  }
}

/// `20261103_031500` — the moment to the second, so a burst of presses does not
/// overwrite the frame before it.
String _stamp(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}${two(value.month)}${two(value.day)}_${two(value.hour)}${two(value.minute)}${two(value.second)}';
}
