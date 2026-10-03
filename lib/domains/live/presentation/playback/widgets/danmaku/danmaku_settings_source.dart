import 'package:pure_live/get/get.dart';

/// The shared live-danmaku settings surface used by portrait, landscape and
/// desktop player layouts.
///
/// Keeping the UI dependent on this small contract prevents fullscreen from
/// growing a second set of ranges, defaults and persistence behaviour.
abstract interface class DanmakuSettingsSource {
  RxBool get noEmojiMode;

  RxDouble get danmakuArea;

  RxDouble get danmakuTopArea;

  RxDouble get danmakuBottomArea;

  RxDouble get danmakuSpeed;

  RxDouble get danmakuFontSize;

  RxInt get danmakuFontWeight;

  RxDouble get danmakuFontBorder;

  RxBool get danmakuMassMode;

  RxDouble get danmakuLetterSpacing;

  RxInt get danmakuMaxVisibleCount;

  RxDouble get danmakuOpacity;

  RxBool get pipDanmakuScaleAuto;

  RxDouble get pipDanmakuScaleValue;

  RxBool get enableDanmakuStroke;

  RxInt get danmakuFps;
}
