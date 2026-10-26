import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/painting.dart' show Offset, Rect, Size;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core_pip/media_core_pip.dart' show PipSavedBounds;

/// Stored compact-window geometry, one record per stream orientation.
///
/// The reference remembers a landscape and a portrait placement separately:
/// a size that fits a phone held upright is wrong for the same phone turned
/// sideways. A record also carries the monitor id so a placement remembered
/// on a disconnected display is not replayed onto another one.
const String kPipLandscapeKey = 'window.pip.landscape';
const String kPipPortraitKey = 'window.pip.portrait';

String _keyFor(bool portrait) => portrait ? kPipPortraitKey : kPipLandscapeKey;

/// Reads the saved geometry for [portrait], or null when none is usable.
PipSavedBounds? readPipSavedBounds({required bool portrait}) {
  try {
    final raw = StoragePrefs.getString(_keyFor(portrait));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final displayId = decoded['display']?.toString().trim() ?? '';
    final x = (decoded['x'] as num?)?.toDouble();
    final y = (decoded['y'] as num?)?.toDouble();
    final width = (decoded['width'] as num?)?.toDouble();
    final height = (decoded['height'] as num?)?.toDouble();
    if (displayId.isEmpty ||
        x == null ||
        y == null ||
        width == null ||
        height == null ||
        !x.isFinite ||
        !y.isFinite ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return PipSavedBounds(displayId: displayId, bounds: Rect.fromLTWH(x, y, width, height));
  } on Object {
    return null;
  }
}

/// Forgets both stored placements; the next compact window falls back to the
/// app window's own corner instead of a remembered spot.
Future<void> clearPipSavedBounds() async {
  await StoragePrefs.remove(kPipLandscapeKey);
  await StoragePrefs.remove(kPipPortraitKey);
}

/// Stores [size]/[position] for [portrait]; called by the PiP placement
/// policy after it lands the window.
void writePipSavedBounds({
  required bool portrait,
  required Size size,
  required Offset position,
  required String displayId,
}) {
  if (!size.isFinite ||
      size.isEmpty ||
      !position.isFinite ||
      displayId.trim().isEmpty ||
      size.width <= 0 ||
      size.height <= 0) {
    return;
  }
  final payload = jsonEncode(<String, Object>{
    'display': displayId.trim(),
    'x': position.dx,
    'y': position.dy,
    'width': size.width,
    'height': size.height,
  });
  unawaited(StoragePrefs.setString(_keyFor(portrait), payload).catchError((Object _) => false));
}
