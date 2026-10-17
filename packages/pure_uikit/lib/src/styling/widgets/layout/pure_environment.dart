import 'package:flutter/widgets.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/tokens/design_token.dart';

/// How a page lays out — the same orthogonal axis as the platform and the
/// design language: a desktop window dragged narrow becomes [mobile], a TV
/// build is always [tv]. Resolved from the live width plus the declared TV
/// form factor, never guessed from the platform alone.
enum PureLayoutMode {
  /// One column, bottom navigation, thumb-reachable controls.
  mobile,

  /// Side navigation, window-shaped content, pointer and keyboard.
  desktop,

  /// Large cards, focus navigation, remote-control reach.
  tv,
}

/// The window-size thresholds that separate the layout modes.
class PureBreakpoints {
  /// A breakpoint set.
  const new({this.mobileMax = 720, this.desktopMin = 1024});

  /// Widths below this are laid out as [PureLayoutMode.mobile].
  final double mobileMax;

  /// Widths at or above this are full [PureLayoutMode.desktop].
  final double desktopMin;

  /// The default thresholds.
  static const PureBreakpoints standard = PureBreakpoints();

  /// The mode a [width] implies for this breakpoint set.
  PureLayoutMode resolve(double width, {required bool isTv}) {
    if (isTv) {
      return PureLayoutMode.tv;
    }
    if (width >= desktopMin) {
      return PureLayoutMode.desktop;
    }
    if (width >= mobileMax) {
      // A tablet / narrow desktop: desktop chrome but wider touch margins.
      return PureLayoutMode.desktop;
    }
    return PureLayoutMode.mobile;
  }
}

/// The per-mode spacing, icon and surface geometry a page reads — the new
/// home for what used to be the old `componentTheme`. Derived from the design
/// tokens and scaled up for TV, so padding is one source rather than every
/// page's literals.
@immutable
final class Geometry {
  /// A geometry set.
  const new({
    required this.mode,
    required this.pagePadding,
    required this.sectionGap,
    required this.iconGap,
    required this.iconSize,
    required this.controlRadius,
    required this.cardRadius,
    required this.cardElevation,
    required this.navBarHeight,
    required this.railWidth,
    required this.contentMaxWidth,
    required this.dialogMaxWidth,
    required this.appBarHeight,
  });

  /// Derives the geometry for [mode] from the design [token].
  factory forTokens(DesignToken token, PureLayoutMode mode) {
    final sizes = token.scale.sizes;
    final tv = mode == PureLayoutMode.tv;
    final desktop = mode == PureLayoutMode.desktop;
    return Geometry(
      mode: mode,
      pagePadding: tv ? 48 : (desktop ? 24 : 16),
      sectionGap: tv ? 32 : sizes.lg,
      iconGap: tv ? 12 : sizes.sm,
      iconSize: tv ? 28 : (desktop ? 20 : 18),
      controlRadius: token.scale.radii.base,
      cardRadius: token.scale.radii.lg,
      cardElevation: tv ? 6 : 3,
      navBarHeight: tv ? 96 : 64,
      railWidth: tv ? 0 : 88,
      contentMaxWidth: tv ? 1920 : 1100,
      dialogMaxWidth: desktop ? 520 : 420,
      appBarHeight: tv ? 88 : 56,
    );
  }

  /// The mode this geometry was resolved for.
  final PureLayoutMode mode;

  /// The page margin.
  final double pagePadding;

  /// The spacing between sections.
  final double sectionGap;

  /// The gap beside an icon.
  final double iconGap;

  /// The standard icon size.
  final double iconSize;

  /// The control corner radius.
  final double controlRadius;

  /// The card corner radius.
  final double cardRadius;

  /// The card elevation.
  final double cardElevation;

  /// The bottom-nav height.
  final double navBarHeight;

  /// The desktop rail width (0 on TV).
  final double railWidth;

  /// The maximum content width.
  final double contentMaxWidth;

  /// The maximum dialog width.
  final double dialogMaxWidth;

  /// The top bar's title-row height, so a page never invents one.
  final double appBarHeight;

  @override
  bool operator ==(Object other) =>
      other is Geometry &&
      other.mode == mode &&
      other.pagePadding == pagePadding &&
      other.sectionGap == sectionGap &&
      other.iconGap == iconGap &&
      other.iconSize == iconSize &&
      other.controlRadius == controlRadius &&
      other.cardRadius == cardRadius &&
      other.cardElevation == cardElevation &&
      other.navBarHeight == navBarHeight &&
      other.railWidth == railWidth &&
      other.contentMaxWidth == contentMaxWidth &&
      other.dialogMaxWidth == dialogMaxWidth &&
      other.appBarHeight == appBarHeight;

