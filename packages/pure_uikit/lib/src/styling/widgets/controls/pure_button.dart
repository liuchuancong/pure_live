import 'package:flutter/gestures.dart' show PointerEnterEvent, PointerExitEvent, TapDownDetails, TapUpDetails;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/recipe.dart';
import 'package:pure_uikit/src/styling/style/style.dart';
import 'package:pure_uikit/src/styling/widgets/controls/pure_progress.dart';

/// The corner treatment a [PureButton]'s plate can take: the base token
/// radius, a full pill, or square corners.
///
/// The name and the three values mirror the retired `fluent_2` enum one to
/// one, so the `fluentShape` parameter keeps its public type and every
/// existing call site keeps naming the corner it always did — the file
/// itself no longer reaches into that package.
enum FluentButtonShape {
  /// The token's base radius. The default.
  rounded,

  /// Fully rounded ends — a pill.
  circular,

  /// Square corners.
  square,
}

/// A button in the token model: one widget, the Fluent theme and every density.
///
/// It carries only semantics (`variant`, `size`, `loading`, `expand`, the focus
/// fields); its appearance is painted here, from `PureTheme`'s own tokens, in
/// the WinUI grammar — a filled accent plate for the primary, the bordered
/// standard plate for the secondary, the quiet hover fill for the ghost and a
/// filled destructive for the danger. Nothing is delegated to a platform widget
/// library, and the tokens answer for the rest: a dark switch, the user's
/// motion setting and the accent they pick all come out of the same tokens, so
/// the control never has to be re-tuned.
///
/// One interaction contract holds, the way the switch and the tab bar hold
/// theirs: hover and pressed tints on the plate, a disabled button that greys
/// and swallows every tap and key, a focus ring drawn on the accent for
/// keyboards and remotes, Enter and Space firing [onPressed], and a
/// screen-reader node that names the action. `loading` is not a fifth state but
/// the same inert face wearing the kit's own ring ([PureSpinner]) beside the
/// label.
///
/// ## Platform-only knobs
///
/// A parameter named after the language (`fluentShape`) and its doc starts with
/// "`<Language>` only:". Under fluent it sets the plate's corner treatment
/// (rounded, pill, or square).
class PureButton extends StatelessWidget {
  /// A button labelled [label].
  const new({
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.size = ControlSize.md,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
    this.tooltip,
    this.style,
    this.fluentShape,
    super.key,
  });

  /// The button text. An empty label with an [icon] draws the glyph alone.
  final String label;

  /// The callback; null disables the button.
  final VoidCallback? onPressed;

  /// An optional leading icon.
  final IconData? icon;

  /// The semantic kind — primary, secondary, danger or ghost.
  final ButtonVariant variant;

  /// The size step: sm, md or lg.
  final ControlSize size;

  /// Whether the kit's ring rides beside the label and input is rejected.
  final bool loading;

  /// Whether the button fills its parent's width.
  final bool expand;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Hover/long-press hint; also the accessible name when there is no label.
  final String? tooltip;

  /// An inline style override (the `style=` attribute), merged over the resolved
  /// grammar: it wins on the corner radius, the plate fill, the label colour and
  /// the outline it names, and leaves the rest to the language.
  final Style? style;

  /// Fluent only: the corner treatment, mapped onto the plate's radius
  /// (rounded → the token's base, circular → a pill, square → none).
  final FluentButtonShape? fluentShape;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = _Visual.fluent(theme, fluentShape);
    final m = _metrics(theme, size);
    final iconOnly = icon != null && label.isEmpty;
    return _ButtonCore(
      // The branch a button draws is its identity in tests and diagnostics.
      key: ValueKey('PureButton.${theme.config.language.name}'),
      visual: visual,
      metrics: m,
      variant: variant,
      icon: icon,
      label: label,
      onPressed: onPressed,
      loading: loading,
      expand: expand,
      iconOnly: iconOnly,
      selected: false,
      tooltip: tooltip,
      autofocus: autofocus,
      focusNode: focusNode,
      style: style,
    );
  }
}

