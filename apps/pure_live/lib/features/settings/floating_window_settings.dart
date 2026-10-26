import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The in-app floating window's size preset and its two pulled scales (the
/// reference's `floatWindowSize` / `floatWindowLandscapeScale` /
/// `floatWindowPortraitScale`). A picked preset resets both scales to 1.
typedef FloatingWindowSettings = ({String size, double landscapeScale, double portraitScale});

const FloatingWindowSettings _defaults = (size: 'medium', landscapeScale: 1, portraitScale: 1);

const String _sizeKey = 'playback.floatWindowSize';
const String _landscapeKey = 'playback.floatWindowLandscapeScale';
const String _portraitKey = 'playback.floatWindowPortraitScale';

/// The base width the preset scales: medium is the designed 360 px.
const double kFloatingWindowBaseWidth = 360;
const double kFloatingWindowScaleMin = 0.25;
const double kFloatingWindowScaleMax = 4;

/// The width factor of a size preset.
double floatingWindowSizeFactor(String size) => switch (size) {
  'small' => 0.8,
  'large' => 1.25,
  _ => 1,
};

/// Owns the floating window's size.
final class FloatingWindowController extends Notifier<FloatingWindowSettings> {
  @override
  FloatingWindowSettings build() {
    try {
      final size = StoragePrefs.getString(_sizeKey);
      return (
        size: const {'small', 'medium', 'large'}.contains(size) ? size! : _defaults.size,
        landscapeScale: _scale(StoragePrefs.getDouble(_landscapeKey)),
        portraitScale: _scale(StoragePrefs.getDouble(_portraitKey)),
      );
    } on Object {
      return _defaults;
    }
  }

  static double _scale(double? value) =>
      value == null || !value.isFinite ? 1 : value.clamp(kFloatingWindowScaleMin, kFloatingWindowScaleMax);

  /// Picks a preset; both pulled scales return to 1, as in the reference.
  Future<void> setSize(String size) async {
    final next = const {'small', 'medium', 'large'}.contains(size) ? size : _defaults.size;
    state = (size: next, landscapeScale: 1, portraitScale: 1);
    await _writeSize(next);
    await _writeScale(landscape: true, value: 1);
    await _writeScale(landscape: false, value: 1);
  }

  /// Stores the scale a resize drag ended at.
  Future<void> setScale({required bool portrait, required double value}) async {
    final next = _scale(value);
    state = (
      size: state.size,
      landscapeScale: portrait ? state.landscapeScale : next,
      portraitScale: portrait ? next : state.portraitScale,
    );
    await _writeScale(landscape: !portrait, value: next);
  }

  Future<void> _writeSize(String value) async {
    try {
      await StoragePrefs.setString(_sizeKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  Future<void> _writeScale({required bool landscape, required double value}) async {
    try {
      await StoragePrefs.setDouble(landscape ? _landscapeKey : _portraitKey, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The floating window's size choices.
final floatingWindowSettingsProvider = NotifierProvider<FloatingWindowController, FloatingWindowSettings>(
  FloatingWindowController.new,
);
