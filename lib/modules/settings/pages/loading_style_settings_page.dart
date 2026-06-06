import 'package:remixicon/remixicon.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:pure_live/common/index.dart' hide Indicator;
import 'package:pure_live/modules/settings/pages/aurora_loading.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoadingStyleSettingsPage extends StatefulWidget {
  const LoadingStyleSettingsPage({super.key});

  @override
  State<LoadingStyleSettingsPage> createState() => _LoadingStyleSettingsPageState();
}

class _LoadingStyleSettingsPageState extends State<LoadingStyleSettingsPage> with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this)..repeat();
  }

  Future<bool> colorPickerDialog() async {
    final bool isZh = Get.locale?.languageCode == 'zh';
    return ColorPicker(
      color: HexColor(
        SettingsService.to.theme.loadingStyleColorSwitch.v.isEmpty
            ? Theme.of(context).colorScheme.primary.hex
            : SettingsService.to.theme.loadingStyleColorSwitch.v,
      ),
      onColorChanged: (Color color) {
        SettingsService.to.theme.loadingStyleColorSwitch.v = color.hex;
      },

      width: 40,
      height: 40,
      borderRadius: 4,
      spacing: 5,
      runSpacing: 5,
      wheelDiameter: 155,
      heading: Text(i18n("theme_color"), style: Theme.of(Get.context!).textTheme.titleMedium),
      subheading: Text(i18n("select_opacity"), style: Theme.of(Get.context!).textTheme.titleMedium),
      wheelSubheading: Text(i18n("theme_color_opacity"), style: Theme.of(Get.context!).textTheme.titleMedium),
      showMaterialName: false,
      showColorName: false,
      showColorCode: true,
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(longPressMenu: true),
      materialNameTextStyle: Theme.of(Get.context!).textTheme.bodySmall,
      colorNameTextStyle: Theme.of(Get.context!).textTheme.bodySmall,
      colorCodeTextStyle: Theme.of(Get.context!).textTheme.bodyMedium,
      colorCodePrefixStyle: Theme.of(Get.context!).textTheme.bodySmall,
      selectedPickerTypeColor: Theme.of(Get.context!).colorScheme.primary,
      customColorSwatchesAndNames: AppConsts.colorsNameMap,

      pickerTypeLabels: <ColorPickerType, String>{
        ColorPickerType.primary: isZh ? "常用色" : "Primary",
        ColorPickerType.accent: isZh ? "鲜艳色" : "Accent",
        ColorPickerType.custom: isZh ? "自定义" : "Custom",
        ColorPickerType.wheel: isZh ? "调色盘" : "Wheel",
      },
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
    ).showPickerDialog(
      Get.context!,
      actionsPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 480, minWidth: 375, maxWidth: 420),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  Widget _buildAnim(String key, Color color, double size, ThemeData theme) {
    Widget animWidget;

    if (key == 'rotatingPlain') {
      animWidget = SpinKitRotatingPlain(color: color, size: size);
    } else if (key == 'auroraRing') {
      animWidget = AuroraLoading(size: size);
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
        rightDotColor: theme.colorScheme.secondary,
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
        rightDotColor: theme.colorScheme.secondary,
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
          colors: [color, theme.colorScheme.secondary, theme.colorScheme.primary],
        ),
      );
    } else if (key == 'ballTrianglePathColoredFilled') {
      animWidget = SizedBox(
        width: size,
        height: size,
        child: LoadingIndicator(
          indicatorType: Indicator.ballTrianglePathColoredFilled,
          colors: [color, theme.colorScheme.secondary, theme.colorScheme.primary],
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
      animWidget = RotationTransition(
        turns: _rotateController,
        child: ShaderMask(
          shaderCallback: (rect) =>
              SweepGradient(colors: [color, color.withValues(alpha: 0.1)], stops: const [0.0, 0.85]).createShader(rect),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(width: 3.0, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return FittedBox(fit: BoxFit.contain, child: animWidget);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isZh = Get.locale?.languageCode == 'zh';
    final double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    double childAspectRatio = 0.95;

    if (screenWidth >= 900) {
      crossAxisCount = 6;
      childAspectRatio = 1.05;
    } else if (screenWidth >= 600) {
      crossAxisCount = 4;
      childAspectRatio = 1.0;
    } else if (screenWidth < 360) {
      crossAxisCount = 2;
      childAspectRatio = 0.85;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("change_loading_style")),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Remix.arrow_go_back_line),
              tooltip: i18n("restore_default"),
              onPressed: () {
                SettingsService.to.theme.loadingStyle.v = AppConsts.defaultLoadingStyleKey;
                SettingsService.to.theme.loadingStyleColorSwitch.v = '';
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                context.buildGroupTitle(i18n("change_loading_color")),
                context.buildModernCard([
                  context.buildTile(
                    icon: Remix.palette_line,
                    title: i18n("change_loading_color"),
                    subtitle: i18n("change_loading_color_subtitle"),
                    onTap: colorPickerDialog,
                    trailing: Obx(
                      () => ColorIndicator(
                        width: 28,
                        height: 28,
                        borderRadius: 6,
                        color: HexColor(
                          SettingsService.to.theme.loadingStyleColorSwitch.v.isEmpty
                              ? theme.colorScheme.primary.hex
                              : SettingsService.to.theme.loadingStyleColorSwitch.v,
                        ),
                        onSelectFocus: false,
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: AppConsts.allStyles.length,
              itemBuilder: (context, index) {
                final item = AppConsts.allStyles[index];
                final String key = item['key']!;
                final String displayName = isZh ? item['nameZh']! : item['nameEn']!;

                return Obx(() {
                  final bool isSelected = SettingsService.to.theme.loadingStyle.v == key;
                  final String currentHex = SettingsService.to.theme.loadingStyleColorSwitch.v;
                  final Color liveColor = currentHex.isEmpty ? theme.colorScheme.primary : HexColor(currentHex);

                  return InkWell(
                    onTap: () => SettingsService.to.theme.loadingStyle.v = key,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Center(
                                  child: SizedBox(width: 36, height: 36, child: _buildAnim(key, liveColor, 36, theme)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                                child: Text(
                                  displayName,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.t11Bold.copyWith(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
                                ),
                              ),
                            ],
                          ),
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
                            ),
                        ],
                      ),
                    ),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
