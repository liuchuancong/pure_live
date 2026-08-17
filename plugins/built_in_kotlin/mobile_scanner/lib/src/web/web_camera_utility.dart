import 'dart:js_interop';

import 'package:mobile_scanner/src/web/media_track_extension.dart';
import 'package:web/web.dart' as web;

export 'package:mobile_scanner/src/web/web_barcode_utils.dart'
    show isInsideScanWindow, mirrorBarcodeX;

/// Returns true if the video stream should be mirrored horizontally.
///
/// Mirrors when facingMode is 'user' (front camera on mobile), or when
/// facingMode is null (desktop cameras mainly face the user).
bool shouldMirrorStream(web.MediaStream? videoStream) {
  final tracks = videoStream?.getVideoTracks().toDart;

  if (tracks == null || tracks.isEmpty) {
    return false;
  }

  final facingMode = tracks.first.getSettings().facingModeNullable?.toDart;

  return facingMode == 'user' || facingMode == null;
}

/// Apply a horizontal CSS mirror transform to [videoElement] if the camera
/// is facing the user.
void maybeFlipVideoPreview(
  web.HTMLVideoElement videoElement,
  web.MediaStream videoStream,
) {
  if (shouldMirrorStream(videoStream)) {
    videoElement.style.transform = 'scaleX(-1)';
  }
}
