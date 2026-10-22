import 'dart:ui' show ImageFilter, SemanticsRole;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_canvas_scope.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// How much a frosted layer blurs the plane behind it: the page plate takes
/// the deeper blur (it sits under everything), a bar band the shallower one
/// the tab bar's frosted track uses, so chrome reads as glass over the page
/// rather than as a second plate.
const double _plateBlurSigma = 24;
const double _bandBlurSigma = 14;

/// The public page frame: one widget whose plate is drawn here, over Flutter's
/// own layout engine.
///
/// The engine stays exactly where it was — a stack around the content box,
/// the [MediaQuery] insets for the keyboard, the safe-area treatment of the
/// bar slots, the environment's page margin for the floating action — and
/// the bars themselves are whatever the app already composed ([appBar] and
/// [bottomBar] go in untouched). The surface is the fluent one: the mica
/// plane — a scrim lifted from the elevated tone down into the layout surface
/// — with chrome floating on an acrylic band and the wide, soft shadow WinUI
/// casts under a command bar. No hairline: the shadow is the separation. All
/// of it is painted from the theme's own tokens, and the config's `language`
/// names the scaffold's identity key only — a non-fluent value keeps
/// compiling and simply draws this plate.
///
/// The layout contract: a bar slot reserves the bar's own height when it
/// declares one (`PreferredSizeWidget`) and the environment's
/// [Geometry.appBarHeight]/[Geometry.navBarHeight] for every other bar; the
/// body lands between the slots unless [extendBodyBehindAppBar] asks for the
/// overlay; [avoidKeyboard] shrinks the content box by the live keyboard
/// inset on the theme's [PureTheme.duration]; the bands paint behind the
/// status bar and the home indicator while the bars keep their insets, and
/// the plate always runs to the physical edge.
class PureScaffold extends StatelessWidget {
  /// A page frame around [body].
  const new({
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
    this.background,
    this.extendBodyBehindAppBar = false,
    this.avoidKeyboard = true,
    super.key,
  });

  /// The page content.
  final Widget body;

  /// The top bar — pass a `PureAppBar` so the bar follows the theme too.
  final Widget? appBar;

  /// A bottom bar: the shell's navigation, a tab strip, an action row.
  final Widget? bottomBar;

  /// A floating action, held at the trailing bottom corner.
  final Widget? floatingActionButton;

  /// A background override; null keeps the theme's own plane.
  final Color? background;

  /// Whether [body] starts under [appBar] instead of below it.
  final bool extendBodyBehindAppBar;

  /// Whether the content keeps clear of an open on-screen keyboard.
  final bool avoidKeyboard;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = _Visual.fluent();
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    final padding = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    final viewInsets = MediaQuery.maybeViewInsetsOf(context) ?? EdgeInsets.zero;

    final topHeight = _slotHeight(appBar, fallback: geometry?.appBarHeight ?? 56);
    final bottomHeight = _slotHeight(bottomBar, fallback: geometry?.navBarHeight ?? 64);
    // The content box reserves the slots it sits between; the plate always
    // runs edge to edge, so a bar's band paints behind the status bar and
    // the home indicator while the bar itself keeps its inset. Extending
    // behind the bar drops the top reservation — the overlay still rides at
    // the top of the page.
    final reserveTop = appBar == null || extendBodyBehindAppBar ? 0.0 : padding.top + topHeight;
    final reserveBottom = bottomHeight == 0 ? 0.0 : padding.bottom + bottomHeight;
    // The keyboard covers what the bottom padding already accounted for, so
    // the content shrinks by the inset above it rather than twice over.
    final keyboard = avoidKeyboard ? viewInsets.bottom - padding.bottom : 0.0;
    final keyboardInset = keyboard > 0 ? keyboard : 0.0;

