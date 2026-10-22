import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
// Only for the [PureDesignLanguage] enum the switch below names; the widget
// draws every language itself and touches no adapter.
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart';

/// The corner the iOS inset-grouped section clips its card to. Absolute, the
/// way the platform's is: it belongs to the grammar, not to the app's radius
/// seed, so the plate reads as iOS whatever the token ladder says.
const double _iosSectionRadius = 10;

/// The public card: one plate, drawn here in nine self-painted grammars, over
/// Flutter's own layout engine.
///
/// Every library frame the card used to borrow — Material's `Card` + `InkWell`,
/// the iOS inset-grouped section, `MacosSheet`, `FluentCard`, `FCard`,
/// `GlassCard`, `NeuCard`, `WCard` — is gone. What the user sees is painted
/// from the theme's own tokens, one grammar per [PureDesignLanguage]:
/// Material's elevated surface (token card shadow, 12pt corner), the iOS
/// grouped inset plate at the section's own 10pt corner, macOS's settings
/// group box (flat surface under a hairline rule), WinUI's CardBackground
/// (8pt corner, CardBorder hairline, the soft cast a card drops on the page),
/// Yaru's flat round card, shadcn/forui's bordered sheet, the glass language's
/// frosted plate over a real backdrop blur, neumorphic's extruded mould (the
/// twin cast-and-glow shadows, no stroke), and wind's crisp bordered card.
/// Colours, radii and shadows come only from `theme.colors.*`, the card
/// component token and the radius scale, so a language re-skin and a dark
/// switch still come out right.
///
/// Where the card is tappable ([onTap] or [onLongPress] set) it answers the
/// uniform interaction contract: hover and pressed tints blended into the
/// plate, a focus ring painted through a static foreground [DecoratedBox]
/// (never a tweened `foregroundDecoration`, never a tree that changes on
/// focus — the ring box is always there, its stroke simply transparent until
/// the card holds focus), Enter/Space/select key activation for keyboards and
/// remotes, and button + selected semantics. A plain card takes no focus and
/// draws no ring — the old contract, kept. [selected] tints the surface to
/// the primary background and rules it with the primary border wherever the
/// grammar accepts a stroke; [bordered] draws the plain hairline; [dense]
/// tightens the inner padding by the same 0.66 step the family has always
/// taken; [padding] replaces it outright; [style] overrides the plate's fill,
/// stroke and corner whatever the language promised.
class PureCard extends StatelessWidget {
  /// A card wrapping [child].
  const new({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.bordered = false,
    this.dense = false,
    this.padding,
    this.focusNode,
    this.autofocus = false,
    this.style,
    super.key,
  });

  /// The card content.
  final Widget child;

  /// The tap handler.
  final VoidCallback? onTap;

  /// A long-press handler.
  final VoidCallback? onLongPress;

  /// Whether the card shows a selected state.
  final bool selected;

  /// Whether the card is bordered.
  final bool bordered;

  /// Whether the card uses a tighter padding.
  final bool dense;

  /// An explicit inner padding.
  final EdgeInsetsGeometry? padding;

  /// A focus node and first-focus flag.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An inline style override.
  final Style? style;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = _resolveVisual(theme);
    final interactive = onTap != null || onLongPress != null;
    final inset = padding ?? EdgeInsets.all(dense ? theme.card.padding * 0.66 : theme.card.padding);
    return KeyedSubtree(
      // The grammar this card is drawing, addressable in tests and diagnostics.
      key: ValueKey('PureCard.${theme.config.language.name}'),
      child: _CardSurface(
        theme: theme,
        visual: visual,
        inset: inset,
        interactive: interactive,
        selected: selected,
        outlined: bordered,
        overrides: style,
        onTap: onTap,
        onLongPress: onLongPress,
        focusNode: focusNode,
        autofocus: autofocus,
        child: child,
      ),
    );
  }

  /// The nine card grammars, one per design language.
  static _Visual _resolveVisual(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.material => _Visual.material(),
    PureDesignLanguage.cupertino => _Visual.cupertino(),
    PureDesignLanguage.macos => _Visual.macos(),
    PureDesignLanguage.fluent => _Visual.fluent(),
    PureDesignLanguage.glass => _Visual.glass(),
    PureDesignLanguage.neumorphic => _Visual.neumorphic(),
    PureDesignLanguage.wind => _Visual.wind(),
    PureDesignLanguage.forui => _Visual.forui(),
    PureDesignLanguage.yaru => _Visual.yaru(),
  };
}

