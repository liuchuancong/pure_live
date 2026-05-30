import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:flutter_color/flutter_color.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:pure_live/common/style/app_text_styles.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/modules/settings/pages/aurora_loading.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

enum AppStatusType { loading, empty, error }

class AppStatusView extends StatefulWidget {
  final AppStatusType type;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final bool isMini;
  final Color? iconColor;
  final Color? titleColor;
  final Color? subtitleColor;

  const AppStatusView({
    super.key,
    required this.type,
    this.title,
    this.subtitle,
    this.icon,
    this.buttonText,
    this.onButtonPressed,
    this.isMini = false,
    this.iconColor,
    this.titleColor,
    this.subtitleColor,
  });

  @override
  State<AppStatusView> createState() => _AppStatusViewState();
}

class _AppStatusViewState extends State<AppStatusView> with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    if (widget.type == AppStatusType.loading && SettingsService.to.theme.loadingStyle.v == 'default') {
      _rotateController.repeat();
    }
  }

  @override
  void didUpdateWidget(AppStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type == AppStatusType.loading &&
        SettingsService.to.theme.loadingStyle.v == 'default' &&
        !_rotateController.isAnimating) {
      _rotateController.repeat();
    } else if ((widget.type != AppStatusType.loading || SettingsService.to.theme.loadingStyle.v != 'default') &&
        _rotateController.isAnimating) {
      _rotateController.stop();
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  Widget _getSpinKit(String style, Color color, double size) {
    switch (style) {
      case 'rotatingPlain':
        return SpinKitRotatingPlain(color: color, size: size);
      case 'aurora_loading':
        return const AuroraLoading(size: 50.0);
      case 'doubleBounce':
        return SpinKitDoubleBounce(color: color, size: size);
      case 'wave':
        return SpinKitWave(color: color, size: size);
      case 'wanderingCubes':
        return SpinKitWanderingCubes(color: color, size: size);
      case 'fadingFour':
        return SpinKitFadingFour(color: color, size: size);
      case 'fadingCube':
        return SpinKitFadingCube(color: color, size: size);
      case 'pulse':
        return SpinKitPulse(color: color, size: size);
      case 'chasingDots':
        return SpinKitChasingDots(color: color, size: size);
      case 'threeBounce':
        return SpinKitThreeBounce(color: color, size: size);
      case 'circle':
        return SpinKitCircle(color: color, size: size);
      case 'cubeGrid':
        return SpinKitCubeGrid(color: color, size: size);
      case 'fadingCircle':
        return SpinKitFadingCircle(color: color, size: size);
      case 'rotatingCircle':
        return SpinKitRotatingCircle(color: color, size: size);
      case 'foldingCube':
        return SpinKitFoldingCube(color: color, size: size);
      case 'pumpingHeart':
        return SpinKitPumpingHeart(color: color, size: size);
      case 'hourGlass':
        return SpinKitHourGlass(color: color, size: size);
      case 'pouringHourGlass':
        return SpinKitPouringHourGlass(color: color, size: size);
      case 'pouringHourGlassRefined':
        return SpinKitPouringHourGlassRefined(color: color, size: size);
      case 'fadingGrid':
        return SpinKitFadingGrid(color: color, size: size);
      case 'ring':
        return SpinKitRing(color: color, size: size);
      case 'ripple':
        return SpinKitRipple(color: color, size: size);
      case 'spinningCircle':
        return SpinKitSpinningCircle(color: color, size: size);
      case 'spinningLines':
        return SpinKitSpinningLines(color: color, size: size);
      case 'squareCircle':
        return SpinKitSquareCircle(color: color, size: size);
      case 'dualRing':
        return SpinKitDualRing(color: color, size: size);
      case 'pianoWave':
        return SpinKitPianoWave(color: color, size: size);
      case 'dancingSquare':
        return SpinKitDancingSquare(color: color, size: size);
      case 'threeInOut':
        return SpinKitThreeInOut(color: color, size: size);
      case 'waveSpinner':
        return SpinKitWaveSpinner(color: color, size: size);
      case 'pulsingGrid':
        return SpinKitPulsingGrid(color: color, size: size);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _getLoadingAnimation(String style, Color color, double size, ThemeData theme) {
    switch (style) {
      case 'waveDots':
        return LoadingAnimationWidget.waveDots(color: color, size: size);
      case 'inkDrop':
        return LoadingAnimationWidget.inkDrop(color: color, size: size);
      case 'twistingDots':
        return LoadingAnimationWidget.twistingDots(
          leftDotColor: color,
          rightDotColor: theme.colorScheme.secondary,
          size: size,
        );
      case 'threeRotatingDots':
        return LoadingAnimationWidget.threeRotatingDots(color: color, size: size);
      case 'staggeredDotsWave':
        return LoadingAnimationWidget.staggeredDotsWave(color: color, size: size);
      case 'fourRotatingDots':
        return LoadingAnimationWidget.fourRotatingDots(color: color, size: size);
      case 'fallingDot':
        return LoadingAnimationWidget.fallingDot(color: color, size: size);
      case 'progressiveDots':
        return LoadingAnimationWidget.progressiveDots(color: color, size: size);
      case 'discreteCircular':
        return LoadingAnimationWidget.discreteCircle(color: color, size: size);
      case 'threeArchedCircle':
        return LoadingAnimationWidget.threeArchedCircle(color: color, size: size);
      case 'bouncingBall':
        return LoadingAnimationWidget.bouncingBall(color: color, size: size);
      case 'flickr':
        return LoadingAnimationWidget.flickr(
          leftDotColor: color,
          rightDotColor: theme.colorScheme.secondary,
          size: size,
        );
      case 'hexagonDots':
        return LoadingAnimationWidget.hexagonDots(color: color, size: size);
      case 'beat':
        return LoadingAnimationWidget.beat(color: color, size: size);
      case 'twoRotatingArc':
        return LoadingAnimationWidget.twoRotatingArc(color: color, size: size);
      case 'horizontalRotatingDots':
        return LoadingAnimationWidget.horizontalRotatingDots(color: color, size: size);
      case 'newtonCradle':
        return LoadingAnimationWidget.newtonCradle(color: color, size: size);
      case 'stretchedDots':
        return LoadingAnimationWidget.stretchedDots(color: color, size: size);
      case 'halfTriangleDot':
        return LoadingAnimationWidget.halfTriangleDot(color: color, size: size);
      case 'dotsTriangle':
        return LoadingAnimationWidget.dotsTriangle(color: color, size: size);

      default:
        return RotationTransition(
          turns: _rotateController,
          child: ShaderMask(
            shaderCallback: (rect) => SweepGradient(
              colors: [color, color.withValues(alpha: 0.1)],
              stops: const [0.0, 0.85],
            ).createShader(rect),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(width: 3.5, color: Colors.white),
              ),
            ),
          ),
        );
    }
  }

  Widget _getLoadingIndicator(String style, Color color, double size, ThemeData theme) {
    switch (style) {
      case 'ballPulse':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballPulse, colors: [color]),
        );
      case 'ballGridPulse':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballGridPulse, colors: [color]),
        );
      case 'ballClipRotate':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballClipRotate, colors: [color]),
        );
      case 'ballClipRotatePulse':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballClipRotatePulse, colors: [color]),
        );
      case 'squareSpin':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.squareSpin, colors: [color]),
        );
      case 'ballClipRotateMultiple':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballClipRotateMultiple, colors: [color]),
        );
      case 'ballPulseRise':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballPulseRise, colors: [color]),
        );
      case 'ballRotate':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballRotate, colors: [color]),
        );
      case 'cubeTransition':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.cubeTransition, colors: [color]),
        );
      case 'ballZigZag':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballZigZag, colors: [color]),
        );
      case 'ballZigZagDeflect':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballZigZagDeflect, colors: [color]),
        );
      case 'ballTrianglePath':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballTrianglePath, colors: [color]),
        );
      case 'ballTrianglePathColored':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(
            indicatorType: Indicator.ballTrianglePathColored,
            colors: [color, theme.colorScheme.secondary, theme.colorScheme.primary],
          ),
        );
      case 'ballTrianglePathColoredFilled':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(
            indicatorType: Indicator.ballTrianglePathColoredFilled,
            colors: [color, theme.colorScheme.secondary, theme.colorScheme.primary],
          ),
        );
      case 'ballScale':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballScale, colors: [color]),
        );
      case 'lineScale':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.lineScale, colors: [color]),
        );
      case 'lineScaleParty':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.lineScaleParty, colors: [color]),
        );
      case 'ballScaleMultiple':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballScaleMultiple, colors: [color]),
        );
      case 'ballPulseSync':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballPulseSync, colors: [color]),
        );
      case 'ballBeat':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballBeat, colors: [color]),
        );
      case 'lineScalePulseOut':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.lineScalePulseOut, colors: [color]),
        );
      case 'lineScalePulseOutRapid':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.lineScalePulseOutRapid, colors: [color]),
        );
      case 'ballScaleRipple':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballScaleRipple, colors: [color]),
        );
      case 'ballScaleRippleMultiple':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballScaleRippleMultiple, colors: [color]),
        );
      case 'ballSpinFadeLoader':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballSpinFadeLoader, colors: [color]),
        );
      case 'lineSpinFadeLoader':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.lineSpinFadeLoader, colors: [color]),
        );
      case 'triangleSkewSpin':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.triangleSkewSpin, colors: [color]),
        );
      case 'pacman':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.pacman, colors: [color]),
        );
      case 'ballGridBeat':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballGridBeat, colors: [color]),
        );
      case 'semiCircleSpin':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.semiCircleSpin, colors: [color]),
        );
      case 'ballRotateChase':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.ballRotateChase, colors: [color]),
        );
      case 'orbit':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.orbit, colors: [color]),
        );
      case 'audioEqualizer':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.audioEqualizer, colors: [color]),
        );
      case 'circleStrokeSpin':
        return SizedBox(
          width: size,
          height: size,
          child: LoadingIndicator(indicatorType: Indicator.circleStrokeSpin, colors: [color]),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLoadingWidget(String style) {
    final theme = Theme.of(context);
    Color parsedColor;
    final hexColor = SettingsService.to.theme.loadingStyleColorSwitch.v;
    if (hexColor.isNotEmpty) {
      parsedColor = HexColor(hexColor);
    } else {
      parsedColor = widget.iconColor ?? theme.colorScheme.primary;
    }

    final double size = widget.isMini ? 24 : 50;

    final spinkit = _getSpinKit(style, parsedColor, size);
    if (spinkit is! SizedBox) return spinkit;

    final loadingIndicator = _getLoadingIndicator(style, parsedColor, size, theme);
    if (loadingIndicator is! SizedBox || loadingIndicator.child != null) return loadingIndicator;

    final loadingAnimation = _getLoadingAnimation(style, parsedColor, size, theme);
    if (loadingAnimation is! SizedBox) return loadingAnimation;

    return RotationTransition(
      turns: _rotateController,
      child: ShaderMask(
        shaderCallback: (rect) {
          return SweepGradient(
            startAngle: 0.0,
            endAngle: 3.14 * 2,
            colors: [parsedColor, parsedColor.withValues(alpha: 0.1)],
            stops: const [0.0, 0.85],
          ).createShader(rect);
        },
        child: Container(
          width: widget.isMini ? 20 : 44,
          height: widget.isMini ? 20 : 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(width: widget.isMini ? 2.0 : 3.5, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = widget.iconColor ?? theme.colorScheme.primary;

    if (widget.type == AppStatusType.loading) {
      return Center(
        child: Obx(() {
          return _buildLoadingWidget(SettingsService.to.theme.loadingStyle.v);
        }),
      );
    }

    final String finalTitle =
        widget.title ?? (widget.type == AppStatusType.error ? i18n('status_error_title') : i18n('status_empty_title'));
    final String finalSubtitle =
        widget.subtitle ??
        (widget.type == AppStatusType.error ? i18n('status_error_subtitle') : i18n('status_empty_subtitle'));
    final String finalButtonText = widget.buttonText ?? i18n('status_retry_button');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              padding: EdgeInsets.all(widget.isMini ? 8 : 22),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: effectiveIconColor.withValues(alpha: 0.05), width: 1),
              ),
              child: Icon(
                widget.icon ?? (widget.type == AppStatusType.error ? Icons.wifi_off_rounded : Icons.live_tv_rounded),
                size: widget.isMini ? 16 : 42,
                color: widget.iconColor ?? theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (!widget.isMini || finalTitle.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              finalTitle,
              style: AppTextStyles.t15.copyWith(
                fontWeight: FontWeight.w600,
                color: widget.titleColor ?? theme.textTheme.titleMedium?.color,
              ),
            ),
          ],
          if (!widget.isMini || finalSubtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(finalSubtitle, style: AppTextStyles.t13.copyWith(color: widget.subtitleColor ?? theme.hintColor)),
          ],
          if (!widget.isMini && widget.onButtonPressed != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: widget.onButtonPressed,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(finalButtonText),
            ),
          ],
        ],
      ),
    );
  }
}
