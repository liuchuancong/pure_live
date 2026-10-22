import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' as cupertino show ObstructingPreferredSizeWidget;
import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_canvas_scope.dart';
import 'package:pure_uikit/src/styling/widgets/controls/pure_button.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// The kit's app bar: one widget that paints the top plate of the page — the
/// Windows 11 Settings header — from the theme's own tokens.
///
/// The header reads the slot contract — [leading] before the title, [actions]
/// after it, [bottom] under the title row, the title from [title] or
/// [titleWidget] — and answers it with its own geometry: no plate, a 28 px
/// left-titled page name, content-sized (a compact bar), actions inline.
///
/// Nothing here is delegated: no library's `AppBar` or `ToolBar` is
/// constructed; the gutters and the title cell are laid out from `PureTheme`
/// colours, radii and type, so a dark switch comes out of the same tokens the
/// kit's other chrome reads. The config's `language` names the bar's identity
/// key only — a non-fluent value keeps compiling and simply draws this header.
///
/// The shared contract: the title cell answers to `Semantics(header:)`;
/// [elevation] and [blur] toggle the plate's cast and its frost; the status-bar
/// inset is taken only when the bar sits under one; the plate restyles
/// instantly on a config change rather than tweening — a bar that animated its
/// own border into a focus ring is exactly the decoration-lerp trap this kit
/// has already stepped in, and chrome has nothing to gain there.
///
/// Fluent's header carries no back convention of its own, so this widget owns
/// the semantics: a page that can pop and gave no [leading] of its own gets
/// the shared back affordance (a [PureIconButton]). Hover and press tints
/// belong to the buttons the slots carry, not to the plate.
class PureAppBar extends StatelessWidget implements PreferredSizeWidget, cupertino.ObstructingPreferredSizeWidget {
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
    this.elevation,
    this.blur,
    super.key,
  });

  /// The page title.
  final String title;

  /// A widget in the title slot instead of the text — the reference puts a
  /// page's own tab bar there. The title cell is a flexible slot the plate
  /// owns, not a library's fixed title field, so a widget the size of a tab
  /// strip neither overflows nor gets dropped.
  final Widget? titleWidget;

  /// A widget before the title — a back affordance or a drawer button.
  final Widget? leading;

  /// Actions after the title, in order. Give them the `Pure*` forms so they
  /// follow the theme too.
  final List<Widget> actions;

  /// A strip under the title row, typically a tab strip. It always renders;
  /// [preferredSize] can only reserve for it when it states its own height (a
  /// [PreferredSizeWidget]), which is how every call site in the app hands it.
  final Widget? bottom;

  /// A background override; null keeps the theme's header surface —
  /// transparent, so the window's own material shows through and the bar reads
  /// as part of that surface, the way the system shell's header does. An
  /// explicit colour also answers the frost question: colour painted on top of
  /// a blur is the caller saying something the header did not get to say.
  final Color? background;

  /// Whether the title sits in the middle; null keeps it started — the Windows
  /// 11 Settings header alignment. An explicit value is honoured either way —
  /// the plate owns its own title cell, so there is no library grammar to
  /// refuse it.
  final bool? centerTitle;

  /// The title-row height; null takes the environment's bar height (and the
  /// toolbar's own 56 outside a layout scope).
  final double? height;

  /// Whether the plate casts a shadow; null keeps it flat — the fluent header
  /// carries no cast of its own.
  final bool? elevation;

  /// Whether the plate frosts the content behind it through a backdrop filter;
  /// null keeps the header solid (the Windows header does not frost). An
  /// explicit true frosts wherever the device affords it; an explicit false
  /// paints the plate solid everywhere.
  final bool? blur;

  /// The bar's total height: the title row plus a stacked bottom strip. The
  /// frame reserves exactly this much; the bar composes itself from a column
  /// (the strip stacks under the row because the header has no bottom slot of
  /// its own) and must report the sum, or the strip overflows the reserved
  /// slot.
  @override
  Size get preferredSize {
    final bar = height ?? kToolbarHeight;
    final strip = switch (bottom) {
      final PreferredSizeWidget sized => sized.preferredSize.height,
      _ => 0.0,
    };
    return Size.fromHeight(bar + strip);
  }

  /// The iOS nav-bar slot asks whether the bar fully obstructs the scrolling
  /// content: the opaque plate does, the frosted one lets the page read
  /// through — the same answer the system bar gives.
  @override
  bool shouldFullyObstruct(BuildContext context) => !_frosted(PureTheme.of(context), _BarVisual.fluent(), context);

  /// Whether this call resolves to a frosted plate: the caller's [blur] wins;
  /// otherwise the header's own default — no frost — but never under an
  /// explicit [background] (painting a colour over a blur is the caller's
  /// answer to "translucent") nor on a transparent canvas (there is nothing
  /// behind the plate to frost). And only when the device can afford the
  /// filter at all.
  bool _frosted(PureTheme theme, _BarVisual visual, BuildContext context) {
    final transparentCanvas = PureCanvasScope.transparentOf(context);
    return (blur ?? (background == null && visual.blurredByDefault && !transparentCanvas)) && theme.canBlur;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = _BarVisual.fluent();
    final leading = this.leading ?? _impliedBack(context);
    final transparentCanvas = PureCanvasScope.transparentOf(context);
    final surface = background ?? (transparentCanvas ? const Color(0x00000000) : visual.surface(theme));
    final frosted = _frosted(theme, visual, context);
    final elevated = elevation ?? visual.elevatedByDefault;
    final rowHeight = height ?? PureEnvironmentScope.maybeOf(context)?.geometry.appBarHeight ?? kToolbarHeight;
    // The status bar belongs above the plate only when the bar says it sits
    // under one; the Windows header sits inside its window's own title region.
    final topInset = visual.statusInset ? MediaQuery.paddingOf(context).top : 0.0;

    final titleCell = Semantics(
      // The bar's one always-present semantic: the page's name, wherever the
      // language puts it. The slot widgets carry their own semantics through
      // this header region untouched.
      header: true,
      child: titleWidget ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: visual.titleStyle(theme)),
    );

    final slots = Row(
      children: [
        if (leading != null)
          Padding(
            padding: EdgeInsetsDirectional.only(start: visual.leadingStartPad),
            child: leading,
          )
        else
          SizedBox(width: visual.bareStartPad),
        SizedBox(width: visual.slotGap),
        Expanded(
          child: Align(
            alignment: (centerTitle ?? visual.centered)
                ? AlignmentDirectional.center
                : AlignmentDirectional.centerStart,
            child: titleCell,
          ),
        ),
        SizedBox(width: visual.slotGap),
        if (actions.isNotEmpty)
          Padding(
            padding: EdgeInsetsDirectional.only(end: visual.endPad),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < actions.length; i++) ...[if (i > 0) SizedBox(width: visual.actionsGap), actions[i]],
              ],
            ),
          )
        else
          // The empty trailing slot mirrors the leading gutter, so a centred
          // title lands on the bar's own centre when nothing balances it.
          SizedBox(width: visual.bareStartPad),
      ],
    );

    // The Windows header is content-sized — the compact bar the design sheet
    // draws — so the row hugs its title unless the frame reserved a height. An
    // explicit `height` sizes it too. The sized content still bows to the
    // frame: a tall title (a tab strip standing in the title slot) clamps to
    // the reserved row minus the padding, so the bar never overflows the
    // height that was reserved for it.
    final row = visual.contentSized && height == null
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: visual.contentVerticalPad),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: math.max(0, rowHeight - 2 * visual.contentVerticalPad)),
              child: slots,
            ),
          )
        : SizedBox(height: rowHeight, child: slots);

    final content = Column(
      // The bar is chrome, not a sheet: it is exactly the inset, the row and
      // the strip tall — never the full box it happens to be offered.
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topInset > 0) SizedBox(height: topInset),
        row,
        ?bottom,
      ],
    );

    Widget plate = DecoratedBox(
      // The plate is the bar's identity in tests and diagnostics: its colour,
      // its cast and its rule all resolve here, statically. A hairline in the
      // decoration's own border (uniform colour, zero radius where it is
      // drawn) never meets the decoration-lerp trap, because nothing tweens
      // it.
      key: const ValueKey('PureAppBar.plate'),
      decoration: BoxDecoration(
        color: frosted ? (background ?? visual.frost(theme, surface)) : surface,
        borderRadius: visual.corner,
        boxShadow: elevated ? visual.shadow(theme) : null,
        border: visual.outline
            ? Border.all(color: theme.colors.borderSecondary)
            : visual.dividerWidth > 0
            ? Border(
                bottom: BorderSide(color: theme.colors.borderSecondary, width: visual.dividerWidth),
              )
            : null,
      ),
      child: content,
    );

    if (frosted) {
      plate = ClipRRect(
        borderRadius: visual.corner,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: visual.blurSigma, sigmaY: visual.blurSigma),
          child: plate,
        ),
      );
    }

    return KeyedSubtree(
      // The branch a language draws is its identity in tests and diagnostics.
      key: ValueKey('PureAppBar.${theme.config.language.name}'),
      child: plate,
    );
  }

  /// The shared back affordance, or null where the route cannot pop.
  ///
  /// A [PureIconButton], so the affordance follows the kit's own theme.
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