    final slots = <Widget>[
      PositionedDirectional(
        top: reserveTop,
        start: 0,
        end: 0,
        bottom: reserveBottom,
        child: AnimatedPadding(
          key: const ValueKey('PureScaffold.content'),
          padding: EdgeInsets.only(bottom: keyboardInset),
          duration: theme.duration,
          curve: Curves.easeOut,
          // The engine host the page's controls answer to: a transparency
          // Material paints no plate of its own (the surface is ours, token
          // by token) but still answers the `TextField`/`InkWell` ancestor
          // the kit's own controls are built against. The plate above, the
          // host below — that is what pure_field did for the field's
          // decoration.
          child: Material(type: MaterialType.transparency, child: body),
        ),
      ),
      if (appBar case final bar?) _topSlot(context, theme, visual, bar, height: topHeight, inset: padding.top),
      if (bottomBar case final bar?)
        _bottomSlot(context, theme, visual, bar, height: bottomHeight, inset: padding.bottom),
      if (floatingActionButton case final action?)
        PositionedDirectional(
          bottom: reserveBottom + keyboardInset + _fabMargin(theme, geometry),
          end: _fabMargin(theme, geometry),
          child: action,
        ),
    ];

    // The page plane: the token surface, a caller's background over it, or
    // nothing at all when a PureCanvasScope says the app's own wallpaper
    // should show through. The band keeps painting — chrome edges are read
    // against the wallpaper too.
    final plate = switch ((background, PureCanvasScope.transparentOf(context))) {
      (final Color color?, _) => BoxDecoration(color: color),
      (null, true) => const BoxDecoration(color: Color(0x00000000)),
      (null, false) => visual.plate(theme),
    };
    final frosted = _shouldFrost(theme, plate.color);
    return KeyedSubtree(
      key: ValueKey('PureScaffold.${theme.config.language.name}'),
      child: DecoratedBox(
        key: const ValueKey('PureScaffold.plate'),
        decoration: plate,
        child: frosted
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: _plateBlurSigma, sigmaY: _plateBlurSigma),
                child: _frame(slots),
              )
            : _frame(slots),
      ),
    );
  }

  /// The engine: a box that fills its (bounded) page and stacks the content
  /// with the chrome overlays over it, so a slot's shadow spills onto the
  /// body the way Scaffold paints bars over content.
  Widget _frame(List<Widget> slots) => Stack(fit: StackFit.expand, children: slots);

  /// The top band: the acrylic plate a bar sits on and the shadow it casts
  /// into the content below. The bar keeps its own rendering — the band only
  /// answers for the surface. The slot scopes its semantics so the bar's
  /// controls read as one group, but takes no landmark role: a page with both
  /// slots must keep exactly one navigation landmark, and that is the
  /// destination strip below.
  Widget _topSlot(
    BuildContext context,
    PureTheme theme,
    _Visual visual,
    Widget bar, {
    required double height,
    required double inset,
  }) {
    return PositionedDirectional(
      top: 0,
      start: 0,
      end: 0,
      child: Semantics(
        key: const ValueKey('PureScaffold.topBarSlot'),
        container: true,
        child: _band(
          context,
          theme,
          color: visual.topBand?.call(theme),
          shadows: visual.topShadow(theme),
          bar: bar,
          height: height,
          inset: inset,
          removeTop: true,
        ),
      ),
    );
  }

  /// The bottom band, mirrored: no plate of its own — the bar answers for its
  /// surface — and the home-indicator inset lives inside the band, not under
  /// it. This slot carries the page's navigation landmark — the destinations
  /// live here, and the header deliberately does not.
  Widget _bottomSlot(
    BuildContext context,
    PureTheme theme,
    _Visual visual,
    Widget bar, {
    required double height,
    required double inset,
  }) {
    return PositionedDirectional(
      bottom: 0,
      start: 0,
      end: 0,
      child: Semantics(
        key: const ValueKey('PureScaffold.bottomBarSlot'),
        role: SemanticsRole.navigation,
        container: true,
        child: _band(
          context,
          theme,
          color: null,
          shadows: const <BoxShadow>[],
          bar: bar,
          height: height,
          inset: inset,
          removeTop: false,
        ),
      ),
    );
  }

  /// One band: decoration, frost, and the bar at its reserved height inside
  /// it. The bar's own [MediaQuery] padding is removed on the inset side —
  /// the contract that keeps a composed bar from insetting itself twice.
  Widget _band(
    BuildContext context,
    PureTheme theme, {
    required Color? color,
    required List<BoxShadow> shadows,
    required Widget bar,
    required double height,
    required double inset,
    required bool removeTop,
  }) {
    Widget slot = Material(
      // Same engine host as the content box: the bars keep their
      // Material-engine controls (icons, ink, text fields) without the band
      // painting a second plate over the theme's own.
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(top: removeTop ? inset : 0, bottom: removeTop ? 0 : inset),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: removeTop,
          removeBottom: !removeTop,
          child: SizedBox(height: height, child: bar),
        ),
      ),
    );
    if (_shouldFrost(theme, color)) {
      slot = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _bandBlurSigma, sigmaY: _bandBlurSigma),
          child: slot,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: color, boxShadow: shadows.isEmpty ? null : shadows),
      child: slot,
    );
  }

  /// The floating action's margin — the environment's page padding (16 on
  /// phones, 24 on desktop, 48 on TV), the token's md step outside a layout
  /// scope. The bar slots it rides above are already reserved.
  double _fabMargin(PureTheme theme, Geometry? geometry) => geometry?.pagePadding ?? theme.token.scale.sizes.md;

  /// A slot reserves the bar's own height when it declares one (the
  /// `PreferredSizeWidget` contract), and the environment's bar height for
  /// every other bar.
  static double _slotHeight(Widget? bar, {required double fallback}) => switch (bar) {
    null => 0,
    final PreferredSizeWidget sized => sized.preferredSize.height,
    final Widget _ => fallback,
  };

  /// Whether a layer is translucent enough to want the backdrop behind it
  /// blurred — and the device and policy still allow it. A fully clear layer
  /// (the canvas-scope plate) blurs nothing: it shows the backdrop exactly as
  /// it is.
  static bool _shouldFrost(PureTheme theme, Color? color) =>
      color != null && color.a > 0 && color.a < 1 && theme.canBlur && theme.config.allowsTransparency;
}

