import 'package:media_core/media_core.dart';

/// Which kind of window a remembered geometry belongs to.
///
/// The two surfaces remember separately because they are two different
/// experiences: a system PiP window lives outside the app and follows the
/// platform's own sizing rules, while the in-app small window is a widget the
/// viewer drags and resizes at will. Sharing one remembered rect between them
/// would make one surprise the other.
enum WindowSurface {
  /// System picture-in-picture (a separate OS window on desktop, the system
  /// PiP activity on Android).
  pip,

  /// The in-app floating window drawn above the current page.
  floating;

  /// The storage slot name for this surface.
  String get storageKey => name;
}

/// The identity a remembered window geometry is stored under.
///
/// A viewer's "vertical small window is a tall strip in the top right" and
/// "horizontal small window is wide, bottom left" are two facts, not one:
/// portrait and landscape videos want different shapes, and both should come
/// back the way they were left. Hence orientation is part of the key.
final class WindowGeometryKey {
  /// Creates a geometry key.
  const new({required this.sessionId, required this.surface, required this.orientation});

  /// The business id of the session (room id, video id).
  final String sessionId;

  /// PiP or floating.
  final WindowSurface surface;

  /// The video's orientation at the time the geometry was captured.
  final VideoOrientation orientation;

  /// Whether the video is taller than it is wide.
  ///
  /// Unknown and square orientations count as landscape: a square video is
  /// laid out like a wide one, and a window must pick a side.
  bool get isPortrait => orientation == VideoOrientation.portrait;

  /// The storage slot under the session id.
  String get slot => '${surface.storageKey}_${isPortrait ? 'portrait' : 'landscape'}';
}

/// How big a window opens when nothing has been remembered yet.
///
/// The defaults are deliberately conservative — a window that opens too big
/// covers the content it is meant to sit beside.
final class WindowSizePolicy {
  /// Creates a size policy.
  const new({
    required this.scale,
    this.minLongSide = 160,
    this.maxShortSideFraction = 0.9,
    this.minPortraitWidth = 120,
  });

  /// The share of the screen's short side the window's long side takes.
  final double scale;

  /// The smallest the window's long side may become.
  final double minLongSide;

  /// The largest the window's short side may become, as a fraction of the
  /// screen's short side.
  final double maxShortSideFraction;

  /// The narrowest a portrait video's window gets.
  final double minPortraitWidth;

  /// The default for the main stream in a small window.
  static const WindowSizePolicy primary = WindowSizePolicy(scale: 0.56);

  /// The default for a member of a multi-view grid, which is smaller.
  static const WindowSizePolicy member = WindowSizePolicy(scale: 0.38);

  /// The default for a window that reappears after the app was backgrounded.
  static const WindowSizePolicy backgroundReturn = WindowSizePolicy(scale: 0.46);
}
