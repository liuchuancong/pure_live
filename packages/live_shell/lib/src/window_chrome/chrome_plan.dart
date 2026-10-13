import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:meta/meta.dart';

/// How far the shell has gone in taking the window's frame over from the OS.
///
/// The first stage is the shipped one, and it is a deliberate restraint: on
/// Windows the buttons stay the system's, so `WS_THICKFRAME` still belongs to
/// the window and everything that rides on it — edge resize, Aero Snap and the
/// snap layout, `Win`+arrow keys, snapping to the top edge, the taskbar never
/// being covered by a maximised window, the DWM shadow, per-monitor DPI — is
/// free. Going frameless is what turns each of those into a bug to maintain.
enum ChromeStage {
  /// Windows keeps its native caption (optionally with the buttons moved),
  /// macOS hides the title bar but keeps the traffic lights inset, and only
  /// Linux draws the whole strip — because on Linux there is no native caption
  /// worth preserving across GTK and KDE themes.
  nativeFirst,

  /// All three platforms draw their own strip. Only sensible together with a
  /// native helper that keeps `WS_THICKFRAME` and answers `WM_NCCALCSIZE` by
  /// eating the non-client area, which is how Chrome and VS Code get a seamless
  /// title bar without giving up the window manager's behaviour. A plain
  /// frameless window here loses resize, snap and the shadow, and each of those
  /// has to be rebuilt in [ChromeHit] terms.
  seamlessSelfDrawn,
}

/// Who draws the caption buttons.
enum ChromeMode {
  /// The system draws and handles them; the app draws nothing.
  nativeCaption,

  /// The system draws the buttons over a title bar the app owns the space of.
  systemOverlayButtons,

  /// The system's traffic lights, moved into the app's own bar.
  insetSystemButtons,

  /// The app draws minimise, maximise and close, and must route their clicks
  /// and the strip's drags itself.
  selfDrawn,
}

/// Where a point on the window's frame belongs.
enum ChromeHit {
  /// Content: let the framework have it.
  client,

  /// The draggable strip.
  drag,

  /// Resize from the top edge.
  resizeTop,

  /// Resize from the bottom edge.
  resizeBottom,

  /// Resize from the left edge.
  resizeLeft,

  /// Resize from the right edge.
  resizeRight,

  /// Resize from the top-left corner.
  resizeTopLeft,

  /// Resize from the top-right corner.
  resizeTopRight,

  /// Resize from the bottom-left corner.
  resizeBottomLeft,

  /// Resize from the bottom-right corner.
  resizeBottomRight,

  /// The minimise button.
  minimise,

  /// The maximise or restore button.
  maximise,

  /// The close button.
  close,
}

/// The geometry of one platform's caption strip, in one place.
///
/// A single source matters: the height of the strip has to agree between the
/// drag region, the app's own content inset, and the offset of any toast or
/// popup anchored under it. Repeating the number in five widgets is how one of
/// them ends up wrong on a scale factor of 125%.
@immutable
final class ChromeMetrics {
  /// Metrics for a strip [titleBarHeight] tall, with [buttonWidth] by
  /// [buttonHeight] buttons and [buttonInset] pixels of clearance on the side
  /// the buttons sit on.
  const new({
    required this.titleBarHeight,
    required this.buttonWidth,
    required this.buttonHeight,
    this.buttonInset = 0,
    this.resizeBorder = 8,
  });

  /// Windows 11's caption: 32 logical pixels tall, ~46 wide per button.
  const new windows() : this(titleBarHeight: 32, buttonWidth: 46, buttonHeight: 32);

  /// macOS's title bar with the traffic lights inset: 38 tall, and the lights
  /// need 78 pixels of horizontal clearance so nothing interactive hides under
  /// them.
  const new macos() : this(titleBarHeight: 38, buttonWidth: 14, buttonHeight: 14, buttonInset: 78);

  /// The self-drawn strip for Linux and for [ChromeStage.seamlessSelfDrawn].
  const new selfDrawn() : this(titleBarHeight: 34, buttonWidth: 44, buttonHeight: 34);

  /// The strip's height.
  final double titleBarHeight;

  /// One button's width.
  final double buttonWidth;

  /// One button's height.
  final double buttonHeight;

  /// Clearance at the edge the buttons sit against: on macOS this is where the
  /// traffic lights are, and a control placed under them cannot be clicked.
  final double buttonInset;

  /// How far inside the window's edge counts as a resize grab.
  final double resizeBorder;

  /// The width of the three-button block.
  double get buttonBlockWidth => buttonWidth * 3;
}

/// What a platform and a stage together decide about the frame.
@immutable
final class ChromePlan {
  /// A plan.
  const new({
    required this.mode,
    required this.metrics,
    required this.ownsResize,
    required this.ownsSnap,
    required this.workAreaClampNeeded,
    this.leftButtonLayout = false,
  });

