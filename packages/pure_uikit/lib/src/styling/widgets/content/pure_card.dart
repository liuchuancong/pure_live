import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart';

/// The public card: one plate, drawn here, over Flutter's own layout engine.
///
/// Every library frame the card used to borrow — Material's `Card` + `InkWell`,
/// the iOS inset-grouped section, `MacosSheet`, `FluentCard`, `FCard`,
/// `GlassCard`, `NeuCard`, `WCard` — is gone. What the user sees is the WinUI
/// CardBackground: the container surface at the 8pt card corner with the
/// CardBorder hairline and the soft, wide cast a WinUI card drops straight down
/// onto the page. Colours, radii and shadows come only from `theme.colors.*`,
/// the card component token and the radius scale, so a dark switch still comes
/// out right, and the config's `language` names the card's identity key only —
/// a non-fluent value keeps compiling and simply draws this plate.
///
/// Where the card is tappable ([onTap] or [onLongPress] set) it answers the
/// uniform interaction contract: hover and pressed tints blended into the
/// plate, a focus ring painted through a static foreground [DecoratedBox]
/// (never a tweened `foregroundDecoration`, never a tree that changes on
/// focus — the ring box is always there, its stroke simply transparent until
/// the card holds focus), Enter/Space/select key activation for keyboards and
/// remotes, and button + selected semantics. A plain card takes no focus and
/// draws no ring — the old contract, kept. [selected] tints the surface to
/// the primary background and rules it with the primary border;
/// [bordered] draws the plain hairline; [dense]
/// tightens the inner padding by the same 0.66 step the family has always
/// taken; [padding] replaces it outright; [style] overrides the plate's fill,
/// stroke and corner.
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
      // The config's language is the card's identity key in tests and
      // diagnostics only; the drawing itself is fluent.
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

  /// The card grammar — the fluent plate.
  static _Visual _resolveVisual(PureTheme theme) => _Visual.fluent();
}

/// How the card is plated: the surface, the corner, the hairline
/// and shadow that set it off the page, and the interaction tints a tappable
/// card blends over the surface.
@immutable
final class _Visual {
  const new({
    required this.surface,
    required this.radius,
    this.hairline,
    List<BoxShadow> Function(PureTheme theme)? shadow,
    Color Function(PureTheme theme)? hoverTint,
    Color Function(PureTheme theme)? pressedTint,
  }) : shadow = shadow ?? _flat,
       hoverTint = hoverTint ?? _fillTint,
       pressedTint = pressedTint ?? _fillSecondaryTint;

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

  /// The plate fill painted before any tint or selection.
  final Color Function(PureTheme theme) surface;

  /// The corner radius, in logical pixels, whatever the card token makes of it.
  final double Function(PureTheme theme) radius;

  /// The hairline the plate rules its edge with; null ships a strokeless plate
  /// until `bordered` asks for one.
  final Color? Function(PureTheme theme)? hairline;

  /// The shadows the plate casts into the page.
  final List<BoxShadow> Function(PureTheme theme) shadow;

  /// The tint blended over the surface while a pointer rests on it.
  final Color Function(PureTheme theme) hoverTint;

  /// The tint blended over the surface while it is held down.
  final Color Function(PureTheme theme) pressedTint;

  static List<BoxShadow> _flat(PureTheme theme) => const [];

  static Color _fillTint(PureTheme theme) => theme.colors.fill;

  static Color _fillSecondaryTint(PureTheme theme) => theme.colors.fillSecondary;
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

