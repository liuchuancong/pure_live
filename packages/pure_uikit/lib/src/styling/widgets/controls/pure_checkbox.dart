import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The design sheet's checkbox: one small square of agreement, drawn in the
/// WinUI grammar. Where the tab bar slides a pill, this ticks — the WinUI box
/// with its flat-cut, right-leaning checkmark on the rounded 3px square, the
/// full hairline around the empty box and the accent fill when checked. All of
/// it is painted here from the tokens, so a dark switch and an accent change
/// still come out right.
///
/// Every visual answers to the same interaction contract: hover and pressed
/// tints, a disabled box (a null `onChanged` or `enabled: false`) that greys
/// out and answers nothing, the kit's focus ring with Space (and Enter, and
/// the remote's select keys) choosing while the box holds focus,
/// `checked`/`enabled` screen-reader traits on every box, and a tick that
/// scales and fades in on the token's fast motion. The value type is a plain
/// `bool` — the contract carries no mixed state.
class PureCheckbox extends StatelessWidget {
  /// A checkbox bound to [value].
  const new({
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Whether the box is checked.
  final bool value;

  /// Called with the next value; null (or `enabled: false`) disables it.
  final ValueChanged<bool>? onChanged;

  /// An optional trailing label.
  final String? label;

  /// Whether the box responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final select = onChanged;
    return _CheckboxBox(
      visual: _BoxVisual.fluent(),
      value: value,
      live: enabled && select != null,
      // The next state of a box is its own opposite; a box with nothing to
      // call never speaks, and the control guards the rest.
      toggle: () => select?.call(!value),
      label: label,
      // The label rides the body role: a checkbox sits in running text, not
      // in a button's tight line.
      labelStyle: theme.text.body.copyWith(color: theme.colors.text),
      gap: theme.token.scale.sizes.sm,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }
}

/// How the box is painted: its edge and corner, the two states' surfaces, the
/// tick's own geometry, the motion's ink and the dim a disabled box falls to.
/// Every value is a function of the resolved theme, so a dark switch or an
/// accent change re-skins the branch without a rebuild of it.
@immutable
final class _BoxVisual {
  const new({
    required this.boxSize,
    required this.radius,
    required this.face,
    required this.tick,
    required this.tickCap,
    required this.tickWeight,
    required this.tickColor,
    required this.disabledAlpha,
  });

  /// Windows Fluent's WinUI checkbox: the rounded 3px square (the corner is
  /// the identity, a flat absolute like the tab bar's ink strip), a full
  /// hairline around the empty box, the accent fill when checked, and the
  /// WinUI checkmark — a short lead-in that bottoms out low, a long exit
  /// stroke that leaves high, both cut flat rather than rounded.
  factory fluent() {
    const corner = BorderRadius.all(Radius.circular(3));
    BorderRadius rounded(PureTheme theme) => corner;
    return _BoxVisual(
      boxSize: (theme) => theme.checkbox.boxSize,
      radius: rounded,
      face: (theme, {required checked, required hovered, required pressed, required live}) {
        if (checked) {
          final fill = pressed
              ? theme.colors.primaryActive
              : hovered
              ? theme.colors.primaryHover
              : theme.colors.primary;
          return BoxDecoration(
            color: fill,
            borderRadius: corner,
            border: Border.all(color: fill),
          );
        }
        return BoxDecoration(
          color: pressed
              ? theme.colors.fill
              : hovered
              ? theme.colors.bgElevated
              : theme.colors.bgContainer,
          borderRadius: corner,
          // WinUI lifts only the border's grey under the pointer; the square
          // itself never takes a fill while it is empty.
          border: Border.all(
            color: pressed
                ? theme.colors.text
                : hovered
                ? theme.colors.textSecondary
                : theme.colors.border,
          ),
        );
      },
      tick: _check(0.17, 0.55, 0.35, 0.74, 0.85, 0.24),
      tickCap: StrokeCap.butt,
      tickWeight: 0.11,
      tickColor: onAccent,
      disabledAlpha: (theme) => theme.checkbox.disabledOpacity,
    );
  }

  /// The box's edge length in the theme.
  final double Function(PureTheme theme) boxSize;

  /// The box's corner.
  final BorderRadius Function(PureTheme theme) radius;

  /// The box's whole surface for one state: fill, border — composed out of
  /// the tokens.
  final Decoration Function(
    PureTheme theme, {
    required bool checked,
    required bool hovered,
    required bool pressed,
    required bool live,
  })
  face;

  /// The checkmark's path across the box.
  final Path Function(Size box) tick;

  /// How the checkmark's ends are cut — flat, in the WinUI hand.
  final StrokeCap tickCap;

  /// The checkmark's stroke as a fraction of the box's edge.
  final double tickWeight;

  /// The checkmark's colour.
  final Color Function(PureTheme theme) tickColor;

  /// The opacity a disabled box (and its label) falls to.
  final double Function(PureTheme theme) disabledAlpha;

  /// The tick colour the filled box shares: the text solid on the accent.
  static Color onAccent(PureTheme theme) => theme.colors.textLightSolid;

  /// A three-point check across the unit box, scaled into the box the painter
  /// hands it.
  static Path Function(Size box) _check(double x1, double y1, double x2, double y2, double x3, double y3) {
    return (box) => Path()
      ..moveTo(box.width * x1, box.height * y1)
      ..lineTo(box.width * x2, box.height * y2)
      ..lineTo(box.width * x3, box.height * y3);
  }
}

/// The box and its label, and the interaction contract: hover and pressed
/// states, the kit's focus ring, Space (and Enter, and the remote's select
/// keys) toggling, the disabled look, the `checked`/`enabled` screen-reader
/// traits, and the tick's scale-and-fade.
class _CheckboxBox extends StatefulWidget {
  const new({
    required this.visual,
    required this.value,
    required this.live,
    required this.toggle,
    required this.label,
    required this.labelStyle,
    required this.gap,
    required this.autofocus,
    this.focusNode,
  });

  final _BoxVisual visual;

  final bool value;

  /// Whether the box responds to anything; a false folds `enabled` and the
  /// null callback into one verdict, the way the tab bar's bar does.
  final bool live;

  final VoidCallback toggle;

  final String? label;

  final TextStyle labelStyle;

  final double gap;

  /// An externally managed focus node; one is owned here when it is null.
  final FocusNode? focusNode;

  final bool autofocus;

  @override
  State<_CheckboxBox> createState() => _CheckboxBoxState();
}

class _CheckboxBoxState extends State<_CheckboxBox> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;
  FocusNode? _ownedNode;

  /// The node the focus sits on: the caller's when they brought one, an
  /// owned one otherwise.
  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode(debugLabel: 'PureCheckbox'));

