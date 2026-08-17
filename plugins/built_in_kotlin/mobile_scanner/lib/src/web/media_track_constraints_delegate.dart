import 'dart:js_interop';

import 'package:mobile_scanner/src/enums/camera_facing.dart';
import 'package:mobile_scanner/src/web/media_track_extension.dart';
import 'package:web/web.dart';

/// This class represents a delegate that manages the constraints for a
/// [MediaStreamTrack].
final class MediaTrackConstraintsDelegate {
  /// Constructs a [MediaTrackConstraintsDelegate] instance.
  const MediaTrackConstraintsDelegate();

  /// Get the camera direction from the given [videoStream].
  CameraFacing getCameraDirection(MediaStream? videoStream) {
    final trackSettings = getSettings(videoStream);

    return switch (trackSettings?.facingModeNullable) {
      'environment' => CameraFacing.back,
      'user' => CameraFacing.front,
      _ => CameraFacing.unknown,
    };
  }

  /// Convert the given [cameraDirection] into a facing mode string,
  /// that is suitable as a MediaTrack constraint.
  String getFacingMode(CameraFacing cameraDirection) {
    return switch (cameraDirection) {
      CameraFacing.back ||
      CameraFacing.external ||
      CameraFacing.unknown => 'environment',
      CameraFacing.front => 'user',
    };
  }

  /// Get the settings for the given [mediaStream].
  MediaTrackSettings? getSettings(MediaStream? mediaStream) {
    final tracks = mediaStream?.getVideoTracks().toDart;

    if (tracks == null || tracks.isEmpty) {
      return null;
    }

    final track = tracks.first;

    final settings = track.getSettings();

    if (settings.facingModeNullable == null) {
      return MediaTrackSettings(width: settings.width, height: settings.height);
    }

    return MediaTrackSettings(
      width: settings.width,
      height: settings.height,
      facingMode: settings.facingMode,
    );
  }
}