    // The plate: the resolved surface, the selection tint over it, the
    // hover/pressed glint over that; then the stroke the plate (or the
    // caller) asks for, and the shadows it casts.
    var fill = style?.background ?? (widget.selected ? theme.colors.primaryBg : visual.surface(theme));
    if (_pressed) {
      fill = Color.alphaBlend(visual.pressedTint(theme), fill);
    } else if (_hovered && widget.interactive) {
      fill = Color.alphaBlend(visual.hoverTint(theme), fill);
    }
    final stroke =
        style?.borderColor ??
        (widget.selected
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

    final body = Padding(padding: widget.inset, child: widget.child);
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

/// The width of the WinUI selection marker — the pill a ListViewItem slides
/// in at its left edge. 3px is the toolkit's own resting marker width.
const double _fluentMarkerWidth = 3;

/// The marker's height when the row holds the selection; WinUI rests at 16px
/// and grows toward 38 on hover — the row answers the pointer in its fill,
/// so the marker keeps the one height.
const double _fluentMarkerHeight = 16;

/// A selectable list row. [build] resolves one [_RowVisual] from the theme and
/// paints the row itself — the borrowed tiles are gone: Flutter's `ListTile`
/// and `CupertinoListTile`, `MacosListTile`, Fluent's `FluentListItem`,
/// ForUI's `FTile`, glass's `GlassListTile`. What the user sees is drawn from
/// the theme's own tokens: WinUI's ListViewItem — the 40pt row on a 4pt neutral
/// chip inset from the list edge, hover one grey and press the next, a
/// semibold title when selected and the 3pt selection marker pill that slides
/// in at the row's left edge. Colours, gaps and rules come only
/// from `theme.colors.*`, the list-tile token and the radius scale, so a dark
/// switch still comes out right, and the config's `language` names the row's
/// identity key only — a non-fluent value keeps compiling and simply draws
/// this row.
///
/// A row with callbacks answers the uniform interaction contract — the same
/// one [_CardSurface] keeps: hover and pressed tints blended into the row, a
/// focus ring painted through a static foreground [DecoratedBox] (never a
/// tweened `foregroundDecoration`, never a tree that changes on focus),
/// Enter/Space/select-key activation, and button + selected semantics. A row
/// without callbacks is inert rather than greyed: it takes no focus, draws no
/// ring and keeps its labels readable — the family's standing contract.
/// [divided] draws the hairline under the row, inset to the text column.
/// [leading]/[trailing] sit in their slots untouched;
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
      // The config's language is the row's identity key in tests and
      // diagnostics only; the drawing itself is fluent.
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

  /// The row grammar — the fluent ListViewItem.
  static _RowVisual _resolveRowVisual(PureTheme theme) => _RowVisual.fluent();
}

/// How the row is painted: the tier heights it answers with,
/// the fills and strokes selection paints, the marker that slides in
/// at the row's edge, the interaction tints, and the separator under it.
@immutable
final class _RowVisual {
  const new({
    required this.oneLineHeight,
    required this.twoLineHeight,
    this.hpad = _pagePad,
    this.marker,
    this.radius = 0,
    this.edgeInset = 0,
    Color Function(PureTheme theme)? selectedFill,
    Border Function(PureTheme theme)? selectedBorder,
    this.selectedTitleWeight,
    Color Function(PureTheme theme)? hoverTint,
    Color Function(PureTheme theme)? pressedTint,
    Color Function(PureTheme theme)? dividerColor,
  }) : selectedFill = selectedFill ?? _selectionFill,
       selectedBorder = selectedBorder ?? _noStroke,
       hoverTint = hoverTint ?? _Visual._fillTint,
       pressedTint = pressedTint ?? _Visual._fillSecondaryTint,
       dividerColor = dividerColor ?? _divider;

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

  /// The row's content height over one line of text; the tier the grammar
  /// answers with, absolute like the platform's own.
  final double oneLineHeight;

  /// ... and over two. Text larger than the tier grows the row, never
  /// clips it: the number is a floor.
  final double twoLineHeight;

  /// The padding inside the row's surface, before the slots.
  final double Function(PureTheme theme) hpad;

  /// The widget that slides in at the row's left edge — the Fluent
  /// marker pill. It is always in the tree, sized to nothing
  /// until the row is chosen.
  final Widget Function(PureTheme theme, {required bool selected})? marker;

  /// The corner of the row's own surface, 0 for the full-bleed row.
  final double radius;

  /// The gap between the row's surface and the list's edge — the inset a
  /// chip row floats in.
  final double edgeInset;

  /// The fill selection paints under the row's content.
  final Color Function(PureTheme theme) selectedFill;

  /// The stroke selection rules the row with; a one-sided edge rule is legal
  /// at [radius] 0, and a row that rounds keeps a uniform stroke.
  final Border? Function(PureTheme theme) selectedBorder;

  /// The label weight a selected row wears — the plain-list answer Fluent
  /// gives instead of an accent fill.
  final FontWeight? selectedTitleWeight;

  /// The tint blended over the row while a pointer rests on it.
  final Color Function(PureTheme theme) hoverTint;

  /// The tint blended over the row while it is held down.
  final Color Function(PureTheme theme) pressedTint;

  /// The separator's colour.
  final Color Function(PureTheme theme) dividerColor;

  static double _pagePad(PureTheme theme) => theme.listTile.paddingHorizontal;

  static Color _selectionFill(PureTheme theme) => theme.listTile.selectedBackground;

  static Color _divider(PureTheme theme) => theme.listTile.dividerColor;

  static Border? _noStroke(PureTheme theme) => null;
}

/// The row's one surface: it lays the slots out in the shared order, paints
/// the resolved visual's selection and tints, and — when the row is
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

    // The row's fill: the visual's selection under the hover/pressed tint,
    // each blended over whatever the row carries — a transparent base is the
    // tint alone.
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
    );

    final titleStyle = _rowTitle(theme)
        .copyWith(color: theme.colors.text, fontWeight: widget.selected ? visual.selectedTitleWeight : null);
    final trailing = widget.trailing;
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
/// height — because [_RowSurface] paints the colour from the row's own
/// state table (selected, secondary, the plain text role). Without this a row's
/// label is whatever the host library's own tile style decides, and the family
/// the app settled on never reaches it.
TextStyle _rowTitle(PureTheme theme) => theme.text.body;

/// The type a row's subtitle wears; smaller and lighter than [_rowTitle], and
/// still colour-free for the same reason.
TextStyle _rowSubtitle(PureTheme theme) => theme.text.bodySmall;
