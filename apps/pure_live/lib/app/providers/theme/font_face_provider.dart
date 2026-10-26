import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/app/theme/fonts/font_library.dart' show CloudFontIds, lockedFontFamily;

/// The face a cloud family renders with: its family id when no weight is
/// pinned, or the family's per-face registration when one is. A pinned face
/// only applies to a cloud family that is installed; anything else keeps the
/// stored family.
String? effectiveFontFamily(String? family, String face) {
  if (family == null || face.isEmpty || !CloudFontIds.contains(family)) return family;
  return lockedFontFamily(family, face);
}

/// One weight lock over a persisted key.
abstract base class _FaceController extends Notifier<String> {
  /// The stored face, or empty for automatic.
  String readStored();

  /// Persists [face].
  Future<void> writeStored(String face);

  @override
  String build() {
    try {
      return readStored();
    } on Object {
      return '';
    }
  }

  /// Pins [face] (a downloaded file's basename), or clears it with ''.
  Future<void> set(String face) async {
    final next = face.trim();
    state = next;
    try {
      await writeStored(next);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The app typeface's pinned weight file (empty = automatic).
final class AppFontFaceController extends _FaceController {
  static const String _key = 'theme.fontFace';

  @override
  String readStored() => StoragePrefs.getString(_key) ?? '';

  @override
  Future<void> writeStored(String face) => StoragePrefs.setString(_key, face);
}

/// The flying danmaku's pinned weight file (empty = automatic).
final class DanmakuFontFaceController extends _FaceController {
  static const String _key = 'danmaku.style.fontFace';

  @override
  String readStored() => StoragePrefs.getString(_key) ?? '';

  @override
  Future<void> writeStored(String face) => StoragePrefs.setString(_key, face);
}

/// The app typeface's pinned weight file.
final appFontFaceProvider = NotifierProvider<AppFontFaceController, String>(AppFontFaceController.new);

/// The flying danmaku's pinned weight file.
final danmakuFontFaceProvider = NotifierProvider<DanmakuFontFaceController, String>(DanmakuFontFaceController.new);
