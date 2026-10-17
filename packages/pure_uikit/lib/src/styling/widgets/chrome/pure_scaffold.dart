import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
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
      // `PureApp._yaruHost`), not from a different frame.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _materialFrame(context),
      PureDesignLanguage.cupertino => _cupertinoFrame(context, theme),
      PureDesignLanguage.macos => _macosFrame(context, theme),
      PureDesignLanguage.fluent => _fluentFrame(context, theme),
      PureDesignLanguage.neumorphic => _neumorphicFrame(context, theme),
      PureDesignLanguage.glass => _glassFrame(context, theme),
      PureDesignLanguage.wind => _windFrame(context, theme),
      PureDesignLanguage.forui => _foruiFrame(context, theme),
    };
  }

  /// Material owns the frame outright: the bar and the bottom strip sit in its
  /// app-bar and bottom slots, the keyboard policy and the extend-behind-bar
  /// choice are its own parameters, and it takes the body's extent, safe area
  /// and scroll-under behaviour — which is what this language exists to get.
  Widget _materialFrame(BuildContext context) {
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    return Scaffold(
      appBar: _bar(appBar, geometry?.appBarHeight ?? 56),
      body: body,
      bottomNavigationBar: _bar(bottomBar, geometry?.navBarHeight ?? 64),
      floatingActionButton: floatingActionButton,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: avoidKeyboard,
      backgroundColor: background ?? (PureCanvasScope.transparentOf(context) ? const Color(0x00000000) : null),
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
      backgroundColor: background ?? (PureCanvasScope.transparentOf(context) ? const Color(0x00000000) : theme.colors.bgLayout),
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

  /// fluent_2 ships no page frame, so the frame composes its own primitives —
  /// a column of the already-dispatched bars around the body — and paints the
  /// surface the `FluentTheme` resolves.
  ///
  /// Two fields have no fluent slot and are handled rather than dropped: the
  /// floating action is placed by the environment's page margin (fluent pages
  /// have no FAB) and [extendBodyBehindAppBar] is ignored because the header
  /// sits inside the content column anyway.
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
    final page = DecoratedBox(
      decoration: BoxDecoration(color: background ?? (PureCanvasScope.transparentOf(context) ? const Color(0x00000000) : f2.FluentTheme.of(context).colors.neutralBackground1)),
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

  /// Glass composes the frame: the library has none — `GlassAppBar` is its only
  /// structural widget and it is a Material bar — so the page is one full-bleed
  /// [glass.GlassContainer] sheet, the library's own surface, with the
  /// dispatched bar above the content, the bottom strip under it and the
  /// floating action held at the trailing corner. The sheet blurs what the app
  /// paints behind it, which is the whole point of the language. The sheet
  /// takes no tap, so no ink host is installed.
  ///
  /// [background] tints that sheet instead of replacing it — a glass frame has
  /// no opaque side to swap — [avoidKeyboard] is answered with the view insets,
  /// and [extendBodyBehindAppBar] lays the bar over the content in a stack.
  Widget _glassFrame(BuildContext context, PureTheme theme) {
    final glassTheme = glass.GlassTheme.of(context);
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    final margin = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final keyboard = avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    final bar = appBar;

    final content = Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: bar == null && !extendBodyBehindAppBar,
        bottom: bottomBar == null,
        child: body,
      ),
    );

    final Widget frameBody;
    if (bar == null) {
      frameBody = content;
    } else if (extendBodyBehindAppBar) {
      frameBody = Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(top: 0, left: 0, right: 0, child: bar),
        ],
      );
    } else {
      frameBody = Column(
        children: [
          bar,
          Expanded(child: content),
        ],
      );
    }

    final bottom = bottomBar;
    final frame = bottom == null
        ? frameBody
        : Column(
            children: [
              Expanded(child: frameBody),
              bottom,
            ],
          );

    final sheet = glass.GlassContainer(color: background ?? glassTheme.color, child: frame);

    final action = floatingActionButton;
    if (action == null) {
      return SizedBox.expand(child: sheet);
    }
    return Stack(
      children: [
        Positioned.fill(child: sheet),
        PositionedDirectional(bottom: margin + keyboard, end: margin, child: action),
      ],
    );
  }

  /// Neumorphic composes the frame: the library ships no page frame — every
  /// widget in it is a surface a caller places, and the only frame-shaped thing
  /// reachable from the dependency is Material's own `Scaffold`, precisely the
  /// surface this dispatch exists to remove. So the frame is the library's own
  /// plane — a `NeuContainer` on its default flat face at zero depth, i.e. the
  /// page surface rather than a raised card — with the already-dispatched bars
  /// stacked on top of it, laid out by flex rather than by a preferred size.
  ///
  /// [background] maps onto the plane's `baseColor` rather than onto a fill
  /// painted over it, [avoidKeyboard] is answered with the view insets,
  /// [extendBodyBehindAppBar] pins the bar to the top edge of the plane, and
  /// [floatingActionButton] is placed by the environment's page padding.
  Widget _neumorphicFrame(BuildContext context, PureTheme theme) {
    final surface = neu.NeuTheme.of(context);
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    final margin = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final keyboard = avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    final bar = appBar;

    final content = Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: bar == null && !extendBodyBehindAppBar,
        bottom: bottomBar == null,
        child: body,
      ),
    );

    Widget stacked;
    if (bar == null) {
      stacked = content;
    } else if (extendBodyBehindAppBar) {
      stacked = Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(top: 0, left: 0, right: 0, child: bar),
        ],
      );
    } else {
      stacked = Column(
        children: [
          bar,
          Expanded(child: content),
        ],
      );
    }

    final bottom = bottomBar;
    if (bottom != null) {
      stacked = Column(
        children: [
          Expanded(child: stacked),
          bottom,
        ],
      );
    }

    final plane = neu.NeuContainer(
      width: double.infinity,
      height: double.infinity,
      baseColor: background ?? surface.baseColor,
      depth: 0,
      distance: 0,
      // Zero radius plus zero depth is the base colour filling the slot: a page
      // is the surface every other plane sits on, not a plane with corners.
      borderRadius: BorderRadius.zero,
      child: stacked,
    );

    final action = floatingActionButton;
    if (action == null) {
      return plane;
    }
    return Stack(
      children: [
        Positioned.fill(child: plane),
        PositionedDirectional(bottom: margin + keyboard, end: margin, child: action),
      ],
    );
  }

  /// Wind composes the frame: the fork ships none — no `Scaffold`, no page, no
  /// inset policy — because it is a styling library, so the frame is the
  /// library's own container doing the job a frame does: a `WDiv` of
  /// `flex flex-col w-full h-full` whose background is the library's own canvas
  /// pair (`bg-gray-50 dark:bg-gray-900`, which follows the host `WindTheme`'s
  /// brightness, and that comes from the token). The dispatched bars are its
  /// neighbours and the body takes the remaining height through `Expanded`.
  ///
  /// [background] is a runtime colour, so it arrives through the container's
  /// inline `backgroundColor` hook; [avoidKeyboard] is answered with the view
  /// insets; [floatingActionButton] is placed by the environment's page
  /// padding, since a Wind page has no FAB corner to put it in.
  Widget _windFrame(BuildContext context, PureTheme theme) {
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    final margin = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final keyboard = avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    final bar = appBar;

    final content = Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: bar == null && !extendBodyBehindAppBar,
        bottom: bottomBar == null,
        child: body,
      ),
    );

    final Widget frameBody;
    if (bar == null) {
      frameBody = content;
    } else if (extendBodyBehindAppBar) {
      frameBody = Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(top: 0, left: 0, right: 0, child: bar),
        ],
      );
    } else {
      frameBody = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(child: content),
        ],
      );
    }

    final frame = wind.WDiv(
      className: 'flex flex-col w-full h-full bg-gray-50 dark:bg-gray-900',
      backgroundColor: background ?? (PureCanvasScope.transparentOf(context) ? const Color(0x00000000) : null),
      children: [
        Expanded(child: frameBody),
        ?bottomBar,
      ],
    );

    final action = floatingActionButton;
    if (action == null) {
      return frame;
    }
    return Stack(
      children: [
        Positioned.fill(child: frame),
        PositionedDirectional(bottom: margin + keyboard, end: margin, child: action),
      ],
    );
  }
}