/// A square icon-only button — the Ant `Button` icon variant. It always carries
/// a [tooltip] (an icon alone is not a readable label) and takes the same
/// `variant` / `size` semantics as [PureButton].
///
/// Its square is the same height tier the text button uses, so an icon button
/// sits flush with the label button it belongs to; `selected` is the toggle
/// grammar (an accent plate carrying a contrasting glyph) the kit's other
/// controls answer to.
class PureIconButton extends StatelessWidget {
  /// An icon button.
  const new({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.variant = ButtonVariant.ghost,
    this.size = ControlSize.md,
    this.selected = false,
    this.enabled = true,
    this.color,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  /// The glyph to draw.
  final IconData icon;

  /// The tooltip and accessibility label.
  final String tooltip;

  /// The callback; null (or `enabled: false`) disables the button.
  final VoidCallback? onPressed;

  /// The semantic kind.
  final ButtonVariant variant;

  /// The size step; drives the square's side length.
  final ControlSize size;

  /// Whether the control shows a mode that is currently on.
  final bool selected;

  /// Whether the button accepts input.
  final bool enabled;

  /// An explicit glyph colour. A control that carries meaning by colour (a
  /// favourite in the error red, a glyph over a picture in white) needs the
  /// override; null keeps the language's own foreground.
  final Color? color;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    // An icon button has no label, so `enabled: false` and a null callback are
    // the same verdict: fold them once and hand the core one live flag.
    final live = enabled && onPressed != null;
    // A selected toggle is the accent plate with its own foreground, whichever
    // quiet variant the button rests at otherwise.
    final effective = selected ? ButtonVariant.primary : variant;
    final visual = _Visual.fluent(theme, null);
    final m = _metrics(theme, size);
    // A chosen glyph colour is an override the core drops onto a quiet
    // (transparent-plate) variant; a filled or selected plate keeps its own
    // contrasting foreground so the mark never disappears into the accent.
    const resting = _BtnState(enabled: true, hovered: false, pressed: false);
    return _ButtonCore(
      key: ValueKey('PureIconButton.${theme.config.language.name}'),
      visual: visual,
      metrics: m,
      variant: effective,
      icon: icon,
      label: '',
      // A disabled icon button hands the core a null callback so it greys and
      // swallows input the same way a text button does.
      onPressed: live ? onPressed : null,
      loading: false,
      expand: false,
      iconOnly: true,
      selected: selected,
      tooltip: tooltip,
      autofocus: autofocus,
      focusNode: focusNode,
      style: null,
      glyphColor: visual.plate(effective, resting) == null ? color : null,
    );
  }
}

/// The visual grammar the button plate draws: the fill and outline in each
/// interaction state, the label colour, the corner treatment and the opacity a
/// disabled button sinks to. Everything is resolved from the theme when the
/// button builds, so a dark switch and the accent the viewer picked all come
/// out of the same tokens the kit's other controls read.
@immutable
final class _Visual {
  const new({
    required this.radius,
    required this.plate,
    required this.content,
    required this.border,
    required this.borderWidth,
    required this.disabledAlpha,
  });

  /// WinUI: a filled accent plate for the primary, a light bordered standard
  /// plate for the secondary, a quiet hover fill for the ghost and a filled
  /// destructive for the danger. [shape] picks the corner (rounded / pill /
  /// square).
  factory fluent(PureTheme theme, FluentButtonShape? shape) {
    final c = theme.colors;
    final radius = switch (shape ?? FluentButtonShape.rounded) {
      FluentButtonShape.rounded => BorderRadius.circular(theme.token.scale.radii.base),
      FluentButtonShape.circular => BorderRadius.circular(PureRadii.pill),
      FluentButtonShape.square => BorderRadius.zero,
    };
    return _Visual(
      radius: radius,
      plate: (v, s) => switch (v) {
        ButtonVariant.primary => _accent(s, base: c.primary, hover: c.primaryHover, active: c.primaryActive),
        ButtonVariant.danger => _accent(s, base: c.error, hover: c.errorHover, active: c.errorActive),
        ButtonVariant.secondary =>
          s.pressed
              ? c.fill
              : s.hovered
              ? c.fillTertiary
              : c.bgContainer,
        ButtonVariant.ghost =>
          s.pressed
              ? c.fill
              : s.hovered
              ? c.fillTertiary
              : null,
      },
      content: (v, s) => switch (v) {
        ButtonVariant.primary || ButtonVariant.danger => theme.button.onPrimary,
        ButtonVariant.secondary || ButtonVariant.ghost => c.text,
      },
      border: (v, s) => v == ButtonVariant.secondary && s.enabled ? c.border : null,
      borderWidth: theme.token.motion.lineWidth,
      disabledAlpha: theme.token.motion.opacityLoading,
    );
  }

  /// The corner radius of the plate (and of the focus ring drawn over it).
  final BorderRadius radius;

  /// The plate's fill in this interaction state; null is transparent.
  final Color? Function(ButtonVariant v, _BtnState s) plate;

  /// The label and glyph colour.
  final Color Function(ButtonVariant v, _BtnState s) content;

  /// The plate's outline colour, or null for none (a uniform single-colour border,
  /// so it may carry the radius).
  final Color? Function(ButtonVariant v, _BtnState s) border;

  /// The outline width.
  final double borderWidth;