/// How one design language plates a card: the surface, the corner, the hairline
/// and shadow that set it off the page, the interaction tints a tappable card
/// blends over the surface, and whether the plate is frosted through a real
/// backdrop blur.
@immutable
final class _Visual {
  const new({
    required this.surface,
    required this.radius,
    this.hairline,
    List<BoxShadow> Function(PureTheme theme)? shadow,
    Color Function(PureTheme theme)? hoverTint,
    Color Function(PureTheme theme)? pressedTint,
    this.frost = 0,
    this.strokesSelection = true,
  }) : shadow = shadow ?? _flat,
       hoverTint = hoverTint ?? _fillTint,
       pressedTint = pressedTint ?? _fillSecondaryTint;

  /// Android Material's elevated card: the container surface on the card
  /// token's own drop shadow, 12pt corner (M3's large card radius), no stroke
  /// until `bordered` asks for the outlined variant.
  factory material() => _Visual(
    surface: (theme) => theme.colors.bgContainer,
    radius: (theme) => PureRadii.md,
    shadow: (theme) => theme.card.shadow,
  );

  /// iOS's inset-grouped plate: the grouped background band clipped at the
  /// 10pt corner its section answers with, flat on the page, no shadow, no
  /// stroke. iOS separates by inset and surface tone, never by an outline.
  factory cupertino() => _Visual(surface: (theme) => theme.colors.bgContainer, radius: (theme) => _iosSectionRadius);

  /// macOS's settings group box: a flat panel under the single hairline rule
  /// the group box draws at its edge, 8pt corner, no elevation — window
  /// chrome separates by rule, not shadow.
  factory macos() => _Visual(
    surface: (theme) => theme.colors.bgContainer,
    radius: (theme) => PureRadii.sm,
    hairline: (theme) => theme.card.borderColor,
  );

  /// Windows Fluent's CardBackground: the container surface at the 8pt card
  /// corner with the CardBorder hairline, and the soft, wide cast a WinUI card
  /// drops straight down onto the page.
  factory fluent() => _Visual(
    surface: (theme) => theme.colors.bgContainer,
    radius: (theme) => PureRadii.sm,
    hairline: (theme) => theme.card.borderColor,
    shadow: (theme) => [
      BoxShadow(color: theme.colors.shadowBase.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
    ],
  );

  /// Ubuntu Yaru's flat card: the rounder 16pt container, one hairline, and no
  /// elevation anywhere — the distribution frames surfaces with rules.
  factory yaru() => _Visual(
    surface: (theme) => theme.colors.bgContainer,
    radius: (theme) => PureRadii.lg,
    hairline: (theme) => theme.card.borderColor,
  );

  /// shadcn's bordered card (the forui grammar): the container sheet ruled by
  /// the full-strength distribution border at the 12pt corner, flat.
  factory forui() => _Visual(
    surface: (theme) => theme.colors.bgContainer,
    radius: (theme) => PureRadii.md,
    hairline: (theme) => theme.colors.border,
  );

  /// The glass language's frosted card: a lit white sheet (the dark theme's
  /// faint glint, the light theme's bright plate) over a real backdrop blur,
  /// the lit edge rule, and the glow a frosted layer casts; solidifies to the
  /// plain container whenever the device or policy refuses transparency.
  factory glass() => _Visual(
    surface: (theme) => theme.canBlur ? _tint(theme, 0.12, 0.55) : theme.colors.bgContainer,
    radius: (theme) => PureRadii.lg,
    hairline: (theme) => theme.canBlur ? _tint(theme, 0.2, 0.75) : theme.card.borderColor,
    shadow: (theme) => [
      BoxShadow(
        color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.4 : 0.12),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
    frost: 18,
    hoverTint: (theme) => _glint(theme, 0.06),
    pressedTint: (theme) => _glint(theme, 0.1),
  );

  /// The neumorphic mould: the page's own container tone pressed up out of
  /// itself at the 24pt corner — the twin cast and glow shadows are the whole
  /// identity, so there is no stroke to select with, only the tinted fill.
  factory neumorphic() => _Visual(
    surface: (theme) => theme.colors.bgContainer,
    radius: (theme) => PureRadii.xl,
    shadow: (theme) => [
      BoxShadow(
        color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.35 : 0.18),
        blurRadius: 10,
        offset: const Offset(4, 4),
      ),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.05 : 0.8),
        blurRadius: 10,
        offset: const Offset(-4, -4),
      ),
    ],
    strokesSelection: false,
  );

  /// The wind (tailwind) card: the crisp 1px distribution border around a flat
  /// sheet at the small 8pt corner — structure over elevation.
  factory wind() => _Visual(
    surface: (theme) => theme.colors.bgContainer,
    radius: (theme) => PureRadii.sm,
    hairline: (theme) => theme.colors.border,
  );

  /// The plate fill the language paints before any tint or selection.
  final Color Function(PureTheme theme) surface;

  /// The corner radius, in logical pixels, whatever the language makes of the
  /// card token.
  final double Function(PureTheme theme) radius;

  /// The hairline the grammar rules its edge with; null is the languages that
  /// ship a strokeless plate until `bordered` asks for one.
  final Color? Function(PureTheme theme)? hairline;

  /// The shadows the plate casts into the page.
  final List<BoxShadow> Function(PureTheme theme) shadow;

  /// The tint blended over the surface while a pointer rests on it.
  final Color Function(PureTheme theme) hoverTint;

  /// The tint blended over the surface while it is held down.
  final Color Function(PureTheme theme) pressedTint;

  /// The backdrop blur sigma the frosted grammars run, 0 for the solid ones —
  /// and even then only when [PureTheme.canBlur] lets the plate stay
  /// translucent at all.
  final double frost;

  /// Whether a selected card marks itself with the primary stroke as well as
  /// the tinted fill; the soft-surface grammar answers in the fill alone.
  final bool strokesSelection;

  static List<BoxShadow> _flat(PureTheme theme) => const [];

  static Color _fillTint(PureTheme theme) => theme.colors.fill;

  static Color _fillSecondaryTint(PureTheme theme) => theme.colors.fillSecondary;

  /// The glass languages' neutral tint: the lit face over dark themes, the
  /// bright sheet over light ones, scaled by the transparency policy.
  static Color _tint(PureTheme theme, double darkAlpha, double lightAlpha) {
    final alpha = ((theme.isDark ? darkAlpha : lightAlpha) * theme.config.effectiveTransparency).clamp(0.0, 1.0);
    return theme.colors.white.withValues(alpha: alpha);
  }

  /// A hover/press glint for the frosted plate: light on dark, shade on light.
  static Color _glint(PureTheme theme, double alpha) =>
      theme.isDark ? theme.colors.white.withValues(alpha: alpha) : Colors.black.withValues(alpha: alpha);
}

