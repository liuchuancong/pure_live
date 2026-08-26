import 'package:media_kit/media_kit.dart';

/// Display dimensions resolved from one decoder-parameter snapshot.
///
/// `dw`/`dh` contain sample-aspect-ratio correction when both are available;
/// `w`/`h` are the safe fallback. Rotation is applied exactly once. Keeping
/// this policy in the video package lets the Android Surface and Pure Live's
/// portrait detector consume identical geometry.
class VideoDisplaySize {
  const VideoDisplaySize({required this.width, required this.height});

  final int width;
  final int height;
}

VideoDisplaySize? resolveVideoParamsDisplaySize(VideoParams params) {
  final correctedWidth = params.dw;
  final correctedHeight = params.dh;
  final rawWidth = params.w;
  final rawHeight = params.h;

  final hasCorrectedPair = correctedWidth != null &&
      correctedWidth > 0 &&
      correctedHeight != null &&
      correctedHeight > 0;
  final hasRawPair =
      rawWidth != null && rawWidth > 0 && rawHeight != null && rawHeight > 0;
  if (!hasCorrectedPair && !hasRawPair) return null;

  late final int decodedWidth;
  late final int decodedHeight;
  if (hasCorrectedPair) {
    decodedWidth = correctedWidth!;
    decodedHeight = correctedHeight!;
  } else {
    decodedWidth = rawWidth!;
    decodedHeight = rawHeight!;
  }
  final rotation = (((params.rotate ?? 0) % 360) + 360) % 360;
  final quarterTurn = rotation == 90 || rotation == 270;
  return quarterTurn
      ? VideoDisplaySize(width: decodedHeight, height: decodedWidth)
      : VideoDisplaySize(width: decodedWidth, height: decodedHeight);
}
