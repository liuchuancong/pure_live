import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pure_live/common/style/app_text_styles.dart';

class CountButton extends StatefulWidget {
  const CountButton({
    super.key,
    required this.minValue,
    required this.maxValue,
    required this.selectedValue,
    this.step = 1,
    this.backgroundColor,
    this.foregroundColor,
    this.buttonSize = const Size(35, 35),
    this.incrementIcon,
    this.decrementIcon,
    this.borderRadius = 12.0,
    required this.onChanged,
    this.valueBuilder,
    this.textStyle,
  }) : assert(maxValue > minValue),
       assert(selectedValue >= minValue && selectedValue <= maxValue),
       assert(step > 0);

  final int minValue;
  final int maxValue;
  final int selectedValue;
  final int step;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final Size buttonSize;

  final Widget? incrementIcon;
  final Widget? decrementIcon;

  final double borderRadius;

  final ValueChanged<int> onChanged;

  final Widget Function(int value)? valueBuilder;

  final TextStyle? textStyle;

  @override
  State<CountButton> createState() => _CountButtonState();
}

class _CountButtonState extends State<CountButton> {
  Timer? incrementTimer;
  Timer? decrementTimer;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.backgroundColor ?? Theme.of(context).colorScheme.primary;
    final foregroundColor = widget.foregroundColor ?? Colors.white;
    final effectiveTextStyle = widget.textStyle ?? AppTextStyles.t15.copyWith(color: Colors.white);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.buttonSize.width,
            height: widget.buttonSize.height,
            child: GestureDetector(
              onLongPress: startDecrementTimer,
              onLongPressEnd: (_) {
                decrementTimer?.cancel();
                decrementTimer = null;
              },
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor,
                  foregroundColor: foregroundColor,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(widget.borderRadius),
                      bottomLeft: Radius.circular(widget.borderRadius),
                    ),
                  ),
                ),
                onPressed: _decrement,
                child: widget.decrementIcon ?? Icon(Icons.remove, color: foregroundColor),
              ),
            ),
          ),

          Container(
            height: widget.buttonSize.height,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: backgroundColor, width: 2)),
            ),
            child: widget.valueBuilder != null
                ? widget.valueBuilder!(widget.selectedValue)
                : Text(widget.selectedValue.toString(), style: effectiveTextStyle),
          ),

          SizedBox(
            width: widget.buttonSize.width,
            height: widget.buttonSize.height,
            child: GestureDetector(
              onLongPress: startIncrementTimer,
              onLongPressEnd: (_) {
                incrementTimer?.cancel();
                incrementTimer = null;
              },
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor,
                  foregroundColor: foregroundColor,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(widget.borderRadius),
                      bottomRight: Radius.circular(widget.borderRadius),
                    ),
                  ),
                ),
                onPressed: _increment,
                child: widget.incrementIcon ?? Icon(Icons.add, color: foregroundColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _increment() {
    final value = widget.selectedValue + widget.step;
    if (value <= widget.maxValue) {
      widget.onChanged(value);
    }
  }

  void _decrement() {
    final value = widget.selectedValue - widget.step;
    if (value >= widget.minValue) {
      widget.onChanged(value);
    }
  }

  void startIncrementTimer() {
    incrementTimer?.cancel();
    incrementTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final value = widget.selectedValue + widget.step;
      if (value <= widget.maxValue) {
        widget.onChanged(value);
      } else {
        incrementTimer?.cancel();
        incrementTimer = null;
      }
    });
  }

  void startDecrementTimer() {
    decrementTimer?.cancel();
    decrementTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final value = widget.selectedValue - widget.step;
      if (value >= widget.minValue) {
        widget.onChanged(value);
      } else {
        decrementTimer?.cancel();
        decrementTimer = null;
      }
    });
  }
}
