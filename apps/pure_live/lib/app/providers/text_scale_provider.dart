import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show TextScaler;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The reference's typography scale: 0.5×–2× over the platform's own size.
const double kDefaultTextScaleFactor = 1;
const double kMinTextScaleFactor = 0.5;
const double kMaxTextScaleFactor = 2;

/// The most the platform's text size and the app's factor may grow together.
const double kAppTextScaleLimit = 2;

/// The platform's text size times [factor], capped at [kAppTextScaleLimit].
///
/// The reference multiplies rather than replaces the system scale, so a
/// viewer who raised the OS text size keeps that size when the app factor
/// stays at 100 %.
final class AppTextScaler extends TextScaler {
  const AppTextScaler(this.system, this.factor);

  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => math.min(system.scale(fontSize) * factor, fontSize * kAppTextScaleLimit);

  @override
  // Flutter keeps this member abstract only for backward compatibility.
  // ignore: deprecated_member_use
  double get textScaleFactor => math.min(system.textScaleFactor * factor, kAppTextScaleLimit);

  @override
  bool operator ==(Object other) => other is AppTextScaler && other.system == system && other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}

/// The persisted key.
const String kTextScalePrefsKey = 'theme.textScale';

/// Clamps a stored or chosen factor; an unreadable value keeps the default.
double normalizeTextScaleFactor(double? value) {
  if (value == null || !value.isFinite) return kDefaultTextScaleFactor;
  return value.clamp(kMinTextScaleFactor, kMaxTextScaleFactor);
}

/// The app-wide text multiplier, applied above every route.
final class TextScaleController extends Notifier<double> {
  @override
  double build() {
    try {
      return normalizeTextScaleFactor(StoragePrefs.getDouble(kTextScalePrefsKey));
    } on Object {
      return kDefaultTextScaleFactor;
    }
  }

  /// The factor applied to every text style.
  double get factor => state;

  /// Stores the factor; the root applies it at once.
  set factor(double value) {
    final normalized = normalizeTextScaleFactor(value);
    if (state == normalized) return;
    state = normalized;
    unawaited(StoragePrefs.setDouble(kTextScalePrefsKey, normalized));
  }
}

/// The text-scale preference.
final textScaleFactorProvider = NotifierProvider<TextScaleController, double>(TextScaleController.new);
