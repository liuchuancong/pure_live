import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

/// The compact (picture-in-picture) danmaku scale: follow the window width,
/// or pin a factor of the main look.
typedef PipDanmakuScale = ({bool auto, double scale});

/// The reference's defaults: auto on, pinned factor 0.4.
const PipDanmakuScale _defaults = (auto: true, scale: kPipDanmakuScaleMin);

/// The reference's pinned-factor range.
const double kPipDanmakuScaleMin = 0.4;
const double kPipDanmakuScaleMax = 1;

/// The compact window's width the auto factor is measured against.
const double kPipDanmakuReferenceWidth = 350;

/// The auto factor's floor: a narrower window still keeps danmaku legible.
const double kPipDanmakuAutoScaleMin = 0.65;

/// The factor a compact danmaku surface renders at.
///
/// Auto shrinks with the window (never above the main look); a pinned factor
/// replaces that width-derived value, and the result stays inside the
/// reference's 0.4–1.0 range either way.
double resolvePipDanmakuScale({
  required double width,
  required bool auto,
  required double pinned,
}) {
  final safeWidth = width.isFinite && width > 0 ? width : kPipDanmakuReferenceWidth;
  final autoFactor = auto ? (safeWidth / kPipDanmakuReferenceWidth).clamp(kPipDanmakuAutoScaleMin, 1.0) : 1.0;
  final fixed = auto ? 1.0 : pinned.clamp(kPipDanmakuScaleMin, kPipDanmakuScaleMax);
  return (autoFactor * fixed).clamp(kPipDanmakuScaleMin, kPipDanmakuScaleMax);
}

/// Owns the two choices, persisted under `danmaku.pip.*`.
final class PipDanmakuScaleController extends Notifier<PipDanmakuScale> {
  @override
  PipDanmakuScale build() {
    try {
      final pinned = StoragePrefs.getDouble('danmaku.pip.scale') ?? _defaults.scale;
      return (
        auto: StoragePrefs.getBool('danmaku.pip.autoScale') ?? _defaults.auto,
        scale: pinned.clamp(kPipDanmakuScaleMin, kPipDanmakuScaleMax),
      );
    } on Object {
      return _defaults;
    }
  }

  /// Flips the auto factor, writing through.
  Future<void> setAuto({required bool value}) => _write((auto: value, scale: state.scale));

  /// Pins a factor, writing through.
  Future<void> setScale(double value) =>
      _write((auto: state.auto, scale: value.clamp(kPipDanmakuScaleMin, kPipDanmakuScaleMax)));

  /// Restores the reference's defaults.
  Future<void> reset() => _write(_defaults);

  Future<void> _write(PipDanmakuScale next) async {
    state = next;
    try {
      await StoragePrefs.setBool('danmaku.pip.autoScale', next.auto);
      await StoragePrefs.setDouble('danmaku.pip.scale', next.scale);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The compact danmaku scale choice.
final pipDanmakuScaleProvider = NotifierProvider<PipDanmakuScaleController, PipDanmakuScale>(
  PipDanmakuScaleController.new,
);