  /// The opacity of a disabled button.
  final double disabledAlpha;
}

/// The accent plate's hover and pressed answer: the base at rest, [hover] under
/// a pointer, [active] while pressed. The caller names all three, so the same
/// helper serves both the primary and destructive fills.
Color _accent(_BtnState s, {required Color base, required Color hover, required Color active}) {
  if (s.pressed) {
    return active;
  }
  if (s.hovered) {
    return hover;
  }
  return base;
}

/// The interaction state a plate is resolved against. `enabled` is "not a
/// disabled button" (a loading button is still `enabled` — it only rejects
/// input); `hovered` and `pressed` are gated to the live control by the core.
@immutable
final class _BtnState {
  const new({required this.enabled, required this.hovered, required this.pressed});

  final bool enabled;
  final bool hovered;
  final bool pressed;
}

/// The button's body: the plate and its content, the shared interaction contract
/// (hover, pressed, focus, disabled), the kit's focus ring drawn over a static
/// foreground layer, the semantics that name the action, and the tooltip.
class _ButtonCore extends StatefulWidget {
  const new({
    required this.visual,
    required this.metrics,
    required this.variant,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.loading,
    required this.expand,
    required this.iconOnly,
    required this.selected,
    required this.tooltip,
    required this.autofocus,
    required this.focusNode,
    required this.style,
    this.glyphColor,
    super.key,
  });

  final _Visual visual;
  final _ButtonMetrics metrics;
  final ButtonVariant variant;
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final bool iconOnly;
  final bool selected;
  final String? tooltip;
  final bool autofocus;
  final FocusNode? focusNode;
  final Style? style;

  /// An explicit glyph colour for a meaning-by-colour icon button; null keeps
  /// the language's own foreground.
  final Color? glyphColor;

  @override
  State<_ButtonCore> createState() => _ButtonCoreState();
}

class _ButtonCoreState extends State<_ButtonCore> {
  late final FocusNode _node;
  bool _ownsNode = false;
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode(debugLabel: 'PureButton');
    _ownsNode = widget.focusNode == null;
  }

  @override
  void dispose() {
    if (_ownsNode) {
      _node.dispose();
    }
    super.dispose();
  }

  /// Whether the button reacts to input at all: a live callback, and not busy
  /// with its own loading ring.
  bool get _live => widget.onPressed != null && !widget.loading;

  /// Whether the button is disabled (as opposed to merely loading): a null
  /// callback and no ring running.
  bool get _dimmed => widget.onPressed == null;

  void _activate() {
    if (_live) {
      widget.onPressed?.call();
    }
  }

  void _handleTapDown(TapDownDetails event) {
    _node.requestFocus();
    setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails event) => setState(() => _pressed = false);

  void _handleTapCancel() => setState(() => _pressed = false);

  void _handleEnter(PointerEnterEvent event) => setState(() => _hovered = true);

  void _handleExit(PointerExitEvent event) => setState(() => _hovered = false);

  void _handleFocusChange(bool focused) => setState(() => _focused = focused);

