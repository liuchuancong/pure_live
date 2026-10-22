import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_canvas_scope.dart';
import 'package:pure_uikit/src/styling/widgets/controls/pure_button.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// The public top bar: one widget, every design language.
///
/// It carries only the neutral parts of a bar (title, [leading], [actions]);
/// its appearance comes straight from the active design language's own widget
/// library. There is no adapter and no spec in between: [build] switches on
/// `UiConfig.language` and constructs the library's real bar directly —
/// Material's `AppBar`, Cupertino's `CupertinoNavigationBar`, macOS's `ToolBar`,
/// glass's `GlassAppBar`, forui's `FHeader.nested`, and Flutter's official
/// Material `AppBar` for wind. Fluent has no app-bar widget, so it keeps the
/// minimal layout row around its own typography and actions.
/// own surfaces and typography, as the languages' package builders did — so
/// what the user sees is exactly what that library's own documentation shows.
/// Switching `UiConfig.language` re-skins every bar.
///
/// Material's bars imply a back affordance from the router; the other
/// languages have no such convention, so this widget owns the semantics: a
/// page that can pop and gave no [leading] of its own gets the shared back
/// affordance (a [PureIconButton]), whatever language draws the bar.
class PureAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// A bar titled [title].
  const new({
    required this.title,
    this.titleWidget,
    this.leading,
    this.actions = const <Widget>[],
    this.bottom,
    this.background,
    this.centerTitle,
    this.height,
    super.key,
  });

  /// The page title.
  final String title;

  /// A widget in the title slot instead of the text — the reference puts a
  /// page's own tab bar there. Languages whose bar has no widget slot fall
  /// back to [title].
  final Widget? titleWidget;

  /// A widget before the title — a back affordance or a drawer button.
  final Widget? leading;

  /// Actions after the title, in order. Give them the `Pure*` forms so they
  /// follow the language too.
  final List<Widget> actions;

  /// A strip under the title row, typically a tab strip.
  final Widget? bottom;

  /// A background override; null keeps the theme's header surface —
  /// transparent where the window's own material shows through (the bar reads
  /// as part of that surface, the way the system shell's header does), the
  /// elevated header colour otherwise.
  final Color? background;

  /// Whether the title sits in the middle; null defers to the language.
  final bool? centerTitle;

  /// The title-row height; null takes the environment's bar height.
  final double? height;

  /// The bar's total height: the title row plus a stacked bottom strip. The
  /// Material Scaffold frame reserves exactly this much; a bar that composed
  /// itself from a column (macOS, fluent, forui, neumorphic stack the strip
  /// under the bar because those libraries' bars have no bottom slot) must
  /// report the sum, or the strip overflows the reserved slot.
  @override
  Size get preferredSize {
    final bar = height ?? kToolbarHeight;
    final strip = switch (bottom) {
      final PreferredSizeWidget sized => sized.preferredSize.height,
      _ => 0.0,
    };
    return Size.fromHeight(bar + strip);
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final leading = this.leading ?? _impliedBack(context);
    final defaultSurface = PureCanvasScope.transparentOf(context) ? const Color(0x00000000) : theme.colors.bgElevated;
    return switch (theme.config.language) {
      // Yaru draws chrome with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (see
      // `PureApp._yaruHost`), not from a different bar.
      PureDesignLanguage.material || PureDesignLanguage.yaru => AppBar(
        leading: leading,
        title: titleWidget ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
        centerTitle: centerTitle,
        bottom: switch (bottom) {
          final PreferredSizeWidget sized => sized,
          _ => null,
        },
        toolbarHeight: height,
        backgroundColor: background ?? defaultSurface,
      ),
      PureDesignLanguage.cupertino => cupertino.CupertinoNavigationBar(
        leading: leading,
        middle: titleWidget ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: switch (actions) {
          [] => null,
          [final Widget only] => only,
          final List<Widget> rest => Row(mainAxisSize: MainAxisSize.min, children: rest),
        },
        bottom: switch (bottom) {
          final PreferredSizeWidget sized => sized,
          _ => null,
        },
        backgroundColor: background ?? defaultSurface,
      ),
      PureDesignLanguage.macos => _macosBar(context, theme, leading),
      PureDesignLanguage.fluent => _fluentHeader(context, leading),
      PureDesignLanguage.neumorphic => _neumorphicBar(context, leading),
      PureDesignLanguage.glass => glass.GlassAppBar(
        title: titleWidget ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: leading,
        actions: actions.isEmpty ? null : actions,
        bottom: switch (bottom) {
          final PreferredSizeWidget sized => sized,
          _ => null,
        },
        centerTitle: centerTitle,
        automaticallyImplyLeading: false,
        toolbarHeight: height ?? PureEnvironmentScope.maybeOf(context)?.geometry.appBarHeight ?? kToolbarHeight,
        color: background ?? glass.GlassTheme.of(context).color,
        opacity: glass.GlassTheme.of(context).opacity,
      ),
      // fluttersdk_wind ships no app bar. Flutter's official Material AppBar is
      // the fallback; the wind page content still carries the language.
      PureDesignLanguage.wind => AppBar(
        leading: leading,
        title: titleWidget ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
        centerTitle: centerTitle,
        toolbarHeight: height,
        backgroundColor: background ?? defaultSurface,
        bottom: switch (bottom) {
          final PreferredSizeWidget sized => sized,
          _ => null,
        },
      ),
      PureDesignLanguage.forui => _foruiHeader(leading),
    };
  }

  /// macOS draws its `ToolBar`; the title row takes [leading] ahead of it and
  /// a macOS bar centres its title unless told otherwise.
  ///
  /// The bar centres its `title` in the space between [leading] and
  /// [actions], and a wide widget there overflows that slot — the library
  /// offers no start-aligned or flexible title. So this bar keeps to the
  /// [title] string: a caller's [titleWidget] (the room's status tabs, the
  /// discovery pages' picker and search) has no honest home in the grammar,
  /// and squeezing it in draws an overflow stripe across the bar.
  ///
  /// `ToolBar`'s internal layout asks to be as tall as it can — fine inside
  /// `MacosScaffold.toolBar`, which sizes it, but an assertion when a frame
  /// stacks the bar in a column. A macOS bar has exactly one height and the
  /// spec says what it is, so the widget states it rather than hoping its
  /// parent bounds it.
  ///
  /// [bottom] has no slot in a `ToolBar`, so the bar is stacked with it and
  /// that pairing is documented rather than dropped: the strip still renders,
  /// in the language of whatever draws it.
  Widget _macosBar(BuildContext context, PureTheme theme, Widget? leading) {
    final height = this.height ?? PureEnvironmentScope.maybeOf(context)?.geometry.appBarHeight ?? 52;
    final bar = SizedBox(
      height: height,
      child: macos.ToolBar(
        height: height,
        title:
            titleWidget ??
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colors.text),
            ),
        leading: leading,
        centerTitle: centerTitle ?? true,
        decoration: background == null ? null : BoxDecoration(color: background),
        actions: [for (final action in actions) macos.CustomToolbarItem(inToolbarBuilder: (_) => action)],
      ),
    );

    final strip = bottom;
    if (strip == null) {
      return bar;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [bar, strip]);
  }

  /// fluent_2 ships no page-header widget, so the header composes the
  /// library's own primitives in the Windows 11 Settings grammar: a large
  /// 28 px left-titled page name (the title ramp's own `display` size, so the
  /// density and font tokens still drive it), actions on the same row's end,
  /// no bar chrome behind. A fluent header is left-titled and content-sized,
  /// so [centerTitle] and [height] are not mapped — centring it would be the
  /// bar saying something about iOS rather than about the caller.
  Widget _fluentHeader(BuildContext context, Widget? leading) {
    final typography = f2.FluentTheme.of(context).typography;
    final header = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: Row(
        children: [
          ?leading,
          Expanded(
            child: Semantics(
              header: true,
              child:
                  titleWidget ??
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // The ramp's largest member (subtitle1) is the 20/28 semibold
                    // the drawer headers use; the page name is Windows 11's 28 px
                    // semibold, so the ramp is overridden at the one axis the
                    // page-name grammar needs. Family and colour stay the ramp's.
                    style: typography.subtitle1.copyWith(fontSize: 28),
                  ),
            ),
          ),
          if (actions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );

    final strip = bottom;
    final bar = strip == null ? header : Column(mainAxisSize: MainAxisSize.min, children: [header, strip]);
    if (background == null) {
      return bar;
    }
    return DecoratedBox(
      decoration: BoxDecoration(color: background),
      child: bar,
    );
  }

  /// forui's `FHeader.nested` is the library's own bar with both action slots:
  /// [leading] goes into `prefixes` and [actions] into `suffixes`, which the
  /// library lays out and pads itself. The root variant is not used because it
  /// has no leading slot, and a bar the caller gave a back affordance to cannot
  /// lose it. [centerTitle] maps onto the header's `titleAlignment`, and null
  /// keeps the library's *page* bar default — start-aligned. [background] and
  /// [height] go through the style delta, so the colour and the bar height are
  /// the library's fields written by the caller, not a box painted over the
  /// widget. [bottom] is stacked under the bar in a column: a ForUI header is
  /// one row, and the strip (a dispatched tab strip) belongs below it rather
  /// than inside it.
  Widget _foruiHeader(Widget? leading) {
    final header = forui.FHeader.nested(
      title: titleWidget ?? Text(title),
      titleAlignment: centerTitle == true ? Alignment.center : AlignmentDirectional.centerStart,
      prefixes: leading == null ? const <Widget>[] : <Widget>[leading],
      suffixes: actions,
      style: forui.FHeaderStyleDelta.delta(
        // The frame reserves [preferredSize]'s height; the header is pinned to
        // it so its natural 64 never overflows the slot by a few pixels.
        constraints: BoxConstraints.tightFor(height: height ?? kToolbarHeight),
        decoration: switch (background) {
          final color? => forui.DecorationDelta.boxDelta(color: color),
          null => null,
        },
      ),
    );

    final strip = bottom;
    return strip == null ? header : Column(mainAxisSize: MainAxisSize.min, children: [header, strip]);
  }

  /// Neumorphic **maps** onto the library's own `NeuAppBar` — a `NeuContainer`
  /// plane carrying a `NavigationToolbar`, an ordinary inline widget that also
  /// implements `PreferredSizeWidget`, so it needs no Material `Scaffold` or
  /// app shell. [leading] and [actions] go straight through (an empty list is
  /// passed as null so the toolbar does not reserve a slot for it),
  /// [centerTitle] defaults to centred, [height] sizes the title row only and
  /// [background] maps onto `baseColor` — the library's own way of overriding a
  /// surface, not a fill painted over it. [bottom] is the one field with no
  /// slot: the library types it as a `PreferredSizeWidget`, while the strip is
  /// any dispatched widget, so it is stacked under the bar on the same plane.
  Widget _neumorphicBar(BuildContext context, Widget? leading) {
    final surface = neu.NeuTheme.of(context);
    // The library's own bar height (`kToolbarHeight`), restated as a literal
    // because this file is not the library's own source.
    const toolbarHeight = 56.0;
    final bar = neu.NeuAppBar(
      title: titleWidget ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: leading,
      actions: actions.isEmpty ? null : actions,
      centerTitle: centerTitle ?? true,
      height: height ?? toolbarHeight,
      baseColor: background ?? surface.baseColor,
    );

    final strip = bottom;
    if (strip == null) {
      return bar;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [bar, strip]);
  }

  /// The shared back affordance, or null where the route cannot pop.
  ///
  /// A [PureIconButton], so the affordance looks native whatever language
  /// owns the bar.
  Widget? _impliedBack(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null || !route.canPop) {
      return null;
    }
    final localizations = Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
    return PureIconButton(
      icon: Icons.arrow_back,
      tooltip: localizations?.backButtonTooltip ?? '',
      onPressed: () => Navigator.maybePop(context),
    );
  }
}
