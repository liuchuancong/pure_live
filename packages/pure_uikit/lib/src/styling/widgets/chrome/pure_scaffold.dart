import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_canvas_scope.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// The public page frame: one widget, every design language.
///
/// It carries only neutral data (the body, the already-dispatched bars, the
/// keyboard policy); its structure comes straight from the active design
/// language's own widget library. There is no adapter and no spec in between:
/// [build] switches on `UiConfig.language` and constructs the library's real
/// frame directly — Material's `Scaffold`, Cupertino's `CupertinoPageScaffold`,
/// macOS's `MacosScaffold` and forui's `FScaffold` — or, where the library
/// ships no frame of its own (fluent, glass, neumorphic, wind), composes a
/// column painted with that library's own surface, as the languages' package
/// builders did — so what the user sees is exactly what that library's own
/// documentation shows. Switching `UiConfig.language` re-skins every page.
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

  /// The top bar — pass a `PureAppBar` so the bar itself dispatches too.
  final Widget? appBar;

  /// A bottom bar: the shell's navigation, a tab strip, an action row.
  final Widget? bottomBar;

  /// A floating action, held at the trailing bottom corner.
  final Widget? floatingActionButton;

  /// A background override; null keeps the theme's layout surface.
  final Color? background;

  /// Whether [body] starts under [appBar] instead of below it.
  final bool extendBodyBehindAppBar;

  /// Whether the content keeps clear of an open on-screen keyboard.
  final bool avoidKeyboard;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return switch (theme.config.language) {
      // Yaru draws chrome with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (see
      // `PureApp._yaruHost`), not from a different frame. Glass, neumorphic
      // and wind ship no page frame, so Flutter's official Material Scaffold is
      // the shared fallback.
      PureDesignLanguage.material ||
      PureDesignLanguage.yaru ||
      PureDesignLanguage.neumorphic ||
      PureDesignLanguage.glass ||
      PureDesignLanguage.wind => _materialFrame(context, theme),
      PureDesignLanguage.fluent => _fluentFrame(context, theme),
      PureDesignLanguage.cupertino => _cupertinoFrame(context, theme),
      PureDesignLanguage.macos => _macosFrame(context, theme),
      PureDesignLanguage.forui => _foruiFrame(context, theme),
    };
  }

  /// The Fluent page frame. fluent_2 ships no scaffold, so this is the minimal
  /// layout column around already-dispatched Fluent widgets — not a hand-drawn
  /// control. The header keeps its natural height, including a tab strip.
  Widget _fluentFrame(BuildContext context, PureTheme theme) {
    final content = Column(
      children: [
        ?appBar,
        Expanded(
          child: avoidKeyboard
              ? Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                  child: body,
                )
              : body,
        ),
        ?bottomBar,
      ],
    );
    final page = ColoredBox(
      color: background ?? (PureCanvasScope.transparentOf(context) ? const Color(0x00000000) : theme.colors.bgLayout),
      child: content,
    );

    final action = floatingActionButton;
    if (action == null) {
      return page;
    }
    final margin = PureEnvironmentScope.maybeOf(context)?.geometry.pagePadding ?? theme.token.scale.sizes.md;
    return Stack(
      children: [
        Positioned.fill(child: page),
        PositionedDirectional(bottom: margin, end: margin, child: action),
      ],
    );
  }

  /// Material owns the frame outright: the bar and the bottom strip sit in its
  /// app-bar and bottom slots, the keyboard policy and the extend-behind-bar
  /// choice are its own parameters, and it takes the body's extent, safe area
  /// and scroll-under behaviour — which is what this language exists to get.
  Widget _materialFrame(BuildContext context, PureTheme theme) {
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    return Scaffold(
      appBar: _bar(appBar, geometry?.appBarHeight ?? 56),
      body: body,
      bottomNavigationBar: _bar(bottomBar, geometry?.navBarHeight ?? 64),
      floatingActionButton: floatingActionButton,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: avoidKeyboard,
      backgroundColor:
          background ?? (PureCanvasScope.transparentOf(context) ? const Color(0x00000000) : theme.colors.bgLayout),
    );
  }

  /// Material's frame asks for a `PreferredSizeWidget` in both bar slots — so
  /// one that is one goes straight in, and a foreign one (a bar composed from
  /// plain widgets, or another language's rendering inside a mixed tree) is
  /// given the height its own frame would have used.
  static PreferredSizeWidget? _bar(Widget? widget, double height) => switch (widget) {
    null => null,
    final PreferredSizeWidget sized => sized,
    final child => PreferredSize(preferredSize: Size.fromHeight(height), child: child),
  };

  /// Cupertino's `CupertinoPageScaffold` owns the iOS bar behaviour the frame
  /// asks for — the translucent nav bar, the scroll-under and the keyboard
  /// policy — and takes the bar in its navigation-bar slot.
  ///
  /// Three fields have no slot in this widget and are handled rather than
  /// dropped: the bottom strip (iOS puts one on `CupertinoTabScaffold`, a
  /// different widget, so the frame stacks it under the page), the floating
  /// action (Cupertino has no FAB; the environment's page margin places it)
  /// and [extendBodyBehindAppBar] (a Cupertino nav bar always overlays the
  /// scrollable content, which is the iOS answer to that flag).
  Widget _cupertinoFrame(BuildContext context, PureTheme theme) {
    // The nav-bar slot takes the library's own bar type. A bar from another
    // language is not one, so it goes above the content rather than being
    // dropped.
    final cupertino.ObstructingPreferredSizeWidget? navBar;
    final Widget pageBody;
    switch (appBar) {
      case final cupertino.ObstructingPreferredSizeWidget sized:
        navBar = sized;
        pageBody = body;
      case final Widget bar:
        navBar = null;
        pageBody = Column(
          children: [
            bar,
            Expanded(child: body),
          ],
        );
      case null:
        navBar = null;
        pageBody = body;
    }

    final page = cupertino.CupertinoPageScaffold(
      navigationBar: navBar,
      backgroundColor:
          background ?? (PureCanvasScope.transparentOf(context) ? const Color(0x00000000) : theme.colors.bgLayout),
      resizeToAvoidBottomInset: avoidKeyboard,
      child: pageBody,
    );

    final strip = bottomBar;
    final action = floatingActionButton;
    final Widget frame;
    if (strip == null) {
      frame = page;
    } else {
      frame = Column(
        children: [
          Expanded(child: page),
          strip,
        ],
      );
    }
    if (action == null) {
      return frame;
    }
    final margin = PureEnvironmentScope.maybeOf(context)?.geometry.pagePadding ?? theme.token.scale.sizes.md;
    return Stack(
      children: [
        Positioned.fill(child: frame),
        PositionedDirectional(bottom: margin, end: margin, child: action),
      ],
    );
  }

  /// macOS composes a window as `MacosScaffold` + one `ContentArea`, and the
  /// bars sit around it — the dispatched bar and strip are whatever the active
  /// language renders, which the frame may not assume.
  ///
  /// Two fields have no macOS slot at this level: the floating action (the
  /// library has no FAB, so the environment's page margin places it) and
  /// [extendBodyBehindAppBar] / [avoidKeyboard] — a macOS window's content
  /// area already sits inside its own safe area and does not resize for a
  /// keyboard.
  Widget _macosFrame(BuildContext context, PureTheme theme) {
    final scaffold = macos.MacosScaffold(
      backgroundColor: background ?? (PureCanvasScope.transparentOf(context) ? const Color(0x00000000) : null),
      children: [
        // `ContentArea` hands its builder a scroll controller; the body owns
        // its own scrolling, so the controller is not taken.
        macos.ContentArea(builder: (context, controller) => body),
      ],
    );

    final frame = Column(
      children: [
        ?appBar,
        Expanded(child: scaffold),
        ?bottomBar,
      ],
    );

    final action = floatingActionButton;
    if (action == null) {
      return frame;
    }
    final margin = PureEnvironmentScope.maybeOf(context)?.geometry.pagePadding ?? theme.token.scale.sizes.md;
    return Stack(
      children: [
        Positioned.fill(child: frame),
        PositionedDirectional(bottom: margin, end: margin, child: action),
      ],
    );
  }

  /// forui owns the frame outright: `FScaffold` is the library's own frame —
  /// header slot, content, footer — so the already-dispatched bar goes into
  /// `header` and the destination strip into `footer`, which is also where the
  /// library paints its own top border for the bottom bar.
  /// [avoidKeyboard] is the library's `resizeToAvoidBottomInset` under another
  /// name and [background] is a style delta on the frame's background colour,
  /// so neither has to be painted over the widget.
  ///
  /// Two fields have no slot and are handled rather than dropped:
  /// [extendBodyBehindAppBar] asks for a body that starts under the bar, which
  /// the library's header slot cannot do (it stacks the bar above the content),
  /// so the frame gets no header and the bar is overlaid at the top of the
  /// content area — the bar keeps its own safe-area inset;
  /// [floatingActionButton] is placed by the environment's page padding, since
  /// a ForUI page has no floating-action slot at all.
  Widget _foruiFrame(BuildContext context, PureTheme theme) {
    final bar = appBar;
    final behindBar = extendBodyBehindAppBar && bar != null;

    final frameBody = behindBar
        ? Stack(
            children: [
              Positioned.fill(child: body),
              Positioned(top: 0, left: 0, right: 0, child: bar),
            ],
          )
        : body;

    final frame = forui.FScaffold(
      header: behindBar ? null : bar,
      footer: bottomBar,
      resizeToAvoidBottomInset: avoidKeyboard,
      scaffoldStyle: switch (background) {
        final color? => forui.FScaffoldStyleDelta.delta(backgroundColor: color),
        null => const forui.FScaffoldStyleDelta.context(),
      },
      child: frameBody,
    );

    final action = floatingActionButton;
    if (action == null) {
      return frame;
    }
    final margin = PureEnvironmentScope.maybeOf(context)?.geometry.pagePadding ?? theme.token.scale.sizes.md;
    return Stack(
      children: [
        Positioned.fill(child: frame),
        PositionedDirectional(bottom: margin, end: margin, child: action),
      ],
    );
  }
}
