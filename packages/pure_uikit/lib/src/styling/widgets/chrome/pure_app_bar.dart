import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' as cupertino show ObstructingPreferredSizeWidget;
import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/widgets/chrome/pure_canvas_scope.dart';
import 'package:pure_uikit/src/styling/widgets/controls/pure_button.dart';
import 'package:pure_uikit/src/styling/widgets/layout/pure_environment.dart';

/// The kit's app bar: one widget that paints the top plate of the page in every
/// design language, from the theme's own tokens.
///
/// The nine languages read the same slot contract — [leading] before the title,
/// [actions] after it, [bottom] under the title row, the title from [title] or
/// [titleWidget] — and answers it with their own geometry:
///
/// * **fluent** keeps the Windows 11 Settings header: no plate, a 28 px
///   left-titled page name, content-sized (a compact bar), actions inline.
/// * **macos** runs the Aqua title bar: a sheened plate over an
///   traffic-light-owned 78 px start gutter, the title centred in the space
///   the slots leave, a hairline under the row.
/// * **cupertino** frosts the navigation plate (system-blur when the device
///   can afford it), centres the 17 px semibold title and keeps iOS's
///   separator hairline.
/// * **glass** lays a frosted plate — real backdrop blur where affordable, the
///   pure ramp where not — with its hairline outline.
/// * **wind** puts the 18 px semibold title on a flat elevated plate with a
///   bottom hairline, the shadcn crispness its sibling grammar keeps.
/// * **forui** draws the shadcn header on the layout surface: border-b, no
///   shadow, start-aligned.
/// * **material** is the M3 top app bar: the elevated surface carrying the
///   22 px regular title, and the material elevation shadow by default.
/// * **yaru** answers the Ubuntu headerbar: a distinct container-tone plate,
///   bold 15 px title centred, a bottom hairline, no shadow.
/// * **neumorphic** raises the plate off the page — dual light/shadow extrusion
///   on the container colour, rounded bottom corners, centred title.
///
/// Nothing here is delegated: no library's `AppBar`, `ToolBar`, `FHeader`,
/// `GlassAppBar` or `NeuAppBar` is constructed; the plate, the gutters, the
/// hairline, the sheen and the frost are painted from `PureTheme` colours,
/// radii and type, so a language re-skin and a dark switch come out of the same
/// tokens the kit's other chrome reads. Switching `UiConfig.language` re-skins
/// every bar.
///
/// The shared contract the languages vary only their look on: the title cell
/// answers to `Semantics(header:)` everywhere; [elevation] and [blur] toggle
/// the plate's cast and its frost against the language's own default; the
/// status-bar inset is taken by the languages whose bar sits under one; the
/// plate restyles instantly on a language switch rather than tweening — a bar
/// that animated its own border into a focus ring is exactly the decoration-lerp
/// trap this kit has already stepped in, and chrome has nothing to gain there.
///
/// Material's bars imply a back affordance from the router; the other languages
/// have no such convention, so this widget owns the semantics: a page that can
/// pop and gave no [leading] of its own gets the shared back affordance (a
/// [PureIconButton]), whatever language draws the bar. Hover and press tints
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
  /// page's own tab bar there. Every language now has an honest home for it:
  /// the title cell is a flexible slot the plate owns, not a library's fixed
  /// title field, so a widget the size of a tab strip neither overflows nor
  /// gets dropped.
  final Widget? titleWidget;

  /// A widget before the title — a back affordance or a drawer button.
  final Widget? leading;

  /// Actions after the title, in order. Give them the `Pure*` forms so they
  /// follow the language too.
  final List<Widget> actions;

  /// A strip under the title row, typically a tab strip. It always renders;
  /// [preferredSize] can only reserve for it when it states its own height (a
  /// [PreferredSizeWidget]), which is how every call site in the app hands it.
  final Widget? bottom;

  /// A background override; null keeps the theme's header surface —
  /// transparent where the window's own material shows through (the bar reads
  /// as part of that surface, the way the system shell's header does), the
  /// elevated header colour otherwise. An explicit colour also answers the
  /// language's frost default: colour painted on top of a blur is the caller
  /// saying something the language did not get to say.
  final Color? background;

  /// Whether the title sits in the middle; null defers to the language
  /// (centred on macOS, iOS, Yaru and neumorphic; started elsewhere). An
  /// explicit value is honoured in every language — the plate owns its own
  /// title cell, so there is no library grammar to refuse it.
  final bool? centerTitle;

  /// The title-row height; null takes the environment's bar height (and the
  /// toolbar's own 56 outside a layout scope).
  final double? height;

  /// Whether the plate casts a shadow; null defers to the language (Material
  /// and macOS cast one, neumorphic is the extruded language itself; the
  /// hairline-and-frost languages answer with the rule below instead).
  final bool? elevation;

  /// Whether the plate frosts the content behind it through a backdrop filter;
  /// null defers to the language (iOS and glass frost by default, over the
  /// device's own [PureTheme.canBlur]). An explicit true frosts wherever the
  /// device affords it; an explicit false paints the plate solid everywhere.
  final bool? blur;

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

  /// The iOS nav-bar slot asks whether the bar fully obstructs the scrolling
  /// content: the opaque plate does, the frosted one lets the page read
  /// through — the same answer the system bar gives.
  @override
  bool shouldFullyObstruct(BuildContext context) => !_frosted(PureTheme.of(context), _resolveVisual(context), context);

  /// The plate look the active language draws.
  _BarVisual _resolveVisual(BuildContext context) => _BarVisual.resolve(PureTheme.of(context));

  /// Whether this call resolves to a frosted plate: the caller's [blur] wins;
  /// otherwise the language's default, but never under an explicit
  /// [background] (painting a colour over a blur is the caller's answer to
  /// "translucent") nor on a transparent canvas (there is nothing behind the
  /// plate to frost). And only when the device can afford the filter at all.
  bool _frosted(PureTheme theme, _BarVisual visual, BuildContext context) {
    final transparentCanvas = PureCanvasScope.transparentOf(context);
    return (blur ?? (background == null && visual.blurredByDefault && !transparentCanvas)) && theme.canBlur;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = _resolveVisual(context);
    final leading = this.leading ?? _impliedBack(context);
    final transparentCanvas = PureCanvasScope.transparentOf(context);
    final surface = background ?? (transparentCanvas ? const Color(0x00000000) : visual.surface(theme));
    final frosted = _frosted(theme, visual, context);
    final elevated = elevation ?? visual.elevatedByDefault;
    final rowHeight = height ?? PureEnvironmentScope.maybeOf(context)?.geometry.appBarHeight ?? kToolbarHeight;
    // The status bar belongs above the plate on the languages whose app runs
    // under one; the desktop bars sit inside their window's own title region.
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

    // WinUI's header is content-sized — the compact bar the design sheet
    // draws — while the plate languages keep the row at the height the frame
    // reserved for it. An explicit `height` sizes fluent too. The sized
    // content still bows to the frame: a tall title (a tab strip standing in
    // the title slot) clamps to the reserved row minus the padding, so the
    // bar never overflows the height that was reserved for it.
    final row = visual.contentSized && height == null
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: visual.contentVerticalPad),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(0, rowHeight - 2 * visual.contentVerticalPad),
              ),
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

    if (visual.sheen case final colors?) {
      // The Aqua gloss rides in the foreground, painted over the row's own
      // children's bottom edge — a static foreground decoration, which is how
      // this kit draws every overlay that could otherwise be animated into a
      // non-uniform border.
      plate = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topCenter,
            end: AlignmentDirectional.bottomCenter,
            colors: colors,
          ),
          borderRadius: visual.corner,
        ),
        child: plate,
      );
    }

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

