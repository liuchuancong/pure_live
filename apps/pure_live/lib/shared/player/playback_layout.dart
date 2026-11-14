/// The playback pages' layout machine: the window class and the
/// sideways-immersive flag, resolved once from the window's shape and read
/// by every branch instead of each page deriving its own measures.
///
/// Every video playback page (the live room, the recorder's playback, the
/// VOD and the rest) answers the same three measures: wide from 840, regular
/// from 600, compact under — and a window held sideways in a short height is
/// the landscape arrangement before any width is asked, the compact height
/// winning over the wide breakpoint. The judgement is the window's own
/// shape, never the platform: a small desktop window is a phone as far as
/// the layout is concerned.
library;

/// The width the wide arrangements start at; the chat column's toggle and
/// the `T` key answer to the same measure.
const double kPlaybackWideBreakpoint = 840;

/// The width where a narrow window's own arrangements start; under it the
/// page is compact.
const double kPlaybackCompactBreakpoint = 600;

/// Windows shorter than this are a window held sideways, whatever their
/// width (the reference's compact height, which wins over the wide
/// breakpoint).
const double kPlaybackLandscapeMaxHeight = 480;

/// The window classes the playback arrangements answer to, wide to compact.
enum PlaybackWindowClass { wide, regular, compact }

/// One resolution of the playback layout axes.
final class PlaybackLayout {
  const PlaybackLayout._({required this.windowClass, required this.landscapeImmersive});

  /// Resolves the axes from the window's shape. [sizeLike] marks a surface
  /// that takes the sideways arrangement — any window passes true: the flag
  /// only gates the compact height's win, and that win is the window's own
  /// shape.
  factory PlaybackLayout.resolve({required double width, required double height, bool sizeLike = true}) {
    final landscapeImmersive =
        sizeLike && height < kPlaybackLandscapeMaxHeight && width > height && width >= kPlaybackCompactBreakpoint;
    final windowClass = switch (width) {
      >= kPlaybackWideBreakpoint => PlaybackWindowClass.wide,
      >= kPlaybackCompactBreakpoint => PlaybackWindowClass.regular,
      _ => PlaybackWindowClass.compact,
    };
    return PlaybackLayout._(windowClass: windowClass, landscapeImmersive: landscapeImmersive);
  }

  /// The width's class: wide from 840, regular from 600, compact under.
  final PlaybackWindowClass windowClass;

  /// A window held sideways in a short height: its own arrangement, decided
  /// before the width's class is asked.
  final bool landscapeImmersive;
}
