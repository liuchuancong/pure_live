import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:pure_live/common/consts/app_consts.dart';
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

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  Widget _buildAnim(String key, Color color, double size, ThemeData theme) {
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
    final settings = Get.find<SettingsService>();
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
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
              onPressed: () => settings.loadingStyle.value = AppConsts.defaultLoadingStyleKey,
            ),
          ),
        ],
      ),
      body: GridView.builder(
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
            final bool isSelected = settings.loadingStyle.value == key;

            return InkWell(
              onTap: () => settings.loadingStyle.value = key,
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.transparent, width: 2),
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Center(
                            child: SizedBox(width: 36, height: 36, child: _buildAnim(key, color, 36, theme)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            ),
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
    );
  }
}