  /// Chooses the plan for [platform] at [stage].
  ///
  /// The Windows case at [ChromeStage.nativeFirst] is the point of the whole
  /// enum: keep the native caption. Everything the second stage would buy —
  /// pixels of visual seamlessness — costs the window manager's cooperation,
  /// and that is not a cosmetic loss: snap, resize, shadow and DPI are the ones
  /// users report as "the desktop app feels broken".
  factory select({required PlatformKind platform, required ChromeStage stage}) {
    return switch ((platform, stage)) {
      (PlatformKind.macos, ChromeStage.nativeFirst) => const ChromePlan(
        mode: ChromeMode.insetSystemButtons,
        metrics: ChromeMetrics.macos(),
        ownsResize: false,
        ownsSnap: false,
        workAreaClampNeeded: false,
        leftButtonLayout: true,
      ),
      (PlatformKind.macos, ChromeStage.seamlessSelfDrawn) => const ChromePlan(
        mode: ChromeMode.selfDrawn,
        metrics: ChromeMetrics.macos(),
        ownsResize: false,
        ownsSnap: false,
        workAreaClampNeeded: false,
        leftButtonLayout: true,
      ),
      (PlatformKind.windows, ChromeStage.nativeFirst) => const ChromePlan(
        mode: ChromeMode.nativeCaption,
        metrics: ChromeMetrics.windows(),
        ownsResize: false,
        ownsSnap: false,
        workAreaClampNeeded: false,
      ),
      (PlatformKind.windows, ChromeStage.seamlessSelfDrawn) => const ChromePlan(
        // Only correct when a native helper keeps WS_THICKFRAME and answers
        // WM_NCCALCSIZE; the flags below say what is otherwise given up.
        mode: ChromeMode.selfDrawn,
        metrics: ChromeMetrics.selfDrawn(),
        ownsResize: true,
        ownsSnap: true,
        workAreaClampNeeded: true,
      ),
      // KDE and GNOME disagree about server-side decorations, so Linux draws
      // its own strip in both stages.
      _ => const ChromePlan(
        mode: ChromeMode.selfDrawn,
        metrics: ChromeMetrics.selfDrawn(),
        ownsResize: true,
        ownsSnap: true,
        workAreaClampNeeded: true,
      ),
    };
  }

  /// Who draws the buttons.
  final ChromeMode mode;

  /// The strip's geometry.
  final ChromeMetrics metrics;

  /// Whether the shell must implement edge resizing itself.
  final bool ownsResize;

  /// Whether the shell must implement snap-to-edge and `Win`+arrow behaviour.
  final bool ownsSnap;

  /// Whether maximising must be clamped to the display's work area by hand.
  final bool workAreaClampNeeded;

  /// Whether the buttons belong on the left (macOS convention).
  final bool leftButtonLayout;

  /// Whether the app has to draw the caption buttons at all.
  bool get drawsButtons => mode == ChromeMode.selfDrawn;

  /// Whether a drag in the strip must be forwarded to the OS by the app rather
  /// than handled by the caption.
  bool get needsDragHandling => mode == ChromeMode.selfDrawn || mode == ChromeMode.insetSystemButtons;
}

/// Classifies a point in window-local coordinates against the caption strip.
///
/// Only needed when [ChromePlan.drawsButtons] or [ChromePlan.ownsResize] — with
/// a native caption the OS has already done this and knows more about it than
/// this function can.
///
/// The button block is claimed **before** the resize band. A pointer near the
/// top-right corner is ambiguous — it is inside both the 8-pixel grab and the
/// close button — and the cost of guessing wrong is not symmetric: treating it
/// as a resize means the close button silently stops working in its outer
/// pixels, which the viewer reads as a broken app, while treating it as a button
/// costs a grip a few pixels wide that the edges still provide.
ChromeHit hitTestChrome({
  required double x,
  required double y,
  required ChromeMetrics metrics,
  required double width,
  required double height,
  bool maximized = false,
  bool rightSideButtons = true,
}) {
  final inStrip = y <= metrics.titleBarHeight;
  if (inStrip && rightSideButtons) {
    // macOS's traffic lights are the OS's own; nothing to hit-test there.
    final blockStart = width - metrics.buttonInset - metrics.buttonBlockWidth;
    final blockEnd = width - metrics.buttonInset;
    if (x >= blockStart && x < blockEnd) {
      final index = ((x - blockStart) / metrics.buttonWidth).floor();
      return switch (index) {
        0 => ChromeHit.minimise,
        1 => ChromeHit.maximise,
        _ => ChromeHit.close,
      };
    }
  }
  final border = metrics.resizeBorder;
  // A maximised window has no resize edge: its frame fills a work area, so a
  // pointer on the boundary is over content, not a grab-band.
  if (!maximized) {
    final left = x < border;
    final right = x > width - border;
    final top = y < border;
    final bottom = y > height - border;
    if (top && left) {
      return ChromeHit.resizeTopLeft;
    }
    if (top && right) {
      return ChromeHit.resizeTopRight;
    }
    if (bottom && left) {
      return ChromeHit.resizeBottomLeft;
    }
    if (bottom && right) {
      return ChromeHit.resizeBottomRight;
    }
    if (left) {
      return ChromeHit.resizeLeft;
    }
    if (right) {
      return ChromeHit.resizeRight;
    }
    if (bottom) {
      return ChromeHit.resizeBottom;
    }
  }
  if (!inStrip) {
    return ChromeHit.client;
  }
  return ChromeHit.drag;
}