/// How the page is surfaced: the plate it paints, the backing band the top
/// bar slot gets, and the shadow that band casts into the content.
@immutable
final class _Visual {
  const new({required this.plate, this.topBand, List<BoxShadow> Function(PureTheme theme)? topShadow})
    : topShadow = topShadow ?? _noShadow;

  /// Windows Fluent: the mica plane — a scrim lifted from the elevated tone
  /// down into the layout surface — with chrome floating on an acrylic band
  /// and the wide, soft shadow WinUI casts under a command bar. No hairline:
  /// the shadow is the separation.
  factory fluent() => _Visual(
    plate: (theme) => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(theme.colors.bgLayout, theme.colors.bgElevated, 0.35)!, theme.colors.bgLayout],
      ),
    ),
    topBand: (theme) => _frost(theme, theme.colors.bgLayout, 0.72),
    topShadow: (theme) => [
      BoxShadow(color: theme.colors.shadowBase.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6)),
    ],
  );

  /// The page plane painted under the chrome.
  final BoxDecoration Function(PureTheme theme) plate;

  /// The band behind the top bar; null when the bar answers for its own
  /// surface.
  final Color? Function(PureTheme theme)? topBand;

  /// The shadows the top band casts into the content box.
  final List<BoxShadow> Function(PureTheme theme) topShadow;

  /// A translucent plane of [base] at the config's [opacity], scaled by the
  /// config's transparency policy — and a fully solid one when the policy (or
  /// the hardware) refuses translucency altogether.
  static Color _frost(PureTheme theme, Color base, double opacity) {
    if (!theme.canBlur || !theme.config.allowsTransparency) {
      return base;
    }
    return base.withValues(alpha: (opacity * theme.config.effectiveTransparency).clamp(0.35, 1.0));
  }

  static List<BoxShadow> _noShadow(PureTheme theme) => const [];
}