  @override
  void dispose() {
    // Externally managed nodes are left for their owner; the box releases
    // only what it made.
    _ownedNode?.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // The same activate set the tab bar answers — Space for keyboards, Enter
    // and the select keys for the remote.
    final activate = {
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    };
    if (!activate.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (widget.live) {
      widget.toggle();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = widget.visual;
    final live = widget.live;
    final box = visual.boxSize(theme);
    final radius = visual.radius(theme);

    final face = AnimatedContainer(
      duration: theme.duration,
      curve: Curves.easeOut,
      width: box,
      height: box,
      alignment: AlignmentDirectional.center,
      decoration: visual.face(theme, checked: widget.value, hovered: _hovered, pressed: _pressed, live: live),
      foregroundDecoration: _focused ? _focusRing(theme, radius) : null,
      child: _tick(theme, visual, box),
    );

    final label = widget.label;
    final row = label == null
        ? face
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              face,
              SizedBox(width: widget.gap),
              // The label yields to a tight parent rather than overflowing it.
              Flexible(child: Text(label, style: widget.labelStyle)),
            ],
          );

    final widgetWithSemantics = Semantics(
      checked: widget.value,
      enabled: live,
      label: label,
      // The screen reader's own toggle, beside the tap gesture's.
      onTap: live ? widget.toggle : null,
      child: AnimatedOpacity(
        duration: theme.duration,
        curve: Curves.easeOut,
        opacity: live ? 1 : visual.disabledAlpha(theme),
        // One semantics node for the whole box: the label rides the traits
        // above rather than as its own text node.
        child: ExcludeSemantics(child: row),
      ),
    );

    final interactive = Focus(
      focusNode: _node,
      canRequestFocus: live,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) => _handleKey(event),
      child: MouseRegion(
        cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: live
              ? (_) {
                  _node.requestFocus();
                  setState(() => _pressed = true);
                }
              : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: live ? widget.toggle : null,
          child: widgetWithSemantics,
        ),
      ),
    );
    if (live) {
      return interactive;
    }
    return IgnorePointer(child: interactive);
  }

  /// The kit's focus ring: a 2px accent border over the box, the same answer
  /// the tab bar's cells give.
  static BoxDecoration _focusRing(PureTheme theme, BorderRadius radius) => BoxDecoration(
    borderRadius: radius,
    border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: 2)),
  );

  /// The checkmark itself: scaled and faded in on the token's fast motion —
  /// around 100ms — and excluded from semantics because the box above already
  /// says `checked`.
  Widget _tick(PureTheme theme, _BoxVisual visual, double box) {
    final size = Size.square(box);
    return ExcludeSemantics(
      child: AnimatedScale(
        scale: widget.value ? 1 : 0.4,
        duration: theme.token.motion.durationFast,
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: widget.value ? 1 : 0,
          duration: theme.token.motion.durationFast,
          curve: Curves.easeOut,
          child: CustomPaint(
            painter: _TickPainter(
              path: visual.tick(size),
              color: visual.tickColor(theme),
              stroke: visual.tickWeight * box,
              cap: visual.tickCap,
            ),
            size: size,
          ),
        ),
      ),
    );
  }
}

/// The stroked checkmark, painted inside the box.
final class _TickPainter extends CustomPainter {
  new({required this.path, required this.color, required this.stroke, required this.cap});

  final Path path;

  final Color color;

  final double stroke;

  final StrokeCap cap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = cap
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color || oldDelegate.stroke != stroke || oldDelegate.cap != cap;
}
