import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The design sheet's slider: one track that carries a value, drawn in the
/// WinUI grammar — a thin outlined track with the accent run behind the knob
/// and a large circular knob with its own border in front; the hover answer
/// the language is known for is the knob swelling from its rest size to its
/// larger one, and the track keeps one thickness. All of it is painted here,
/// because a value that answers to a keyboard, a screen reader and the whole
/// sheet at once is exactly what the libraries refuse to share; the colours,
/// radii, motion and text come from the tokens, so a dark switch still comes
/// out right.
///
/// Every visual answers to the same interaction contract: the whole track is
/// one hit target, so a pointer drags from anywhere on it and a tap moves the
/// value to where it landed; hover and drag swell the handle; the kit's focus
/// ring circles the handle while it holds focus; Left and Right (and Down and
/// Up) move one step, Home and End run to the bounds; `slider` semantics
/// carrying the value, the two neighbours and the two actions name the control
/// to a screen reader; the handle animates its size back down when the drag
/// lets go; and a null `onChanged` (or `enabled: false`) fades the whole
/// control to its disabled alpha and swallows pointer and keyboard alike.
class PureSlider extends StatelessWidget {
  /// A slider carrying [value] between [min] and [max].
  const new({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.onChangeStart,
    this.onChangeEnd,
    super.key,
  }) : assert(divisions == null || divisions > 0, 'A slider divides its range at least once.');

  /// The current value.
  final double value;

  /// Called with each new value; null (or `enabled: false`) disables the
  /// slider, fades it and swallows every pointer and key.
  final ValueChanged<double>? onChanged;

  /// The lower bound.
  final double min;

  /// The upper bound.
  final double max;

  /// How many equal steps the range is cut into. A stepped slider snaps its
  /// value to those notches. Null leaves the value continuous.
  final int? divisions;

  /// Whether the slider responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// The name a screen reader reads beside the value; the value itself is
  /// always read.
  final String? semanticLabel;

  /// Called when a pointer lands on the track — the moment a caller that
  /// shows the value in its own chrome should start listening.
  final VoidCallback? onChangeStart;

  /// Called when the pointer lets go.
  final VoidCallback? onChangeEnd;

  /// One step of the keyboard's arithmetic: a notch of [divisions] where the
  /// value has them, and a twentieth of the range on a continuous track. The
  /// twentieth is the kit's own answer to the question the libraries leave
  /// implicit — a slider with no notches still has to move by something.
  double get _step {
    final span = max - min;
    final divisions = this.divisions;
    if (divisions != null && span.isFinite) {
      return span / divisions;
    }
    return span / _continuousDivisions;
  }

  static const int _continuousDivisions = 20;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    final span = max - min;
    // A value outside its own bounds still draws inside the rail, and a rail
    // whose bounds collapsed keeps its handle at the near end rather than
    // dividing by nothing.
    final clamped = span > 0 ? value.clamp(min, max) : min;
    final fraction = span > 0 ? ((clamped - min) / span).clamp(0.0, 1.0) : 0.0;
    return _SliderCore(
      // The branch a slider draws is its identity in tests and diagnostics.
      key: ValueKey('PureSlider.${language.name}'),
      visual: _SliderVisual.fluent(theme),
      value: clamped,
      fraction: fraction,
      min: min,
      max: max,
      step: _step,
      divisions: divisions,
      // A null callback is the inert state, so folding `enabled` into it once
      // gives the core a single verdict.
      report: enabled ? onChanged : null,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel,
    );
  }
}

/// The geometry, colours and motion the rail, its runs of
/// colour and its handle are drawn with. Everything is resolved from the theme
/// when the slider builds, so a dark switch and the user's motion settings all
/// come out of the same tokens the kit's other controls read.
@immutable
final class _SliderVisual {
  const new({
    required this.height,
    required this.trackHeight,
    required this.activeHeight,
    required this.radius,
    required this.trackOutline,
    required this.outlineWidth,
    required this.inactiveColor,
    required this.activeColor,
    required this.handleSize,
    required this.handleGrown,
    required this.handleRadius,
    required this.handleColor,
    required this.handleOutline,
    required this.handleOutlineWidth,
    required this.disabledAlpha,
    required this.curve,
  });