/// The card's one surface: it paints the resolved plate, and — when the card
/// is tappable — carries the interaction state that tints it, the static
/// foreground ring that names focus, and the semantics that announce it.
class _CardSurface extends StatefulWidget {
  const new({
    required this.theme,
    required this.visual,
    required this.inset,
    required this.interactive,
    required this.selected,
    required this.outlined,
    required this.overrides,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
  });

  final PureTheme theme;

  final _Visual visual;

  final EdgeInsetsGeometry inset;

  final bool interactive;

  final bool selected;

  final bool outlined;

  /// The caller's inline [Style]; only its plate properties (fill, stroke,
  /// corner) answer here — typography belongs to the content.
  final Style? overrides;

  final Widget child;

  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  final FocusNode? focusNode;

  final bool autofocus;

  @override
  State<_CardSurface> createState() => _CardSurfaceState();
}

class _CardSurfaceState extends State<_CardSurface> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  /// The card's own traversal node, made on first use when the caller did not
  /// name one; an externally owned node is never disposed here.
  FocusNode? _fallbackNode;

  FocusNode get _node => widget.focusNode ?? (_fallbackNode ??= FocusNode(debugLabel: 'PureCard'));

  @override
  void dispose() {
    _fallbackNode?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (widget.onTap == null) {
      return KeyEventResult.ignored;
    }
    final activate = {
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    };
    if (activate.contains(event.logicalKey)) {
      widget.onTap!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final visual = widget.visual;
    final style = widget.overrides;
    final radii = style?.borderRadius ?? BorderRadius.circular(visual.radius(theme));

    // The plate: the language's surface, the selection tint over it, the
    // hover/pressed glint over that; then the stroke the grammar (or the
    // caller) asks for, and the shadows it casts.
    var fill = style?.background ?? (widget.selected ? theme.colors.primaryBg : visual.surface(theme));
    if (_pressed) {
      fill = Color.alphaBlend(visual.pressedTint(theme), fill);
    } else if (_hovered && widget.interactive) {
      fill = Color.alphaBlend(visual.hoverTint(theme), fill);
    }
    final stroke =
        style?.borderColor ??
        (widget.selected && visual.strokesSelection
            ? theme.colors.primaryBorder
            : visual.hairline?.call(theme) ?? (widget.outlined ? theme.colors.border : null));
    final plate = BoxDecoration(
      color: fill,
      borderRadius: radii,
      border: stroke == null
          ? null
          : Border.all(color: stroke, width: style?.borderWidth ?? theme.token.motion.lineWidth),
      boxShadow: style?.shadow ?? visual.shadow(theme),
    );

    Widget body = Padding(padding: widget.inset, child: widget.child);
    if (visual.frost > 0 && theme.canBlur) {
      body = ClipRRect(
        borderRadius: radii,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: visual.frost, sigmaY: visual.frost),
          child: body,
        ),
      );
    }
    Widget card = DecoratedBox(key: const Key('PureCard.plate'), decoration: plate, child: body);
    if (!widget.interactive) {
      return card;
    }

    // The focus ring rides a static foreground DecoratedBox that is always in
    // the tree; until the card holds focus its stroke is simply transparent,
    // so focusing neither tweens a decoration nor changes the shape below.
    final ringOn = _focused && theme.config.focusOutline;
    card = DecoratedBox(
      key: const Key('PureCard.ring'),
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radii,
        border: Border.all(
          color: ringOn ? theme.colors.primary : const Color(0x00000000),
          width: theme.token.motion.lineWidthFocus,
        ),
      ),
      child: card,
    );
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) {
            _node.requestFocus();
            setState(() => _pressed = true);
          },
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Semantics(button: true, selected: widget.selected, child: card),
        ),
      ),
    );
  }
}

