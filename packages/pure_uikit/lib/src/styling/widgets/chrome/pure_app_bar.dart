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
import 'package:pure_uikit/src/styling/widgets/controls/pure_button.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// The public top bar: one widget, every design language.
///
/// It carries only the neutral parts of a bar (title, [leading], [actions]);
/// its appearance comes straight from the active design language's own widget
/// library. There is no adapter and no spec in between: [build] switches on
/// `UiConfig.language` and constructs the library's real bar directly —
/// Material's `AppBar`, Cupertino's `CupertinoNavigationBar`, macOS's `ToolBar`
/// and forui's `FHeader.nested` — or, where the library ships no bar of its
/// own (fluent, glass, neumorphic, wind), composes one out of that library's
/// own surfaces and typography, as the languages' package builders did — so
/// what the user sees is exactly what that library's own documentation shows.
/// Switching `UiConfig.language` re-skins every bar.
///
/// Material's bars imply a back affordance from the router; the other
/// languages have no such convention, so this widget owns the semantics: a
/// page that can pop and gave no [leading] of its own gets the shared back
/// affordance (a [PureIconButton]), whatever language draws the bar.
class PureAppBar extends StatelessWidget {
  /// A bar titled [title].
  const new({
    required this.title,
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

  /// A widget before the title — a back affordance or a drawer button.
  final Widget? leading;

  /// Actions after the title, in order. Give them the `Pure*` forms so they
  /// follow the language too.
  final List<Widget> actions;

  /// A strip under the title row, typically a tab strip.
  final Widget? bottom;

  /// A background override; null keeps the theme's header surface.
  final Color? background;

  /// Whether the title sits in the middle; null defers to the language.
  final bool? centerTitle;

  /// The title-row height; null takes the environment's bar height.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final leading = this.leading ?? _impliedBack(context);
    return switch (theme.config.language) {
      // Yaru draws chrome with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (see
      // `PureApp._yaruHost`), not from a different bar.
      PureDesignLanguage.material || PureDesignLanguage.yaru => AppBar(
        leading: leading,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
        centerTitle: centerTitle,
        bottom: switch (bottom) {
          final PreferredSizeWidget sized => sized,
          _ => null,
        },
        toolbarHeight: height,
        backgroundColor: background ?? theme.colors.bgElevated,
      ),
      PureDesignLanguage.cupertino => cupertino.CupertinoNavigationBar(
        leading: leading,
        middle: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: switch (actions) {
          [] => null,
          [final Widget only] => only,
          final List<Widget> rest => Row(mainAxisSize: MainAxisSize.min, children: rest),
        },
        bottom: switch (bottom) {
          final PreferredSizeWidget sized => sized,
          _ => null,
        },
        backgroundColor: background ?? theme.colors.bgElevated,
      ),
      PureDesignLanguage.macos => _macosBar(context, theme, leading),
      PureDesignLanguage.fluent => _fluentHeader(context, leading),
      PureDesignLanguage.neumorphic => _neumorphicBar(context, leading),
      PureDesignLanguage.glass => _glassBar(context, theme, leading),
      PureDesignLanguage.wind => _windBar(context, theme, leading),
      PureDesignLanguage.forui => _foruiHeader(leading),
    };
  }

  /// macOS draws its `ToolBar`; the title row takes [leading] ahead of it and
  /// a macOS bar centres its title unless told otherwise.
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
        title: Text(
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
  /// library's own primitives: the title on the theme's subtitle ramp, the
  /// actions as an ordinary row. A fluent header is left-titled and
  /// content-sized, so [centerTitle] and [height] are not mapped — centring
  /// it would be the bar saying something about iOS rather than about the
  /// caller.
  Widget _fluentHeader(BuildContext context, Widget? leading) {
    final typography = f2.FluentTheme.of(context).typography;
    final header = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
      child: Row(
        children: [
          ?leading,
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: typography.subtitle1),
            ),
          ),
          if (actions.isNotEmpty) ...[const SizedBox(width: 8), Row(mainAxisSize: MainAxisSize.min, children: actions)],
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
      title: Text(title),
      titleAlignment: centerTitle == true ? Alignment.center : AlignmentDirectional.centerStart,
      prefixes: leading == null ? const <Widget>[] : <Widget>[leading],
      suffixes: actions,
      style: background == null && height == null
          ? const forui.FHeaderStyleDelta.context()
          : forui.FHeaderStyleDelta.delta(
              constraints: switch (height) {
                final height? => BoxConstraints.tightFor(height: height),
                null => null,
              },
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
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
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

  /// Glass composes the bar, and measures first: the library does have a
  /// `GlassAppBar`, but it is a Material `AppBar` with a frosted `flexibleSpace`
  /// pasted into it — it asserts `No MaterialLocalizations found.` outside a
  /// Material host, takes the whole window under loose constraints, and its
  /// `bottom` slot wants a `PreferredSizeWidget`. So the bar here is the
  /// library's *surface*: a floating [glass.GlassContainer] sheet, squared along
  /// its bottom edge, taking its blur, tint, stroke and radius from
  /// [glass.GlassTheme]. [centerTitle] defaults to centred — a glass header
  /// reads as an iOS-style sheet — and [background] tints the sheet rather than
  /// replacing it, because a glass header has no opaque side.
  Widget _glassBar(BuildContext context, PureTheme theme, Widget? leading) {
    final glassTheme = glass.GlassTheme.of(context);
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    final barHeight = height ?? geometry?.appBarHeight ?? 56;
    final padding = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final gap = theme.token.scale.sizes.sm;
    final center = centerTitle ?? true;
    final radius = glassTheme.borderRadius;

    final row = SizedBox(
      height: barHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Row(
          children: [
            if (leading case final lead?) ...[lead, SizedBox(width: gap)],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: center ? TextAlign.center : TextAlign.start,
                  style: theme.text.title.copyWith(color: theme.colors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            for (final action in actions) ...[SizedBox(width: gap), action],
          ],
        ),
      ),
    );

    return glass.GlassContainer(
      padding: EdgeInsets.symmetric(vertical: theme.token.scale.sizes.xs),
      customBorderRadius: BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius / 2),
        bottomRight: Radius.circular(radius / 2),
      ),
      color: background ?? glassTheme.color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          if (bottom case final strip?)
            Padding(
              padding: EdgeInsets.only(top: gap),
              child: strip,
            ),
        ],
      ),
    );
  }

  /// Wind composes the bar — the fork has no bar of any kind. The surface is
  /// its own container, a `WDiv` panel in the library's `bg-white dark:bg-gray-900`
  /// pair closed by the Tailwind bottom hairline, with the title in `WText` at
  /// the library's `text-lg font-semibold` step and [actions] appended as the
  /// widgets the caller already dispatched. [height] and [background] are
  /// runtime values, so neither is interpolated into a className (the library
  /// caches parsed class strings): the height goes to a `SizedBox` and the
  /// colour override to the container's inline `backgroundColor` hook.
  /// [centerTitle] defaults to left; asking for the centre is answered with
  /// `text-center` on a title that already takes the leftover width.
  Widget _windBar(BuildContext context, PureTheme theme, Widget? leading) {
    final geometry = PureEnvironmentScope.maybeOf(context)?.geometry;
    final barHeight = height ?? geometry?.appBarHeight ?? 56;
    final padding = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final centered = (centerTitle ?? false) ? ' text-center' : '';

    final titleText = wind.WText(
      title,
      className: 'text-lg font-semibold text-gray-900 dark:text-gray-100 truncate$centered',
    );

    final row = wind.WDiv(
      className: 'flex flex-row items-center gap-2 w-full h-full',
      children: [
        ?leading,
        Expanded(child: titleText),
        for (final action in actions) action,
      ],
    );

    return wind.WDiv(
      className: 'flex flex-col w-full bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700',
      backgroundColor: background,
      children: [
        SizedBox(
          height: barHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: row,
          ),
        ),
        ?bottom,
      ],
    );
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