  /// WinUI: a thin outlined track with the accent run behind the knob and a
  /// large circular knob with its own border in front; the hover answer the
  /// language is known for is the knob swelling from its rest size to its
  /// larger one, and the track keeps one thickness.
  factory fluent(PureTheme theme) {
    final base = theme.slider;
    return _SliderVisual(
      // The swollen knob needs the room, and the ring around it more still.
      height: theme.token.scale.controlHeight,
      trackHeight: base.railHeight,
      activeHeight: base.railHeight,
      radius: BorderRadius.circular(PureRadii.xs),
      trackOutline: theme.colors.borderSecondary,
      outlineWidth: theme.token.motion.lineWidth,
      inactiveColor: theme.colors.fillSecondary,
      activeColor: base.trackColor,
      handleSize: theme.token.scale.controlHeightXS + PureRadii.xs,
      handleGrown: PureRadii.xs,
      handleRadius: PureRadii.pill,
      handleColor: base.handleColor,
      handleOutline: theme.colors.border,
      handleOutlineWidth: theme.token.motion.lineWidth * 2,
      disabledAlpha: base.disabledOpacity,
      curve: Curves.easeOutCubic,
    );
  }

  /// The control's own height: the box the rail is centred in.
  final double height;

  /// The rail's thickness — the track's inactive, unpassed part.
  final double trackHeight;

  /// The passed part's thickness; the WinUI track keeps it level with the rail.
  final double activeHeight;

  /// The rail's corner.
  final BorderRadius radius;

  /// The hairline around the rail.
  final Color? trackOutline;

  /// The rail's outline width.
  final double outlineWidth;

  /// The colour of the track ahead of the handle.
  final Color inactiveColor;

  /// The colour of the track the value has run over.
  final Color activeColor;

  /// The handle's edge at rest.
  final double handleSize;

  /// How much the handle swells under the pointer; the WinUI knob answers a
  /// hover with a value.
  final double handleGrown;

  /// The handle's corner; [PureRadii.pill] reads as the circle.
  final double handleRadius;

  /// The handle's fill.
  final Color handleColor;

  /// The handle's border colour; null draws no border.
  final Color? handleOutline;

  /// The handle's border width.
  final double handleOutlineWidth;

  /// The opacity of a disabled slider.
  final double disabledAlpha;

  /// The curve the handle slides and swells on, and the fill and tints fade
  /// along.
  final Curve curve;

  /// The room the handle takes at its largest: the box it rides stays this size
  /// so a swell keeps the knob centred on the value instead of sliding it off.
  double get handleSlot => handleSize + handleGrown;

  /// The handle's decoration at one interaction state, with the kit's focus
  /// ring folded into the shadows so it swells with the handle it names.
  BoxDecoration handleDecoration({required Color? ringColor, required double ringWidth}) {
    final outline = handleOutline;
    final circle = handleRadius * 2 >= handleSize + handleGrown;
    final ring = ringColor == null || ringWidth <= 0 ? null : BoxShadow(color: ringColor, spreadRadius: ringWidth);
    return BoxDecoration(
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(handleRadius),
      color: handleColor,
      border: outline == null || handleOutlineWidth <= 0 ? null : Border.all(color: outline, width: handleOutlineWidth),
      boxShadow: [?ring],
    );
  }
}

/// The slider's body: the rail, its two runs of colour and
/// the handle that rides the value, under one interaction contract — the whole
/// track hit-tested for a drag, a tap that moves the value to where it landed,
/// the kit's focus ring, the step keys and Home and End, and the `slider`
/// semantics.
class _SliderCore extends StatefulWidget {
  const new({
    required this.visual,
    required this.value,
    required this.fraction,
    required this.min,
    required this.max,
    required this.step,
    required this.divisions,
    required this.report,
    required this.onChangeStart,
    required this.onChangeEnd,
    required this.focusNode,
    required this.autofocus,
    required this.semanticLabel,
    super.key,
  });

  final _SliderVisual visual;

  /// The value clamped into the range — what the handle rides and what a screen
  /// reader hears.
  final double value;

  /// That value normalised onto the 0..1 rail.
  final double fraction;

  final double min;

  final double max;

  /// One keyboard step, in the range's own units.
  final double step;

  /// The number of notches, or null for a continuous track.
  final int? divisions;

  /// The live callback; null is the disabled verdict the public widget has
  /// already folded `enabled` into.
  final ValueChanged<double>? report;

  final VoidCallback? onChangeStart;

  final VoidCallback? onChangeEnd;