/// The corner the macOS settings chip rounds its selection to. Absolute like
/// the iOS section's: the System Settings list owns this number, not the
/// radius ladder.
const double _macosRowChipRadius = 6;

/// The width of the WinUI selection marker — the pill a ListViewItem slides
/// in at its left edge. 3px is the toolkit's own resting marker width.
const double _fluentMarkerWidth = 3;

/// The marker's height when the row holds the selection; WinUI rests at 16px
/// and grows toward 38 on hover — the row answers the pointer in its fill,
/// so the marker keeps the one height.
const double _fluentMarkerHeight = 16;

/// The width of wind's left accent bar — the `border-l-2` a tailwind list
/// marks its active row with.
const double _windAccentBarWidth = 2;

/// A selectable list row. [build] resolves one [_RowVisual] from the theme and
/// paints the row itself — the borrowed tiles are gone: Flutter's `ListTile`
/// and `CupertinoListTile`, `MacosListTile`, Fluent's `FluentListItem`,
/// ForUI's `FTile`, glass's `GlassListTile`. What the user sees is drawn from
/// the theme's own tokens, one grammar per [PureDesignLanguage]: Material's
/// two-line list item (56/72pt tiers, a secondary-container fill and a
/// primary label when selected, the separator inset to the text), the iOS
/// inset-grouped row (44pt, grey pressed and selected fills, the separator
/// inset past the leading, and — when the row opens something and the caller
/// named no trailing — a disclosure chevron), macOS's settings row (a hairline-
/// ruled accent chip inset from the pane edge), WinUI's ListViewItem (a 4pt
/// neutral chip, a semibold title and the 3pt selection marker pill that
/// slides in at the row's left edge), Ubuntu's flat row under a rounded
/// primary-tinted chip, shadcn/forui's full-bleed row (muted secondary when
/// selected, a medium label, rules across the whole sheet), the glass
/// language's lit row (a translucent glint hover, a frosted lit fill and lit
/// hairline edges when chosen, solidifying with the theme's transparency
/// policy), the neumorphic inset groove (the twin shadows reversed — the row
/// sinks into the plate, depth and no stroke), and wind's crisp row (a 2px
/// primary accent bar down a tinted sheet). Colours, gaps and rules come only
/// from `theme.colors.*`, the list-tile token and the radius scale, so a
/// language re-skin and a dark switch still come out right.
///
/// A row with callbacks answers the uniform interaction contract — the same
/// one [_CardSurface] keeps: hover and pressed tints blended into the row, a
/// focus ring painted through a static foreground [DecoratedBox] (never a
/// tweened `foregroundDecoration`, never a tree that changes on focus),
/// Enter/Space/select-key activation, and button + selected semantics. A row
/// without callbacks is inert rather than greyed: it takes no focus, draws no
/// ring and keeps its labels readable — the family's standing contract.
/// [divided] draws the language's own hairline under the row, inset wherever
/// the grammar insets it. [leading]/[trailing] sit in their slots untouched;
/// the row places the family gap around them and never restyles them.
class PureListRow extends StatelessWidget {
  /// A list row.
  const new({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.divided = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The primary text.
  final String title;

  /// A secondary line of text.
  final String? subtitle;

  /// A leading widget (icon, avatar, thumbnail).
  final Widget? leading;

  /// A trailing widget (chevron, switch, badge).
  final Widget? trailing;

  /// The tap handler; null renders the row non-interactive.
  final VoidCallback? onTap;

  /// A long-press handler.
  final VoidCallback? onLongPress;

  /// Whether the row shows the selected state.
  final bool selected;

  /// Whether to paint a divider under the row.
  final bool divided;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = _resolveRowVisual(theme);
    return KeyedSubtree(
      // The grammar this row is drawing, addressable in tests and diagnostics.
      key: ValueKey('PureListRow.${theme.config.language.name}'),
      child: _RowSurface(
        theme: theme,
        visual: visual,
        interactive: onTap != null || onLongPress != null,
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        selected: selected,
        divided: divided,
        onTap: onTap,
        onLongPress: onLongPress,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
    );
  }

  /// The nine row grammars, one per design language.
  static _RowVisual _resolveRowVisual(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.material => _RowVisual.material(),
    PureDesignLanguage.cupertino => _RowVisual.cupertino(),
    PureDesignLanguage.macos => _RowVisual.macos(),
    PureDesignLanguage.fluent => _RowVisual.fluent(),
    PureDesignLanguage.glass => _RowVisual.glass(),
    PureDesignLanguage.neumorphic => _RowVisual.neumorphic(),
    PureDesignLanguage.wind => _RowVisual.wind(),
    PureDesignLanguage.forui => _RowVisual.forui(),
    PureDesignLanguage.yaru => _RowVisual.yaru(),
  };
}

/// How one design languages rows a list: the tier heights it answers with,
/// the fills and strokes selection paints, the marker the grammar slides in
/// at the row's edge, the interaction tints, and the separator under it.
@immutable
final class _RowVisual {
  const new({
    required this.oneLineHeight,
    required this.twoLineHeight,
    this.hpad = _pagePad,
    this.marker,
    this.disclosure = false,
    this.radius = 0,
    this.edgeInset = 0,
    Color Function(PureTheme theme)? selectedFill,
    Border Function(PureTheme theme)? selectedBorder,
    this.selectedShadow,
    this.selectedTitleColor,
    this.selectedTitleWeight,
    Color Function(PureTheme theme)? hoverTint,
    Color Function(PureTheme theme)? pressedTint,
    Color Function(PureTheme theme)? dividerColor,
    this.dividerInset = 0,
  }) : selectedFill = selectedFill ?? _selectionFill,
       selectedBorder = selectedBorder ?? _noStroke,
       hoverTint = hoverTint ?? _Visual._fillTint,
       pressedTint = pressedTint ?? _Visual._fillSecondaryTint,
       dividerColor = dividerColor ?? _divider;

  /// Android Material's two-line list item: 56pt over one line, 72 over two,
  /// the state layers are the fill roles, and selection turns the item's
  /// surface to the secondary container with the label in the primary — M3
  /// marks a list choice in fill and colour, never a stroke. The separator
  /// insets to the text column, as the M3 list rules its items.
  factory material() => _RowVisual(
    oneLineHeight: 56,
    twoLineHeight: 72,
    selectedTitleColor: (theme) => theme.colors.primary,
    dividerInset: 16,
  );

  /// The iOS inset-grouped row: a 44pt cell in the section plate, pressed and
  /// selected alike in the grey fill iOS knows (selection is the row's own,
  /// not an accent), the separator inset 16pt to line up with the title, and
  /// the disclosure chevron this grammar adds itself when the row opens
  /// something and the caller named no trailing. iOS separates by the inset
  /// rule and the greyed fill, and by nothing else.
  factory cupertino() => const _RowVisual(oneLineHeight: 44, twoLineHeight: 62, disclosure: true, dividerInset: 16);

  /// macOS's settings row: the 40pt line answers the pointer with a fill,
  /// and selection lifts the row into a chip — the 6pt System Settings
  /// corner, inset 8pt from the pane edges and ruled with the primary
  /// hairline over the tinted fill. The rule is the chrome; window surfaces
  /// mark a choice by outlining it.
  factory macos() => _RowVisual(
    oneLineHeight: 40,
    twoLineHeight: 56,
    radius: _macosRowChipRadius,
    edgeInset: 8,
    selectedBorder: (theme) => Border.all(color: theme.colors.primaryBorder, width: theme.token.motion.lineWidth),
  );

  /// Windows Fluent's ListViewItem: the 40pt row on a 4pt neutral chip inset
  /// from the list edge, hover one grey and press the next — a plain WinUI
  /// list marks its current item in the neutral layer with a semibold title,
  /// never an accent fill — and the accent belongs to the marker: the 3x16pt
  /// primary pill that slides up from zero height at the row's left edge when
  /// the row is chosen.
  factory fluent() => _RowVisual(
    oneLineHeight: 40,
    twoLineHeight: 56,
    radius: PureRadii.xs,
    edgeInset: 4,
    hpad: (theme) => 12,
    selectedFill: (theme) => theme.colors.fillSecondary,
    selectedTitleWeight: FontWeight.w600,
    marker: (theme, {required selected}) => AnimatedContainer(
      key: const ValueKey('PureListRow.marker'),
      duration: theme.duration,
      curve: Curves.easeOut,
      width: _fluentMarkerWidth,
      height: selected ? _fluentMarkerHeight : 0,
      decoration: BoxDecoration(color: theme.colors.primary, borderRadius: BorderRadius.circular(PureRadii.pill)),
    ),
  );

  /// Ubuntu Yaru's row: the flat 44pt line under the rounded 8pt, 6pt-inset
  /// chip of a GNOME list, filled with the primary tint and never ruled —
  /// Yaru marks a choice in the accent wash, the hairline belongs to the
  /// card around it. The separator runs full-bleed between the rows.
  factory yaru() =>
      _RowVisual(oneLineHeight: 44, twoLineHeight: 60, radius: PureRadii.sm, edgeInset: 6, hpad: (theme) => 10);

  /// shadcn's list row (the forui grammar): the full-bleed 48pt item, hover
  /// the faint accent, selection the muted secondary surface under a
  /// medium-weight label — `bg-accent`/`font-medium`, the sheet's own
  /// component style — and separators ruled across the whole width, because
  /// a shadcn list divides edge to edge.
  factory forui() => _RowVisual(
    oneLineHeight: 48,
    twoLineHeight: 64,
    selectedFill: (theme) => theme.colors.fillSecondary,
    selectedTitleWeight: FontWeight.w500,
  );

  /// The glass language's row: the line carries no fill of its own — it sits
  /// on a frosted plate and answers in light. A glint on hover, a
  /// translucent lit fill and lit hairlines above and below when selected,
  /// and the separator a lit thread instead of grey. When the device or the
  /// policy refuses transparency the row solidifies to the token's selected
  /// tint and border, like the card plate it rides in.
  factory glass() => _RowVisual(
    oneLineHeight: 48,
    twoLineHeight: 64,
    hoverTint: (theme) => _Visual._glint(theme, 0.06),
    pressedTint: (theme) => _Visual._glint(theme, 0.1),
    selectedFill: (theme) => theme.canBlur ? _Visual._tint(theme, 0.18, 0.5) : theme.colors.primaryBg,
    selectedBorder: (theme) => theme.canBlur
        ? Border.symmetric(
            horizontal: BorderSide(color: _Visual._tint(theme, 0.28, 0.75), width: theme.token.motion.lineWidth),
          )
        : Border.all(color: theme.colors.primaryBorder, width: theme.token.motion.lineWidth),
    dividerColor: (theme) => theme.canBlur ? _Visual._tint(theme, 0.1, 0.6) : theme.listTile.dividerColor,
  );

  /// The neumorphic groove: the row pressed into the plate it stands on.
  /// Selection answers in depth and nowhere else — the twin cast and glow
  /// shadows reversed (light bottom-right, shade top-left, the same trick
  /// the tab bar's pressed-in pill plays), the fill the plate's own tone, no
  /// stroke the soft surface could hold.
  factory neumorphic() => _RowVisual(
    oneLineHeight: 44,
    twoLineHeight: 64,
    radius: PureRadii.sm,
    edgeInset: 6,
    hpad: (theme) => 12,
    selectedFill: (theme) => theme.colors.bgContainer,
    selectedShadow: (theme) => [
      BoxShadow(
        color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.35 : 0.18),
        blurRadius: 8,
        offset: const Offset(-4, -4),
      ),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.05 : 0.8),
        blurRadius: 8,
        offset: const Offset(4, 4),
      ),
    ],
  );

  /// The wind (tailwind) row: the crisp 48pt sheet item, hairline-divided,
  /// and the active row marked the way a tailwind list marks it — a 2px
  /// primary bar down its left edge over the primary-tinted wash. The edge
  /// rule is a stroke of one side, so it rides the decoration at radius 0,
  /// where Flutter's border-and-corner mix would refuse it.
  factory wind() => _RowVisual(
    oneLineHeight: 48,
    twoLineHeight: 64,
    selectedBorder: (theme) => Border(
      left: BorderSide(color: theme.colors.primary, width: _windAccentBarWidth),
    ),
  );

  /// The row's content height over one line of text; the tier the grammar
  /// answers with, absolute like the platform's own.
  final double oneLineHeight;

  /// ... and over two. Text larger than the tier grows the row, never
  /// clips it: the number is a floor.
  final double twoLineHeight;

  /// The padding inside the row's surface, before the slots.
  final double Function(PureTheme theme) hpad;

  /// The widget the grammar slides in at the row's left edge — Fluent's
  /// marker pill; null is every language that marks its choice without one.
  /// It is always in the tree when the language ships it, sized to nothing
  /// until the row is chosen.
  final Widget Function(PureTheme theme, {required bool selected})? marker;

  /// Whether a tappable row with no trailing draws this grammar's own
  /// disclosure chevron — the iOS habit the platform's tiles ship with.
  final bool disclosure;

  /// The corner of the row's own surface, 0 for the full-bleed grammars.
  final double radius;

  /// The gap between the row's surface and the list's edge — the inset a
  /// chip grammar floats in.
  final double edgeInset;

  /// The fill selection paints under the row's content.
  final Color Function(PureTheme theme) selectedFill;

  /// The stroke selection rules the row with; a one-sided edge rule is legal
  /// at [radius] 0, and every grammar that rounds keeps a uniform stroke.
  final Border? Function(PureTheme theme) selectedBorder;

  /// The shadows the selected row sinks or lifts with; the groove's answer.
  final List<BoxShadow>? Function(PureTheme theme)? selectedShadow;

  /// The label colour a selected row wears, null where the grammar keeps
  /// the plain text role.
  final Color? Function(PureTheme theme)? selectedTitleColor;

  /// The label weight a selected row wears — the plain-list answer Fluent and
  /// shadcn give instead of an accent fill.
  final FontWeight? selectedTitleWeight;

  /// The tint blended over the row while a pointer rests on it.
  final Color Function(PureTheme theme) hoverTint;

  /// The tint blended over the row while it is held down.
  final Color Function(PureTheme theme) pressedTint;

  /// The separator's colour.
  final Color Function(PureTheme theme) dividerColor;

  /// The separator's inset from the list's left edge.
  final double dividerInset;

  static double _pagePad(PureTheme theme) => theme.listTile.paddingHorizontal;

  static Color _selectionFill(PureTheme theme) => theme.listTile.selectedBackground;

  static Color _divider(PureTheme theme) => theme.listTile.dividerColor;

  static Border? _noStroke(PureTheme theme) => null;
}

