import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// The flying danmaku's look and motion (the reference's danmaku settings,
/// the subset the flame layer draws by): type size, speed, the screen's
/// share the messages may cross, opacity and the outline.
typedef DanmakuStyle = ({double fontSize, double baseSpeed, double area, double opacity, bool showStroke});

const DanmakuStyle _defaults = (fontSize: 18, baseSpeed: 120, area: 0.7, opacity: 1.0, showStroke: true);

/// The ranges the settings surface offers; the flame layer's own design
/// bounds, kept beside the controller so a slider and its consumer can
/// never disagree.
abstract final class DanmakuStyleRange {
  static const double fontSizeMin = 12;
  static const double fontSizeMax = 32;
  static const double speedMin = 60;
  static const double speedMax = 240;
  static const double areaMin = 0.25;
  static const double areaMax = 1;
  static const double opacityMin = 0.2;
  static const double opacityMax = 1;
}

/// Owns the danmaku style, persisted under `danmaku.style.*`; the player
/// surface rebuilds its barrage config on every change.
final class DanmakuStyleController extends Notifier<DanmakuStyle> {
  @override
  DanmakuStyle build() {
    try {
      return (
        fontSize: StoragePrefs.getDouble('danmaku.style.fontSize') ?? _defaults.fontSize,
        baseSpeed: StoragePrefs.getDouble('danmaku.style.baseSpeed') ?? _defaults.baseSpeed,
        area: StoragePrefs.getDouble('danmaku.style.area') ?? _defaults.area,
        opacity: StoragePrefs.getDouble('danmaku.style.opacity') ?? _defaults.opacity,
        showStroke: StoragePrefs.getBool('danmaku.style.showStroke') ?? _defaults.showStroke,
      );
    } on Object {
      return _defaults;
    }
  }

  /// Moves the type size, writing through.
  Future<void> setFontSize(double value) => _write((
    fontSize: value.clamp(DanmakuStyleRange.fontSizeMin, DanmakuStyleRange.fontSizeMax),
    baseSpeed: state.baseSpeed,
    area: state.area,
    opacity: state.opacity,
    showStroke: state.showStroke,
  ));

  /// Moves the speed, writing through.
  Future<void> setBaseSpeed(double value) => _write((
    fontSize: state.fontSize,
    baseSpeed: value.clamp(DanmakuStyleRange.speedMin, DanmakuStyleRange.speedMax),
    area: state.area,
    opacity: state.opacity,
    showStroke: state.showStroke,
  ));

  /// Moves the share of the screen messages may cross, writing through.
  Future<void> setArea(double value) => _write((
    fontSize: state.fontSize,
    baseSpeed: state.baseSpeed,
    area: value.clamp(DanmakuStyleRange.areaMin, DanmakuStyleRange.areaMax),
    opacity: state.opacity,
    showStroke: state.showStroke,
  ));

  /// Moves the opacity, writing through.
  Future<void> setOpacity(double value) => _write((
    fontSize: state.fontSize,
    baseSpeed: state.baseSpeed,
    area: state.area,
    opacity: value.clamp(DanmakuStyleRange.opacityMin, DanmakuStyleRange.opacityMax),
    showStroke: state.showStroke,
  ));

  /// Flips the outline, writing through.
  Future<void> setShowStroke({required bool value}) => _write((
    fontSize: state.fontSize,
    baseSpeed: state.baseSpeed,
    area: state.area,
    opacity: state.opacity,
    showStroke: value,
  ));

  /// Restores the designed defaults.
  Future<void> reset() => _write(_defaults);

  Future<void> _write(DanmakuStyle next) async {
    state = next;
    try {
      await StoragePrefs.setDouble('danmaku.style.fontSize', next.fontSize);
      await StoragePrefs.setDouble('danmaku.style.baseSpeed', next.baseSpeed);
      await StoragePrefs.setDouble('danmaku.style.area', next.area);
      await StoragePrefs.setDouble('danmaku.style.opacity', next.opacity);
      await StoragePrefs.setBool('danmaku.style.showStroke', next.showStroke);
    } on Object {
      // The style is a preference; a closed store loses it.
    }
  }
}

/// The flying danmaku's style.
final danmakuStyleProvider = NotifierProvider<DanmakuStyleController, DanmakuStyle>(DanmakuStyleController.new);