  // Every field, because `PureEnvironmentScope.updateShouldNotify` compares two
  // `Geometry` objects: a field left out here is a field whose change silently
  // leaves the subtree laid out with the old numbers.
  @override
  int get hashCode => Object.hash(
    mode,
    pagePadding,
    sectionGap,
    iconGap,
    iconSize,
    controlRadius,
    cardRadius,
    cardElevation,
    navBarHeight,
    railWidth,
    contentMaxWidth,
    dialogMaxWidth,
    appBarHeight,
  );
}

/// The runtime layout environment: the resolved [mode] and its [geometry]. Data,
/// not behaviour — a page reads it instead of measuring or checking the
/// platform itself.
@immutable
final class PureEnvironment {
  /// An environment.
  const new({required this.mode, required this.geometry, required this.isTv});

  /// Computes the environment for a window [width] on this (possibly TV) build.
  factory compute({
    required double width,
    required bool isTv,
    required DesignToken token,
    PureBreakpoints breakpoints = PureBreakpoints.standard,
  }) {
    final mode = breakpoints.resolve(width, isTv: isTv);
    return PureEnvironment(mode: mode, geometry: Geometry.forTokens(token, mode), isTv: isTv);
  }

  /// The current layout mode.
  final PureLayoutMode mode;

  /// The geometry that follows from [mode].
  final Geometry geometry;

  /// Whether this is a TV build.
  final bool isTv;

  /// Convenience flags pages branch on.
  bool get isMobile => mode == PureLayoutMode.mobile;

  /// Whether the layout is the TV form.
  bool get isTvMode => mode == PureLayoutMode.tv;

  @override
  bool operator ==(Object other) =>
      other is PureEnvironment && other.mode == mode && other.isTv == isTv && other.geometry == geometry;

  @override
  int get hashCode => Object.hash(mode, isTv, geometry);
}

/// Provides a [PureEnvironment] to the subtree, installed by
/// [PureLayoutBuilder] whenever the window is resized.
class PureEnvironmentScope extends InheritedWidget {
  /// A scope exposing [environment].
  const new({required this.environment, required super.child, super.key});

  /// The environment every `PureEnvironmentScope.of(context)` below returns.
  final PureEnvironment environment;

  /// The nearest environment.
  static PureEnvironment of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PureEnvironmentScope>()!.environment;

  /// The nearest environment, or null outside a [PureLayoutBuilder].
  static PureEnvironment? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PureEnvironmentScope>()?.environment;

  @override
  bool updateShouldNotify(PureEnvironmentScope oldWidget) => environment != oldWidget.environment;
}

/// Rebuilds [builder] with an environment recomputed from the live window width,
/// so a page can lay out for mobile, desktop or TV from one source of truth. The
/// declared [isTv] comes from the composition root, never inferred here.
class PureLayoutBuilder extends StatelessWidget {
  /// A responsive layout builder.
  const new({required this.isTv, required this.builder, super.key});

  /// Whether this build targets a TV form factor.
  final bool isTv;

  /// Builds the subtree for the resolved environment.
  final Widget Function(BuildContext context, PureEnvironment environment) builder;

  @override
  Widget build(BuildContext context) {
    final token = PureTheme.of(context).token;
    return LayoutBuilder(
      builder: (context, constraints) {
        final environment = PureEnvironment.compute(width: constraints.maxWidth, isTv: isTv, token: token);
        return PureEnvironmentScope(
          environment: environment,
          child: Builder(builder: (context) => builder(context, environment)),
        );
      },
    );
  }
}

/// A responsive content grid (the room/channel list). It reads the current
/// [PureEnvironment] so a phone shows two cover tiles across and a desktop or
/// TV shows more, with the same token spacing — one widget for every layout
/// mode, mirroring the old TV content grid without its platform checks.
class PureContentGrid extends StatelessWidget {
  /// A content grid.
  const new({
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.maxTileWidth = 260,
    this.aspectRatio = 0.72,
    super.key,
  });

  /// The number of tiles.
  final int itemCount;

  /// Builds the tile at an index.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// An optional scroll controller (for infinite scroll).
  final ScrollController? controller;

  /// The widest a tile grows before another column is added.
  final double maxTileWidth;

  /// Each tile's width-to-height ratio.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final geometry = PureEnvironmentScope.of(context).geometry;
    final gap = geometry.iconGap * 2;
    return GridView.builder(
      controller: controller,
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxTileWidth,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: gap,
        mainAxisSpacing: gap,
      ),
      itemBuilder: itemBuilder,
    );
  }
}