/// The row's one surface: it lays the slots out in the shared order, paints
/// the resolved grammar's selection and tints, and — when the row is
/// interactive — carries the hover/pressed state, the static foreground ring
/// that names focus, the activation keys and the semantics that announce it.
class _RowSurface extends StatefulWidget {
  const new({
    required this.theme,
    required this.visual,
    required this.interactive,
    required this.title,
    required this.selected,
    required this.divided,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
  });

  final PureTheme theme;

  final _RowVisual visual;

  /// Whether the row responds to input; false sheds the ring, the tints and
  /// the traversal, exactly as the plain card does.
  final bool interactive;

  final String title;

  final String? subtitle;

  final Widget? leading;

  final Widget? trailing;

  final bool selected;

  final bool divided;

  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  final FocusNode? focusNode;

  final bool autofocus;

  @override
  State<_RowSurface> createState() => _RowSurfaceState();
}

class _RowSurfaceState extends State<_RowSurface> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  /// The row's own traversal node, made on first use when the caller did not
  /// name one; an externally owned node is never disposed here.
  FocusNode? _fallbackNode;

  FocusNode get _node => widget.focusNode ?? (_fallbackNode ??= FocusNode(debugLabel: 'PureListRow'));

  @override
  void dispose() {
    _fallbackNode?.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (widget.onTap == null) {
      return KeyEventResult.ignored;
    }
    final activate = {
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    };
    if (activate.contains(event.logicalKey)) {
      widget.onTap!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final visual = widget.visual;
    final subtitle = widget.subtitle;
    final gap = theme.listTile.gap;

    // The row's fill: the grammar's selection under the hover/pressed tint,
    // each blended over whatever the row carries — a transparent base is the
    // tint alone, which is how the full-bleed grammars wash.
    var fill = widget.selected ? visual.selectedFill(theme) : null;
    if (_pressed) {
      fill = Color.alphaBlend(visual.pressedTint(theme), fill ?? const Color(0x00000000));
    } else if (_hovered && widget.interactive) {
      fill = Color.alphaBlend(visual.hoverTint(theme), fill ?? const Color(0x00000000));
    }
    final stroke = widget.selected ? visual.selectedBorder(theme) : null;
    final plate = BoxDecoration(
      color: fill,
      borderRadius: visual.radius > 0 ? BorderRadius.circular(visual.radius) : null,
      border: stroke,
      boxShadow: widget.selected ? visual.selectedShadow?.call(theme) : null,
    );

    final titleStyle = _rowTitle(theme).copyWith(
      color: widget.selected ? visual.selectedTitleColor?.call(theme) ?? theme.colors.text : theme.colors.text,
      fontWeight: widget.selected ? visual.selectedTitleWeight : null,
    );
    final trailing = widget.trailing;
    final showChevron = visual.disclosure && widget.interactive && trailing == null;
    final marker = visual.marker?.call(theme, selected: widget.selected);
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: visual.hpad(theme)),
      child: Row(
        children: [
          if (marker case final edge?) ...[edge, const SizedBox(width: 8)],
          if (widget.leading case final icon?) ...[icon, SizedBox(width: gap)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                if (subtitle case final line?)
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _rowSubtitle(theme).copyWith(color: theme.colors.textSecondary),
                  ),
              ],
            ),
          ),
          if (trailing case final end?) ...[SizedBox(width: gap), end],
          if (showChevron) ...[
            SizedBox(width: gap),
            // The iOS disclosure caret — this grammar's own affordance, not a
            // slot the caller filled.
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colors.textTertiary,
              key: const ValueKey('PureListRow.disclosure'),
            ),
          ],
        ],
      ),
    );

    Widget row = DecoratedBox(
      key: const Key('PureListRow.plate'),
      decoration: plate,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: subtitle == null ? visual.oneLineHeight : visual.twoLineHeight),
        child: Align(alignment: AlignmentDirectional.centerStart, child: content),
      ),
    );
    if (visual.edgeInset > 0) {
      row = Padding(
        padding: EdgeInsets.symmetric(horizontal: visual.edgeInset),
        child: row,
      );
    }
    if (widget.interactive) {
      // The focus ring rides a static foreground DecoratedBox that is always
      // in the tree; until the row holds focus its stroke is simply
      // transparent, so focusing neither tweens a decoration nor changes the
      // shape below. Its corner follows the chip the ring wraps.
      final ringOn = _focused && theme.config.focusOutline;
      row = DecoratedBox(
        key: const Key('PureListRow.ring'),
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(visual.radius + visual.edgeInset),
          border: Border.all(
            color: ringOn ? theme.colors.primary : const Color(0x00000000),
            width: theme.token.motion.lineWidthFocus,
          ),
        ),
        child: row,
      );
    }
    var stack = row;
    if (widget.divided) {
      stack = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          Container(
            key: const ValueKey('PureListRow.divider'),
            height: theme.token.motion.lineWidth,
            margin: EdgeInsets.only(left: visual.dividerInset),
            color: visual.dividerColor(theme),
          ),
        ],
      );
    }
    if (!widget.interactive) {
      return stack;
    }
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: (_) {
            _node.requestFocus();
            setState(() => _pressed = true);
          },
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Semantics(button: true, selected: widget.selected, child: stack),
        ),
      ),
    );
  }
}

/// The type a row's title wears: the theme's body role.
///
/// The roles deliberately carry no colour — only family, size, weight and line
/// height — because [_RowSurface] paints the colour from the grammar's own
/// state table (selected, secondary, the plain text role). Without this a row's
/// label is whatever the host library's own tile style decides, and the family
/// the viewer picked in the appearance settings never reaches it.
TextStyle _rowTitle(PureTheme theme) => theme.text.body;

/// The type a row's subtitle wears; smaller and lighter than [_rowTitle], and
/// still colour-free for the same reason.
TextStyle _rowSubtitle(PureTheme theme) => theme.text.bodySmall;
