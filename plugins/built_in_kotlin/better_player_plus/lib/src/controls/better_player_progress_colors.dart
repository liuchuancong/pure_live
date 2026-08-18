// Flutter imports:
import 'package:flutter/rendering.dart';

///Representation of colors used in progress bar.
class BetterPlayerProgressColors {
  BetterPlayerProgressColors({
    Color playedColor = const Color.fromRGBO(255, 0, 0, 0.7),
    Color bufferedColor = const Color.fromRGBO(30, 30, 200, 0.2),
    Color handleColor = const Color.fromRGBO(200, 200, 200, 1),
    Color backgroundColor = const Color.fromRGBO(200, 200, 200, 0.5),
  }) : playedPaint = Paint()..color = playedColor,
       bufferedPaint = Paint()..color = bufferedColor,
       handlePaint = Paint()..color = handleColor,
       backgroundPaint = Paint()..color = backgroundColor;

  final Paint playedPaint;
  final Paint bufferedPaint;
  final Paint handlePaint;
  final Paint backgroundPaint;
}
