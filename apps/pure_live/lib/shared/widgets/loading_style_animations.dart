import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:loading_indicator/loading_indicator.dart';

/// The reference's loading-style gallery: the same animation for a stored
/// key, drawn by the three packages the reference uses. [secondary] is the
/// second ink some two-colour styles take; [size] is the square box.
Widget loadingStyleAnimation(
  String key, {
  required Color color,
  required Color secondary,
  required double size,
}) {
  Widget animWidget;

  if (key == 'rotatingPlain') {
    animWidget = SpinKitRotatingPlain(color: color, size: size);
  } else if (key == 'doubleBounce') {
    animWidget = SpinKitDoubleBounce(color: color, size: size);
  } else if (key == 'wave') {
    animWidget = SpinKitWave(color: color, size: size);
  } else if (key == 'wanderingCubes') {
    animWidget = SpinKitWanderingCubes(color: color, size: size);
  } else if (key == 'fadingFour') {
    animWidget = SpinKitFadingFour(color: color, size: size);
  } else if (key == 'fadingCube') {
    animWidget = SpinKitFadingCube(color: color, size: size);
  } else if (key == 'pulse') {
    animWidget = SpinKitPulse(color: color, size: size);
  } else if (key == 'chasingDots') {
    animWidget = SpinKitChasingDots(color: color, size: size);
  } else if (key == 'threeBounce') {
    animWidget = SpinKitThreeBounce(color: color, size: size);
  } else if (key == 'circle') {
    animWidget = SpinKitCircle(color: color, size: size);
  } else if (key == 'cubeGrid') {
    animWidget = SpinKitCubeGrid(color: color, size: size);
  } else if (key == 'fadingCircle') {
    animWidget = SpinKitFadingCircle(color: color, size: size);
  } else if (key == 'rotatingCircle') {
    animWidget = SpinKitRotatingCircle(color: color, size: size);
  } else if (key == 'foldingCube') {
    animWidget = SpinKitFoldingCube(color: color, size: size);
  } else if (key == 'pumpingHeart') {
    animWidget = SpinKitPumpingHeart(color: color, size: size);
  } else if (key == 'hourGlass') {
    animWidget = SpinKitHourGlass(color: color, size: size);
  } else if (key == 'pouringHourGlass') {
    animWidget = SpinKitPouringHourGlass(color: color, size: size);
  } else if (key == 'pouringHourGlassRefined') {
    animWidget = SpinKitPouringHourGlassRefined(color: color, size: size);
  } else if (key == 'fadingGrid') {
    animWidget = SpinKitFadingGrid(color: color, size: size);
  } else if (key == 'ring') {
    animWidget = SpinKitRing(color: color, size: size);
  } else if (key == 'ripple') {
    animWidget = SpinKitRipple(color: color, size: size);
  } else if (key == 'spinningCircle') {
    animWidget = SpinKitSpinningCircle(color: color, size: size);
  } else if (key == 'spinningLines') {
    animWidget = SpinKitSpinningLines(color: color, size: size);
  } else if (key == 'squareCircle') {
    animWidget = SpinKitSquareCircle(color: color, size: size);
  } else if (key == 'dualRing') {
    animWidget = SpinKitDualRing(color: color, size: size);
  } else if (key == 'pianoWave') {
    animWidget = SpinKitPianoWave(color: color, size: size);
  } else if (key == 'dancingSquare') {
    animWidget = SpinKitDancingSquare(color: color, size: size);
  } else if (key == 'threeInOut') {
    animWidget = SpinKitThreeInOut(color: color, size: size);
  } else if (key == 'waveSpinner') {
    animWidget = SpinKitWaveSpinner(color: color, size: size);
  } else if (key == 'pulsingGrid') {
    animWidget = SpinKitPulsingGrid(color: color, size: size);
  } else if (key == 'waveDots') {
    animWidget = LoadingAnimationWidget.waveDots(color: color, size: size);
  } else if (key == 'inkDrop') {
    animWidget = LoadingAnimationWidget.inkDrop(color: color, size: size);
  } else if (key == 'twistingDots') {
    animWidget = LoadingAnimationWidget.twistingDots(
      leftDotColor: color,
      rightDotColor: secondary,
      size: size,
    );
  } else if (key == 'threeRotatingDots') {
    animWidget = LoadingAnimationWidget.threeRotatingDots(color: color, size: size);
  } else if (key == 'staggeredDotsWave') {
    animWidget = LoadingAnimationWidget.staggeredDotsWave(color: color, size: size);
  } else if (key == 'fourRotatingDots') {
    animWidget = LoadingAnimationWidget.fourRotatingDots(color: color, size: size);
  } else if (key == 'fallingDot') {
    animWidget = LoadingAnimationWidget.fallingDot(color: color, size: size);
  } else if (key == 'progressiveDots') {
    animWidget = LoadingAnimationWidget.progressiveDots(color: color, size: size);
  } else if (key == 'discreteCircular') {
    animWidget = LoadingAnimationWidget.discreteCircle(color: color, size: size);
  } else if (key == 'threeArchedCircle') {
    animWidget = LoadingAnimationWidget.threeArchedCircle(color: color, size: size);
  } else if (key == 'bouncingBall') {
    animWidget = LoadingAnimationWidget.bouncingBall(color: color, size: size);
  } else if (key == 'flickr') {
    animWidget = LoadingAnimationWidget.flickr(
      leftDotColor: color,
      rightDotColor: secondary,
      size: size,
    );
  } else if (key == 'hexagonDots') {
    animWidget = LoadingAnimationWidget.hexagonDots(color: color, size: size);
  } else if (key == 'beat') {
    animWidget = LoadingAnimationWidget.beat(color: color, size: size);
  } else if (key == 'twoRotatingArc') {
    animWidget = LoadingAnimationWidget.twoRotatingArc(color: color, size: size);
  } else if (key == 'horizontalRotatingDots') {
    animWidget = LoadingAnimationWidget.horizontalRotatingDots(color: color, size: size);
  } else if (key == 'newtonCradle') {
    animWidget = LoadingAnimationWidget.newtonCradle(color: color, size: size);
  } else if (key == 'stretchedDots') {
    animWidget = LoadingAnimationWidget.stretchedDots(color: color, size: size);
  } else if (key == 'halfTriangleDot') {
    animWidget = LoadingAnimationWidget.halfTriangleDot(color: color, size: size);
  } else if (key == 'dotsTriangle') {
    animWidget = LoadingAnimationWidget.dotsTriangle(color: color, size: size);
  } else if (key == 'ballPulse') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballPulse, colors: [color]),
    );
  } else if (key == 'ballGridPulse') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballGridPulse, colors: [color]),
    );
  } else if (key == 'ballClipRotate') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballClipRotate, colors: [color]),
    );
  } else if (key == 'ballClipRotatePulse') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballClipRotatePulse, colors: [color]),
    );
  } else if (key == 'squareSpin') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.squareSpin, colors: [color]),
    );
  } else if (key == 'ballClipRotateMultiple') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballClipRotateMultiple, colors: [color]),
    );
  } else if (key == 'ballPulseRise') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballPulseRise, colors: [color]),
    );
  } else if (key == 'ballRotate') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballRotate, colors: [color]),
    );
  } else if (key == 'cubeTransition') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.cubeTransition, colors: [color]),
    );
  } else if (key == 'ballZigZag') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballZigZag, colors: [color]),
    );
  } else if (key == 'ballZigZagDeflect') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballZigZagDeflect, colors: [color]),
    );
  } else if (key == 'ballTrianglePath') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballTrianglePath, colors: [color]),
    );
  } else if (key == 'ballTrianglePathColored') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(
        indicatorType: Indicator.ballTrianglePathColored,
        colors: [color, secondary, color],
      ),
    );
  } else if (key == 'ballTrianglePathColoredFilled') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(
        indicatorType: Indicator.ballTrianglePathColoredFilled,
        colors: [color, secondary, color],
      ),
    );
  } else if (key == 'ballScale') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballScale, colors: [color]),
    );
  } else if (key == 'lineScale') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.lineScale, colors: [color]),
    );
  } else if (key == 'lineScaleParty') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.lineScaleParty, colors: [color]),
    );
  } else if (key == 'ballScaleMultiple') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballScaleMultiple, colors: [color]),
    );
  } else if (key == 'ballPulseSync') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballPulseSync, colors: [color]),
    );
  } else if (key == 'ballBeat') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballBeat, colors: [color]),
    );
  } else if (key == 'lineScalePulseOut') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.lineScalePulseOut, colors: [color]),
    );
  } else if (key == 'lineScalePulseOutRapid') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.lineScalePulseOutRapid, colors: [color]),
    );
  } else if (key == 'ballScaleRipple') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballScaleRipple, colors: [color]),
    );
  } else if (key == 'ballScaleRippleMultiple') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballScaleRippleMultiple, colors: [color]),
    );
  } else if (key == 'ballSpinFadeLoader') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballSpinFadeLoader, colors: [color]),
    );
  } else if (key == 'lineSpinFadeLoader') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.lineSpinFadeLoader, colors: [color]),
    );
  } else if (key == 'triangleSkewSpin') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.triangleSkewSpin, colors: [color]),
    );
  } else if (key == 'pacman') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.pacman, colors: [color]),
    );
  } else if (key == 'ballGridBeat') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballGridBeat, colors: [color]),
    );
  } else if (key == 'semiCircleSpin') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.semiCircleSpin, colors: [color]),
    );
  } else if (key == 'ballRotateChase') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.ballRotateChase, colors: [color]),
    );
  } else if (key == 'orbit') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.orbit, colors: [color]),
    );
  } else if (key == 'audioEqualizer') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.audioEqualizer, colors: [color]),
    );
  } else if (key == 'circleStrokeSpin') {
    animWidget = SizedBox(
      width: size,
      height: size,
      child: LoadingIndicator(indicatorType: Indicator.circleStrokeSpin, colors: [color]),
    );
  } else {
    animWidget = SizedBox.square(dimension: size);
  }
  return FittedBox(child: animWidget);
}