/// The geometry and colours the app bar plate is drawn with: the title's ramp
/// entry, the gutters the slot grammar owns, the frost, the rule under the
/// row, and the cast. Every value resolves from the theme when the bar builds,
/// so a dark switch and a canvas change come out of the same tokens the kit's
/// other chrome reads.
@immutable
final class _BarVisual {
  /// A bar visual.
  const new({
    required this.titleSize,
    required this.titleWeight,
    required this.centered,
    required this.bareStartPad,
    required this.leadingStartPad,
    required this.slotGap,
    required this.endPad,
    required this.actionsGap,
    required this.elevatedByDefault,
    required this.blurredByDefault,
    required this.blurSigma,
    required this.dividerWidth,
    required this.outline,
    required this.corner,
    required this.contentSized,
    required this.contentVerticalPad,
    required this.statusInset,
    required this.surface,
    required this.frost,
    required this.shadow,
  });

  /// The Windows 11 header: no plate at all (the page canvas is the surface),
  /// the 28 px semibold page name from the title ramp's largest step, and a
  /// row content-sized to the text — the compact bar the design sheet draws.
  factory fluent() {
    const quiet = Color(0x00000000);
    return _BarVisual(
      titleSize: 28,
      titleWeight: FontWeight.w600,
      centered: false,
      bareStartPad: 16,
      leadingStartPad: 16,
      slotGap: 12,
      endPad: 16,
      actionsGap: 4,
      elevatedByDefault: false,
      blurredByDefault: false,
      blurSigma: 14,
      dividerWidth: 0,
      outline: false,
      corner: BorderRadius.zero,
      contentSized: true,
      contentVerticalPad: 8,
      statusInset: false,
      surface: (_) => quiet,
      frost: (_, surface) => surface,
      shadow: (theme) => [
        BoxShadow(
          color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.4 : 0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// The title's absolute pixel size, before the theme's font scale.
  final double titleSize;

  /// The title's weight; the ramp carries the family and the line height.
  final FontWeight titleWeight;

  /// Whether the header centres its title when the caller says nothing.
  final bool centered;

  /// The start gutter with no [PureAppBar.leading]. It stays empty either way
  /// so a centred title (when the caller asks for one) lands on the bar's own
  /// centre.
  final double bareStartPad;

  /// The gutter in front of a supplied leading widget.
  final double leadingStartPad;

  /// The gap between a slot and the title cell.
  final double slotGap;

  /// The gutter after the last action.
  final double endPad;

  /// The gap packed between two actions.
  final double actionsGap;

  /// Whether the plate casts by default when the caller says nothing.
  final bool elevatedByDefault;

  /// Whether the plate frosts by default when the device affords it.
  final bool blurredByDefault;

  /// The sigma the frost is laid down with.
  final double blurSigma;

  /// The bottom hairline's width; zero draws no rule.
  final double dividerWidth;

  /// Whether the plate wears an outline on every edge instead of a bottom
  /// rule.
  final bool outline;

  /// The plate's corner radius.
  final BorderRadius corner;

  /// Whether the row hugs its content instead of the reserved height — the
  /// compact Windows header.
  final bool contentSized;

  /// The vertical padding of the content-sized row.
  final double contentVerticalPad;

  /// Whether the bar sits under a status bar and takes its inset.
  final bool statusInset;

  /// The plate's colour when not overridden.
  final Color Function(PureTheme theme) surface;

  /// The plate's colour while frosted; the default keeps the surface's hue at
  /// a translucency the frost reads through.
  final Color Function(PureTheme theme, Color surface) frost;

  /// The plate's cast while elevated.
  final List<BoxShadow> Function(PureTheme theme) shadow;

  /// The title's style: the ramp's family and line height at the header's
  /// own size and weight, scaled by the user's text setting the way every
  /// control here scales (the ratio is the ramp's own scale factor).
  TextStyle titleStyle(PureTheme theme) {
    final ratio = theme.text.title.fontSize! / theme.token.type.fontSizeHeading4;
    return theme.text.title.copyWith(fontSize: titleSize * ratio, fontWeight: titleWeight, color: theme.colors.text);
  }
}
