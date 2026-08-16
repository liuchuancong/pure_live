//MIT License
//
//Copyright (c) [2019] [Befovy]
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

part of fijkplayer;

/// FijkSlider is like Slider in Flutter SDK.
/// FijkSlider support [cacheValue] which can be used
/// to show the player's cached buffer.
/// The [colors] is used to make colorful painter to draw the line and circle.
class FijkSlider extends StatefulWidget {
  final double value;
  final double cacheValue;

  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  final double min;
  final double max;

  final FijkSliderColors colors;

  const FijkSlider({
    Key? key,
    required this.value,
    required this.onChanged,
    this.cacheValue = 0.0,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.colors = const FijkSliderColors(),
  })  : assert(min <= max),
        assert(value >= min && value <= max),
        super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _FijkSliderState();
  }
}

class _FijkSliderState extends State<FijkSlider> {
  bool dragging = false;

  double dragValue = 0.0;

  static const double margin = 2.0;

  @override
  Widget build(BuildContext context) {
    double v = widget.value / (widget.max - widget.min);
    double cv = widget.cacheValue / (widget.max - widget.min);

    return GestureDetector(
      child: Container(
        margin: EdgeInsets.only(left: margin, right: margin),
        height: double.infinity,
        width: double.infinity,
        color: Colors.transparent,
        child: CustomPaint(
          painter: _SliderPainter(v, cv, dragging, colors: widget.colors),
        ),
      ),
      onHorizontalDragStart: (DragStartDetails details) {
        setState(() {
          dragging = true;
        });
        dragValue = widget.value;
        widget.onChangeStart?.call(dragValue);
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        final box = context.findRenderObject() as RenderBox;
        final dx = details.localPosition.dx;
        dragValue = (dx - margin) / (box.size.width - 2 * margin);
        dragValue = max(0, min(1, dragValue));
        dragValue = dragValue * (widget.max - widget.min) + widget.min;
        widget.onChanged(dragValue);
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        setState(() {
          dragging = false;
        });
        widget.onChangeEnd?.call(dragValue);
      },
    );
  }
}

/// Colors for the FijkSlider
class FijkSliderColors {
  const FijkSliderColors({
    this.playedColor = const Color.fromRGBO(255, 0, 0, 0.6),
    this.bufferedColor = const Color.fromRGBO(50, 50, 100, 0.4),
    this.cursorColor = const Color.fromRGBO(255, 0, 0, 0.8),
    this.baselineColor = const Color.fromRGBO(200, 200, 200, 0.5),
  });

  final Color playedColor;
  final Color bufferedColor;
  final Color cursorColor;
  final Color baselineColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FijkSliderColors &&
          runtimeType == other.runtimeType &&
          hashCode == other.hashCode;

  @override
  int get hashCode =>
      Object.hash(playedColor, bufferedColor, cursorColor, baselineColor);
}

class _SliderPainter extends CustomPainter {
  final double v;
  final double cv;

  final bool dragging;
  final Paint pt = Paint();

  final FijkSliderColors colors;

  _SliderPainter(this.v, this.cv, this.dragging,
      {this.colors = const FijkSliderColors()});

  @override
  void paint(Canvas canvas, Size size) {
    double lineHeight = min(size.height / 2, 1);
    pt.color = colors.baselineColor;

    double radius = min(size.height / 2, 4);
    // draw background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0, size.height / 2 - lineHeight),
          Offset(size.width, size.height / 2 + lineHeight),
        ),
        Radius.circular(radius),
      ),
      pt,
    );

    final double value = v * size.width;

    // draw played part
    pt.color = colors.playedColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0, size.height / 2 - lineHeight),
          Offset(value, size.height / 2 + lineHeight),
        ),
        Radius.circular(radius),
      ),
      pt,
    );

    // draw cached part
    final double cacheValue = cv * size.width;
    if (cacheValue > value && cacheValue > 0) {
      pt.color = colors.bufferedColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(
            Offset(value, size.height / 2 - lineHeight),
            Offset(cacheValue, size.height / 2 + lineHeight),
          ),
          Radius.circular(radius),
        ),
        pt,
      );
    }

    // draw circle cursor
    pt.color = colors.cursorColor;
    pt.color = pt.color.withAlpha(max(0, pt.color.alpha - 50));
    radius = min(size.height / 2, dragging ? 10 : 5);
    canvas.drawCircle(Offset(value, size.height / 2), radius, pt);
    pt.color = colors.cursorColor;
    radius = min(size.height / 2, dragging ? 6 : 3);
    canvas.drawCircle(Offset(value, size.height / 2), radius, pt);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SliderPainter && hashCode == other.hashCode;

  @override
  int get hashCode => Object.hash(v, cv, dragging, colors);

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) {
    return hashCode != oldDelegate.hashCode;
  }
}