  final FocusNode? focusNode;

  final bool autofocus;

  final String? semanticLabel;

  @override
  State<_SliderCore> createState() => _SliderCoreState();
}

class _SliderCoreState extends State<_SliderCore> {
  bool _hovered = false;
  bool _dragging = false;
  bool _focused = false;

  bool get _live => widget.report != null;

  /// Whether the handle is answering a pointer: the swell hangs off this one
  /// verdict.
  bool get _engaged => _live && (_dragging || _hovered);

  /// The value a fraction of the rail stands for, snapped to the notches a
  /// stepped slider has and clamped into the range it belongs to.
  double _valueAt(double fraction) => _quantise(widget.min + fraction * (widget.max - widget.min));

  double _quantise(double raw) {
    final min = widget.min;
    final max = widget.max;
    final divisions = widget.divisions;
    final notch = divisions == null ? 0 : (max - min) / divisions;
    if (notch <= 0) {
      return raw.clamp(min, max);
    }
    return (min + ((raw - min) / notch).roundToDouble() * notch).clamp(min, max);
  }

  void _begin(FocusNode node) {
    if (!_live || _dragging) {
      return;
    }
    node.requestFocus();
    setState(() => _dragging = true);
    widget.onChangeStart?.call();
  }

  void _end() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.onChangeEnd?.call();
  }

  /// The keyboard's one step: Left and Down run the value down, Right and Up
  /// run it up, Home and End jump to the bounds. Whatever else the shell has in
  /// mind for a key is left to the shell.
  void _stepBy(int direction) {
    widget.report?.call(_quantise(widget.value + direction * widget.step));
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_live) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowUp) {
      _stepBy(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowDown) {
      _stepBy(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      widget.report!(widget.min);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      widget.report!(widget.max);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = widget.visual;
    final live = _live;
    final centre = visual.height / 2;
    // The rail stops short of the widest the handle ever gets, so a knob that
    // swells under the pointer never overhangs the track it rides.
    final inset = visual.handleSlot / 2;
    final handleExtent = visual.handleSize + (_engaged ? visual.handleGrown : 0);

    return SizedBox(
      height: visual.height,
      width: double.infinity,
      child: Focus(
        focusNode: widget.focusNode,
        debugLabel: 'PureSlider',
        canRequestFocus: live,
        autofocus: widget.autofocus && live,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _handleKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final node = Focus.of(context);
            final travel = (constraints.maxWidth - inset * 2).clamp(0.0, double.infinity);
            // A pointer's position read back as a fraction of the rail: the
            // whole track answers, which is the hit-test half of the contract.
            double fractionAt(Offset global) {
              if (travel <= 0) {
                return 0;
              }
              final box = context.findRenderObject();
              final local = box is RenderBox ? global - box.localToGlobal(Offset.zero) : global;
              return ((local.dx - inset) / travel).clamp(0.0, 1.0);
            }

            void reportAt(Offset global) {
              widget.report?.call(_valueAt(fractionAt(global)));
            }

            final centreX = inset + widget.fraction * travel;

            return MouseRegion(
              cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: live ? (_) => _begin(node) : null,
                // A tap puts the value where the finger landed.
                onTapUp: live
                    ? (details) {
                        reportAt(details.globalPosition);
                        _end();
                      }
                    : null,
                onTapCancel: live ? _end : null,
                onHorizontalDragStart: live
                    ? (details) {
                        _begin(node);
                        reportAt(details.globalPosition);
                      }
                    : null,
                onHorizontalDragUpdate: live ? (details) => reportAt(details.globalPosition) : null,
                onHorizontalDragEnd: live ? (_) => _end() : null,
                onHorizontalDragCancel: live ? _end : null,
                child: Semantics(
                  container: true,
                  slider: true,
                  enabled: live,
                  label: widget.semanticLabel,
                  value: _describeValue(widget.value),
                  increasedValue: _describeValue(_quantise(widget.value + widget.step)),
                  decreasedValue: _describeValue(_quantise(widget.value - widget.step)),
                  textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
                  onIncrease: live ? () => _stepBy(1) : null,
                  onDecrease: live ? () => _stepBy(-1) : null,
                  child: ExcludeSemantics(
                    child: AnimatedOpacity(
                      duration: theme.duration,
                      opacity: live ? 1 : visual.disabledAlpha,
                      child: Stack(
                        // The handle is allowed to swell past the rail's room;
                        // it is not clipped away.
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: _SliderTrack(
                              visual: visual,
                              centre: centre,
                              left: inset,
                              travel: travel,
                              fraction: widget.fraction,
                            ),
                          ),
                          _Handle(
                            visual: visual,
                            centre: centre,
                            centreX: centreX,
                            extent: handleExtent,
                            ringColor: live && _focused ? theme.colors.primary : null,
                            ringWidth: theme.token.motion.lineWidth * 2,
                            sliding: !_dragging,
                            duration: theme.duration,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The rail: the hairline bed with the run the value has passed over and the
/// run ahead of it laid on top.
class _SliderTrack extends StatelessWidget {
  const new({
    required this.visual,
    required this.centre,
    required this.left,
    required this.travel,
    required this.fraction,
  });

  final _SliderVisual visual;

  /// The rail's centre line inside the control's box.
  final double centre;

  /// Where the rail starts and how far it runs.
  final double left;

  final double travel;

  /// How much of the rail the value has run over.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final outline = visual.trackOutline;
    final bed = outline == null
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: visual.radius,
              border: Border.all(color: outline, width: visual.outlineWidth),
            ),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (bed != null)
          Positioned(
            left: left,
            top: centre - visual.trackHeight / 2,
            width: travel,
            height: visual.trackHeight,
            child: bed,
          ),
        _Run(
          color: visual.inactiveColor,
          radius: visual.radius,
          left: left,
          width: travel,
          thickness: visual.trackHeight,
          centre: centre,
        ),
        _Run(
          color: visual.activeColor,
          radius: visual.radius,
          left: left,
          width: travel * fraction,
          thickness: visual.activeHeight,
          centre: centre,
        ),
      ],
    );
  }
}

/// One run of the track: a bar of colour with the rail's corner, laid at the
/// thickness the track gives that part of it.
class _Run extends StatelessWidget {
  const new({
    required this.color,
    required this.radius,
    required this.left,
    required this.width,
    required this.thickness,
    required this.centre,
  });

  final Color color;

  final BorderRadius radius;

  final double left;

  final double width;

  final double thickness;

  final double centre;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: centre - thickness / 2,
      width: width,
      height: thickness,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, borderRadius: radius),
      ),
    );
  }
}

/// The handle: the knob itself with its border and the kit's focus ring, riding
/// the value along the rail.
class _Handle extends StatelessWidget {
  const new({
    required this.visual,
    required this.centre,
    required this.centreX,
    required this.extent,
    required this.ringColor,
    required this.ringWidth,
    required this.sliding,
    required this.duration,
  });

  final _SliderVisual visual;

  final double centre;

  final double centreX;

  /// The knob's edge at the interaction state it is in.
  final double extent;

  final Color? ringColor;

  final double ringWidth;

  /// Whether the handle slides to its value or is told where it is.
  final bool sliding;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final slot = visual.handleSlot;
    return _OnHandle(
      centreX: centreX,
      slot: slot,
      top: centre - slot / 2,
      sliding: sliding,
      duration: duration,
      curve: visual.curve,
      child: AnimatedContainer(
        duration: duration,
        curve: visual.curve,
        width: extent,
        height: extent,
        decoration: visual.handleDecoration(ringColor: ringColor, ringWidth: ringWidth),
      ),
    );
  }
}

/// Slots the handle on the rail: centred on the value along the rail and sliding
/// there on the language's own curve — except while a drag is running, when the
/// handle is told where it is every frame and snapping is the answer.
class _OnHandle extends StatelessWidget {
  const new({
    required this.centreX,
    required this.slot,
    required this.top,
    required this.sliding,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final double centreX;

  /// The width of the box the handle sits in, centred on the value.
  final double slot;

  final double top;

  final bool sliding;

  final Duration duration;

  final Curve curve;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final box = Align(alignment: AlignmentDirectional.center, child: child);
    final left = centreX - slot / 2;
    return sliding
        ? AnimatedPositioned(
            duration: duration,
            curve: curve,
            left: left,
            top: top,
            width: slot,
            height: slot,
            child: box,
          )
        : Positioned(left: left, top: top, width: slot, height: slot, child: box);
  }
}

/// The value's own words: a whole number reads plainly, and a value with a
/// fraction keeps the digits it has without the padding zeros a fixed-format
/// render adds — so a screen reader and the semantics say one thing.
String _describeValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
