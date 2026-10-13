import 'package:media_core/media_core.dart';

/// How a page arranges a — possibly vertical — video surface.
///
/// The device profile decides the strategy, and the strategy decides what the
/// UI does, so the host never branches on "is this a phone" itself:
///
/// - a phone forces vertical *media* into an immersive column and letterboxes
///   horizontal media into the same column;
/// - a tablet or desktop lays the video out responsively next to other
///   content, because its window is not defined by a physical rotation.
enum LayoutStrategy {
  /// Phone, portrait video: fill the viewport, chrome overlays the picture.
  immersivePortrait,

  /// Phone, landscape video: fit the picture into the portrait viewport
  /// with letterbox bars (or let the user rotate).
  letterboxLandscape,

  /// Tablet/desktop: the video shares the window with surrounding content.
  responsive,

  /// The window is an overlay (PiP or in-app floating): the surface follows
  /// the video's own shape, no letterboxing, chrome collapsed.
  overlay;

  /// The strategy for [orientation] on [profile].
  ///
  /// [isOverlay] wins over the profile: an overlay window is a thumbnail of
  /// the video, so it follows the video's shape on every device.
  static LayoutStrategy forProfile(DeviceProfile profile, VideoOrientation orientation, {bool isOverlay = false}) {
    if (isOverlay) {
      return LayoutStrategy.overlay;
    }

    if (profile == DeviceProfile.mobile) {
      return orientation == VideoOrientation.landscape
          ? LayoutStrategy.letterboxLandscape
          : LayoutStrategy.immersivePortrait;
    }

    return LayoutStrategy.responsive;
  }
}
