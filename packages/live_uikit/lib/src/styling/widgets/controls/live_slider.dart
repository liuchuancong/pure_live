import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/tokens/component_token.dart' show SliderComponentToken;

/// The token-driven slider renderer (rail, active track and handle from
/// [SliderComponentToken]; drag and arrow keys change the value) — the base for
/// languages that do not map a slider to their own widget.
class TokenSlider extends StatefulWidget {
  /// A token slider built from [spec].
  const new({required this.spec, super.key});

  /// The slider configuration.
  final LanguageSliderSpec spec;

  @override
  State<TokenSlider> createState() => _TokenSliderState();
}

class _TokenSliderState extends State<TokenSlider> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  FocusNode get _node => widget.spec.focusNode ?? _focus;

  bool get _interactive => widget.spec.enabled && widget.spec.onChanged != null;

  double _clamp(double v) => v.clamp(widget.spec.min, widget.spec.max);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _node.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _setValueFromX(double dx, double width, double handleSize) {
    final trackWidth = (width - handleSize).clamp(0.0, width);
    final fraction = (trackWidth <= 0 ? 0.0 : (dx - handleSize / 2) / trackWidth).clamp(0.0, 1.0);
    final range = widget.spec.max - widget.spec.min;
    widget.spec.onChanged?.call(_clamp(widget.spec.min + fraction * range));
  }

  void _step(double direction) {
    final range = widget.spec.max - widget.spec.min;
    widget.spec.onChanged?.call(_clamp(widget.spec.value + direction * range / 20));
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final st = theme.slider;
    final range = widget.spec.max - widget.spec.min;
    final fraction = range == 0 ? 0.0 : ((widget.spec.value - widget.spec.min) / range).clamp(0.0, 1.0);
    final opacity = widget.spec.enabled ? 1.0 : st.disabledOpacity;

    return Focus(
      focusNode: _node,
      canRequestFocus: _interactive,
      onKeyEvent: (node, event) {
        if (!_interactive) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _step(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _step(1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        slider: true,
        value: widget.spec.value.toStringAsFixed(2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final trackWidth = (width - st.handleSize).clamp(0.0, width);
            final center = st.handleSize / 2 + fraction * trackWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _interactive
                  ? (d) => _setValueFromX(d.localPosition.dx, width, st.handleSize)
                  : null,
              onTapDown: _interactive ? (d) => _setValueFromX(d.localPosition.dx, width, st.handleSize) : null,
              child: SizedBox(
                height: st.handleSize,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: st.railHeight,
                      decoration: BoxDecoration(
                        color: st.railColor.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(st.railHeight),
                      ),
                    ),
                    Container(
                      width: center,
                      height: st.railHeight,
                      decoration: BoxDecoration(
                        color: st.trackColor.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(st.railHeight),
                      ),
                    ),
                    Positioned(
                      left: (center - st.handleSize / 2).clamp(0.0, width - st.handleSize),
                      child: Container(
                        width: st.handleSize,
                        height: st.handleSize,
                        decoration: BoxDecoration(
                          color: st.handleColor.withValues(alpha: opacity),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: st.handleBorderColor.withValues(alpha: opacity),
                            width: _focused ? theme.token.motion.lineWidthBold : theme.token.motion.lineWidth,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The public slider: a thin dispatcher to the active language adapter, so
/// switching `UiConfig.language` re-renders it with the real library's control.
class LiveSlider extends StatelessWidget {
  /// A slider.
  const new({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.enabled = true,
    this.focusNode,
    super.key,
  });

  /// The current value.
  final double value;

  /// Called with each new value; null (or `enabled: false`) disables it.
  final ValueChanged<double>? onChanged;

  /// The lower bound.
  final double min;

  /// The upper bound.
  final double max;

  /// Whether the slider responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.slider(
    context,
    LanguageSliderSpec(value: value, onChanged: onChanged, min: min, max: max, enabled: enabled, focusNode: focusNode),
  );
}
