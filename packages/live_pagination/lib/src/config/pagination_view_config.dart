import 'package:meta/meta.dart';

/// Pure-Dart UI configuration and scroll-edge math for paged views.
///
/// This package renders nothing; the app's widgets read this config and
/// feed scroll numbers into the predicates. The defaults mirror the
/// behaviour of the legacy PureLive list views: jump buttons appear past
/// 400 px, jump animations run 220–520 ms scaled by distance, mobile
/// pages hold 20 items, and the desktop layout starts above 680 px.
@immutable
final class PaginationViewConfig {
  /// A configuration with every value explicit; see [defaults] for the
  /// legacy-tuned instance.
  const new({
    this.backToTopOffsetThreshold = 400,
    this.backToBottomDistanceThreshold = 400,
    this.jumpAnimationBaseMs = 180,
    this.jumpAnimationMsPerPx = 1 / 8,
    this.jumpAnimationMinMs = 220,
    this.jumpAnimationMaxMs = 520,
    this.mobilePageSize = 20,
    this.desktopPageSize = 40,
    this.desktopBreakpointWidth = 680,
    this.pageSizeOptions = const [20, 40, 60, 80],
  });

  /// The legacy-tuned default configuration.
  static const PaginationViewConfig defaults = PaginationViewConfig();

  /// Scroll offset past which the back-to-top button shows.
  final double backToTopOffsetThreshold;

  /// Remaining distance past which the back-to-bottom button shows.
  final double backToBottomDistanceThreshold;

  /// Jump animation length: `base + distance * msPerPx`, clamped to
  /// `[minMs, maxMs]`.
  final int jumpAnimationBaseMs;

  /// Per-pixel component of the jump animation length.
  final double jumpAnimationMsPerPx;

  /// Lower clamp of the jump animation length.
  final int jumpAnimationMinMs;

  /// Upper clamp of the jump animation length.
  final int jumpAnimationMaxMs;

  /// Page size on phone layouts.
  final int mobilePageSize;

  /// Page size on desktop layouts (settings may override per user).
  final int desktopPageSize;

  /// Layout width above which a window uses the desktop paged view.
  final double desktopBreakpointWidth;

  /// Offered page-size choices for the desktop selector.
  final List<int> pageSizeOptions;

  /// Whether the back-to-top affordance should be visible at [offset].
  bool shouldShowBackToTop(double offset) => offset > backToTopOffsetThreshold;

  /// Whether the back-to-bottom affordance should be visible:
  /// not already resting at the edge, and more than
  /// [backToBottomDistanceThreshold] away from the bottom.
  bool shouldShowBackToBottom(double offset, double maxScrollExtent, {required bool atEdge}) {
    if (atEdge && offset > 0) {
      return false;
    }
    return maxScrollExtent - offset > backToBottomDistanceThreshold;
  }

  /// Neither affordance makes sense without scrollable content.
  bool shouldHideJumpButtons({required bool hasClients}) => !hasClients;

  /// Animation duration for a jump of [distance] pixels.
  Duration jumpAnimationDuration(double distance) {
    final ms = (jumpAnimationBaseMs + distance * jumpAnimationMsPerPx).round().clamp(
      jumpAnimationMinMs,
      jumpAnimationMaxMs,
    );
    return Duration(milliseconds: ms);
  }

  /// Whether a window of [width] uses the desktop paged view.
  bool isDesktopLayout(double width, {required bool isMobile}) => width > desktopBreakpointWidth && !isMobile;

  /// The page size for a layout; [userPageSize] overrides on desktop
  /// (the user's persisted choice).
  int pageSizeFor({required bool isDesktop, int? userPageSize}) {
    if (!isDesktop) {
      return mobilePageSize;
    }
    final size = userPageSize ?? desktopPageSize;
    return size < 1 ? desktopPageSize : size;
  }

  /// The page-size selector options including [current] when missing, so
  /// a user-edited size never disappears from the dropdown.
  List<int> pageSizeOptionsIncluding(int current) {
    if (pageSizeOptions.contains(current)) {
      return pageSizeOptions;
    }
    return [...pageSizeOptions, current]..sort();
  }

  /// A copy with the given fields replaced.
  PaginationViewConfig copyWith({
    double? backToTopOffsetThreshold,
    double? backToBottomDistanceThreshold,
    int? jumpAnimationBaseMs,
    double? jumpAnimationMsPerPx,
    int? jumpAnimationMinMs,
    int? jumpAnimationMaxMs,
    int? mobilePageSize,
    int? desktopPageSize,
    double? desktopBreakpointWidth,
    List<int>? pageSizeOptions,
  }) => PaginationViewConfig(
    backToTopOffsetThreshold: backToTopOffsetThreshold ?? this.backToTopOffsetThreshold,
    backToBottomDistanceThreshold: backToBottomDistanceThreshold ?? this.backToBottomDistanceThreshold,
    jumpAnimationBaseMs: jumpAnimationBaseMs ?? this.jumpAnimationBaseMs,
    jumpAnimationMsPerPx: jumpAnimationMsPerPx ?? this.jumpAnimationMsPerPx,
    jumpAnimationMinMs: jumpAnimationMinMs ?? this.jumpAnimationMinMs,
    jumpAnimationMaxMs: jumpAnimationMaxMs ?? this.jumpAnimationMaxMs,
    mobilePageSize: mobilePageSize ?? this.mobilePageSize,
    desktopPageSize: desktopPageSize ?? this.desktopPageSize,
    desktopBreakpointWidth: desktopBreakpointWidth ?? this.desktopBreakpointWidth,
    pageSizeOptions: pageSizeOptions ?? this.pageSizeOptions,
  );
}