/// What one design language puts on the app bar plate: the surface and its
/// cast, the frost, the rule under the row, the title's ramp entry, and the
/// gutters its slot grammar owns. Every value resolves from the theme when the
/// bar builds, so a language re-skin, a dark switch and a canvas change come
/// out of the same tokens the kit's other chrome reads.
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
    this.sheen,
  });

  /// The nine bars, one per design language.
  factory resolve(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.fluent => _BarVisual.fluent(),
    PureDesignLanguage.macos => _BarVisual.macos(theme),
    PureDesignLanguage.cupertino => _BarVisual.cupertino(theme),
    PureDesignLanguage.glass => _BarVisual.glass(),
    PureDesignLanguage.wind => _BarVisual.wind(theme),
    PureDesignLanguage.forui => _BarVisual.forui(theme),
    PureDesignLanguage.material => _BarVisual.material(),
    PureDesignLanguage.yaru => _BarVisual.yaru(theme),
    PureDesignLanguage.neumorphic => _BarVisual.neumorphic(theme),
  };

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

  /// The Aqua title bar: the 13 px semibold centred in the space the slots
  /// leave, the traffic lights' 78 px gutter kept clear at the start, the
  /// subtle cast and the hairline the library draws under a vibrance bar —
  /// and the top-down white sheen that makes the plate read as Aqua.
  factory macos(PureTheme theme) {
    final sheenTop = theme.colors.white.withValues(alpha: theme.isDark ? 0.05 : 0.4);
    return _BarVisual(
      titleSize: 13,
      titleWeight: FontWeight.w600,
      centered: true,
      bareStartPad: 78,
      leadingStartPad: 78,
      slotGap: 10,
      endPad: 12,
      actionsGap: 8,
      elevatedByDefault: true,
      blurredByDefault: false,
      blurSigma: 14,
      dividerWidth: theme.token.motion.lineWidth,
      outline: false,
      corner: BorderRadius.zero,
      contentSized: false,
      contentVerticalPad: 0,
      statusInset: false,
      surface: (theme) => theme.colors.bgElevated,
      frost: (_, surface) => surface,
      shadow: (theme) => [
        BoxShadow(
          color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.35 : 0.1),
          blurRadius: 6,
          offset: const Offset(0, 1.5),
        ),
      ],
      sheen: [sheenTop, theme.colors.white.withValues(alpha: 0)],
    );
  }

  /// The iOS navigation plate: the 17 px semibold centred, the hairline
  /// separator, and the system frost over an 82 %-alpha plate where the
  /// device affords the filter (the plain ramp where it does not).
  factory cupertino(PureTheme theme) {
    return _BarVisual(
      titleSize: 17,
      titleWeight: FontWeight.w600,
      centered: true,
      bareStartPad: 16,
      leadingStartPad: 8,
      slotGap: 8,
      endPad: 16,
      actionsGap: 12,
      elevatedByDefault: false,
      blurredByDefault: true,
      blurSigma: 20,
      dividerWidth: theme.token.motion.lineWidth,
      outline: false,
      corner: BorderRadius.zero,
      contentSized: false,
      contentVerticalPad: 0,
      statusInset: true,
      surface: (theme) => theme.colors.bgElevated,
      frost: (theme, surface) => surface.withValues(alpha: theme.isDark ? 0.72 : 0.85),
      shadow: (theme) => [
        BoxShadow(
          color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.4 : 0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// The glass plate: a real backdrop frost (the pure ramp where the device
  /// cannot afford it) with the language's own white-tinted fill and a
  /// hairline outline on every edge, the title started like the Material bar
  /// the grammar grew from.
  factory glass() {
    return _BarVisual(
      titleSize: 17,
      titleWeight: FontWeight.w600,
      centered: false,
      bareStartPad: 16,
      leadingStartPad: 8,
      slotGap: 12,
      endPad: 16,
      actionsGap: 4,
      elevatedByDefault: false,
      blurredByDefault: true,
      blurSigma: 16,
      dividerWidth: 0,
      outline: true,
      corner: BorderRadius.zero,
      contentSized: false,
      contentVerticalPad: 0,
      statusInset: true,
      surface: (theme) => theme.colors.bgElevated,
      frost: (theme, _) => theme.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.55),
      shadow: (theme) => [
        BoxShadow(
          color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.4 : 0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// The wind plate: the sibling of the shadcn bar read crisper — the elevated
  /// surface, the 18 px semibold started after the leading slot, and the
  /// bottom hairline instead of a shadow.
  factory wind(PureTheme theme) {
    return _BarVisual(
      titleSize: 18,
      titleWeight: FontWeight.w600,
      centered: false,
      bareStartPad: 16,
      leadingStartPad: 8,
      slotGap: 12,
      endPad: 16,
      actionsGap: 4,
      elevatedByDefault: false,
      blurredByDefault: false,
      blurSigma: 14,
      dividerWidth: theme.token.motion.lineWidth,
      outline: false,
      corner: BorderRadius.zero,
      contentSized: false,
      contentVerticalPad: 0,
      statusInset: true,
      surface: (theme) => theme.colors.bgElevated,
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

  /// The forui header: shadcn's `border-b` on the layout surface — flat,
  /// undecorated, the 18 px semibold title started — because the library's
  /// own header says nothing about elevation.
  factory forui(PureTheme theme) {
    return _BarVisual(
      titleSize: 18,
      titleWeight: FontWeight.w600,
      centered: false,
      bareStartPad: 16,
      leadingStartPad: 8,
      slotGap: 12,
      endPad: 16,
      actionsGap: 4,
      elevatedByDefault: false,
      blurredByDefault: false,
      blurSigma: 14,
      dividerWidth: theme.token.motion.lineWidth,
      outline: false,
      corner: BorderRadius.zero,
      contentSized: false,
      contentVerticalPad: 0,
      statusInset: true,
      surface: (theme) => theme.colors.bgLayout,
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

  /// The Material 3 top app bar: the elevated surface under the 22 px regular
  /// title Flutter's own ramp draws, and the colour's cast — the sheet's
  /// scrolled state, answered statically because the plate carries no scroll
  /// listener of its own.
  factory material() {
    return _BarVisual(
      titleSize: 22,
      titleWeight: FontWeight.w400,
      centered: false,
      bareStartPad: 16,
      leadingStartPad: 4,
      slotGap: 8,
      endPad: 12,
      actionsGap: 4,
      elevatedByDefault: true,
      blurredByDefault: false,
      blurSigma: 14,
      dividerWidth: 0,
      outline: false,
      corner: BorderRadius.zero,
      contentSized: false,
      contentVerticalPad: 0,
      statusInset: true,
      surface: (theme) => theme.colors.bgElevated,
      frost: (_, surface) => surface,
      shadow: (theme) => theme.token.motion.boxShadow,
    );
  }

  /// The Ubuntu headerbar: its own container tone between the bar and the
  /// page, the bold 15 px title centred the way GNOME centres header titles,
  /// and a hairline under the row in place of a shadow.
  factory yaru(PureTheme theme) {
    return _BarVisual(
      titleSize: 15,
      titleWeight: FontWeight.w600,
      centered: true,
      bareStartPad: 12,
      leadingStartPad: 8,
      slotGap: 8,
      endPad: 12,
      actionsGap: 4,
      elevatedByDefault: false,
      blurredByDefault: false,
      blurSigma: 14,
      dividerWidth: theme.token.motion.lineWidth,
      outline: false,
      corner: BorderRadius.zero,
      contentSized: false,
      contentVerticalPad: 0,
      statusInset: true,
      surface: (theme) => theme.colors.bgContainer,
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

  /// The neumorphic plate: the container colour raised out of the page by the
  /// language's own dual cast — light from the top left, shadow from the
  /// bottom right — the bottom corners rounded off into the page, the title
  /// centred, no hairline (the extrusion is the rule).
  factory neumorphic(PureTheme theme) {
    return _BarVisual(
      titleSize: 18,
      titleWeight: FontWeight.w600,
      centered: true,
      bareStartPad: 16,
      leadingStartPad: 12,
      slotGap: 12,
      endPad: 16,
      actionsGap: 8,
      elevatedByDefault: true,
      blurredByDefault: false,
      blurSigma: 14,
      dividerWidth: 0,
      outline: false,
      corner: BorderRadius.vertical(bottom: Radius.circular(theme.token.scale.radii.lg)),
      contentSized: false,
      contentVerticalPad: 0,
      statusInset: true,
      surface: (theme) => theme.colors.bgContainer,
      frost: (_, surface) => surface,
      shadow: (theme) => [
        BoxShadow(color: theme.colors.shadowBase, blurRadius: 6, offset: const Offset(3, 3)),
        BoxShadow(
          color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.8),
          blurRadius: 6,
          offset: const Offset(-3, -3),
        ),
      ],
    );
  }

  /// The title's absolute pixel size, before the theme's font scale.
  final double titleSize;

  /// The title's weight; the ramp carries the family and the line height.
  final FontWeight titleWeight;

  /// Whether the language centres its title when the caller says nothing.
  final bool centered;

  /// The start gutter with no [PureAppBar.leading] — macOS's is the traffic
  /// lights' own region, and it stays empty either way so the centred title
  /// lands where the platform puts it.
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
  /// rule — the frosted language's hairline.
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

  /// The top-down overlay colours some languages sheen their plate with; null
  /// is the flat languages. It rides in a static foreground decoration — an
  /// overlay that animated alongside a border is the lerp trap this kit has
  /// already stepped in.
  final List<Color>? sheen;

  /// The title's style: the ramp's family and line height at this language's
  /// own size and weight, scaled by the user's text setting the way every
  /// control here scales (the ratio is the ramp's own scale factor).
  TextStyle titleStyle(PureTheme theme) {
    final ratio = theme.text.title.fontSize! / theme.token.type.fontSizeHeading4;
    return theme.text.title.copyWith(fontSize: titleSize * ratio, fontWeight: titleWeight, color: theme.colors.text);
  }
}