  /// Space and Enter fire the button, the same activation keys the kit's other
  /// controls answer to; anything else is left to the shell.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final activate = {
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    };
    if (!activate.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    _activate();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = widget.visual;
    final m = widget.metrics;
    final live = _live;
    final state = _BtnState(enabled: !_dimmed, hovered: _hovered && live, pressed: _pressed && live);
    final fg = widget.glyphColor ?? visual.content(widget.variant, state);

    final inline = widget.style;
    final plate = visual.plate(widget.variant, state);
    final outline = visual.border(widget.variant, state);
    final radius = inline?.borderRadius ?? visual.radius;
    final decoration = BoxDecoration(
      color: inline?.background ?? plate,
      borderRadius: radius,
      border: outline != null ? Border.all(color: outline, width: visual.borderWidth) : null,
    );

    // The plate itself: the animated background (fill, outline) with the content
    // riding in it.
    final surface = AnimatedContainer(
      duration: theme.duration,
      curve: Curves.easeOut,
      decoration: decoration,
      // A Container that names an alignment grows to fill whatever it is given,
      // which would widen a hugging text button to the slot; the alignment is
      // only wanted where the box is deliberately sized — filling (expand) or a
      // square icon plate that must centre its glyph.
      alignment: widget.expand || widget.iconOnly ? AlignmentDirectional.center : null,
      width: widget.iconOnly ? null : (widget.expand ? double.infinity : null),
      // An icon button is a square its own tier is the side of; a text button
      // hugs its label and only takes the full width when asked to expand. The
      // square is set through the constraints, not a `width`/`height` pair, so a
      // tight slot cannot flatten it to the parent's width.
      constraints: widget.iconOnly
          ? BoxConstraints.tightFor(width: m.height, height: m.height)
          : BoxConstraints(minHeight: m.height),
      padding: widget.iconOnly ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: m.padH),
      child: _content(theme, fg, m),
    );

    // The kit's focus ring goes through a STATIC foreground [DecoratedBox], not
    // the container's `foregroundDecoration`: an [AnimatedContainer] tweens that,
    // and lerping the ring in would pass through a border state the shape will not
    // accept. The box is always wrapped (an empty decoration when unfocused) so
    // gaining focus never changes the widget-tree shape out from under a press.
    final ringed = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: _focused && live
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: 2)),
            )
          : const BoxDecoration(),
      child: surface,
    );

    // The disabled sink: the animated layer. Loading is never sunk — it wears
    // the ring instead.
    final disabled = _dimmed && !widget.loading;
    final sunk = AnimatedOpacity(duration: theme.duration, opacity: disabled ? visual.disabledAlpha : 1, child: ringed);

    final semanticName = widget.label.isNotEmpty ? widget.label : widget.tooltip;
    final labelled = Semantics(
      container: true,
      button: true,
      enabled: !_dimmed,
      label: semanticName,
      child: ExcludeSemantics(child: sunk),
    );
    final tappable = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: live ? _activate : null,
      onTapDown: live ? _handleTapDown : null,
      onTapUp: live ? _handleTapUp : null,
      onTapCancel: live ? _handleTapCancel : null,
      child: labelled,
    );
    final hoverable = MouseRegion(
      cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _handleEnter,
      onExit: _handleExit,
      child: tappable,
    );
    final focusable = Focus(
      focusNode: _node,
      debugLabel: 'PureButton',
      canRequestFocus: live,
      autofocus: widget.autofocus && live,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKey,
      child: hoverable,
    );

    return widget.tooltip == null ? focusable : Tooltip(message: widget.tooltip, child: focusable);
  }

  /// Label and optional leading glyph, or the kit's ring while loading. The glyph
  /// colour travels through [IconTheme.merge] (the one channel an icon reads) so
  /// a disabled face reaches the glyph too; the label takes the same colour
  /// through its own style.
  Widget _content(PureTheme theme, Color fg, _ButtonMetrics m) {
    final labelStyle = theme.text.label.copyWith(fontSize: m.fontSize, fontWeight: FontWeight.w500, color: fg);
    Widget body;
    if (widget.loading) {
      final ring = PureSpinner(size: m.fontSize, color: fg);
      body = widget.iconOnly
          ? ring
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ring,
                const SizedBox(width: 6),
                Flexible(
                  child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
                ),
              ],
            );
    } else if (widget.iconOnly) {
      body = Icon(widget.icon);
    } else if (widget.icon == null) {
      body = Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle);
    } else {
      body = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: m.icon),
          SizedBox(width: m.size == ControlSize.sm ? 4 : 6),
          Flexible(
            child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
          ),
        ],
      );
    }
    return IconTheme.merge(
      data: IconThemeData(color: fg, size: m.icon),
      child: body,
    );
  }
}

/// The three size steps read out of the resolved theme: the control height, the
/// label size, the horizontal padding and the glyph size. Geometry comes from the
/// tokens, so a sm / md / lg button is never flattened to one tier.
@immutable
final class _ButtonMetrics {
  const new({required this.size, required this.height, required this.fontSize, required this.padH, required this.icon});

  final ControlSize size;
  final double height;
  final double fontSize;
  final double padH;
  final double icon;
}

/// The token's three steps, read from the resolved theme's button, type and scale
/// tokens. The label size rides the theme's already-scaled role, so a re-skin and
/// the user's text-size setting both carry through.
_ButtonMetrics _metrics(PureTheme theme, ControlSize size) {
  final b = theme.button;
  final type = theme.token.type;
  final label = theme.text.label.fontSize ?? type.fontSize;
  return switch (size) {
    ControlSize.sm => _ButtonMetrics(
      size: size,
      height: b.controlHeightSM,
      fontSize: label - 1,
      padH: b.paddingInline * 0.66,
      icon: 14,
    ),
    ControlSize.md => _ButtonMetrics(
      size: size,
      height: b.controlHeight,
      fontSize: label,
      padH: b.paddingInline,
      icon: 16,
    ),
    ControlSize.lg => _ButtonMetrics(
      size: size,
      height: b.controlHeightLG,
      fontSize: label + 2,
      padH: b.paddingInline * 1.33,
      icon: 18,
    ),
  };
}

/// A standalone circular spinner — `PureProgress`'s ring asked for by name.
///
/// The kit already paints the unknown-work ring in `pure_progress.dart`, so this
/// is the shape callers reach for when they want the ring without the bar's
/// vocabulary; a `null` value is what the shape answers to for a spinner.
class PureSpinner extends StatelessWidget {
  /// A spinner.
  const new({this.size = 18, this.color, super.key});

  /// The diameter.
  final double size;

  /// An optional colour override.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? PureTheme.of(context).colors.primary;
    return PureProgress(value: null, shape: PureProgressShape.circular, size: size, barColor: tint);
  }
}
