/// Icon sizes and minimum interactive sizes.
///
/// The minimums follow the bigger of the two platform conventions — 44
/// logical pixels of touch target (iOS) and 48 pixels of remote target
/// (Android TV) — because a control that is too small is a defect on both,
/// while a control that is slightly large is not.
abstract final class LiveSizing {
  /// 16 — icons inside dense chrome (badges, chips).
  static const double iconXs = 16;

  /// 20 — icons inside buttons and list tiles.
  static const double iconSm = 20;

  /// 24 — the default icon size.
  static const double iconMd = 24;

  /// 32 — navigation icons and toolbar actions.
  static const double iconLg = 32;

  /// 48 — TV navigation icons and empty-state art.
  static const double iconXl = 48;

  /// The smallest touch target; below this a tap is a guess.
  static const double minTouchTarget = 44;

  /// The smallest remote-control target; focus plus confirmation.
  static const double minRemoteTarget = 48;

  /// The default control height on touch platforms.
  static const double controlHeight = 44;

  /// The default control height on desktop, where pointer precision allows
  /// a tighter layout.
  static const double controlHeightCompact = 36;

  /// The default control height in TV layouts.
  static const double controlHeightTv = 56;

  /// The width of a navigation rail.
  static const double railWidth = 88;

  /// The height of a bottom navigation bar.
  static const double navBarHeight = 64;

  /// The maximum width of a reading column (settings pages, dialogs).
  static const double contentMaxWidth = 960;

  /// The default avatar size.
  static const double avatar = 40;

  /// The default card cover aspect ratio (16:9 covers).
  static const double coverAspectRatio = 16 / 9;
}
