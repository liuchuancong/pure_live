import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/theme/font_sizes.dart';

double _readSize(String key, {required double fallback, required double min, required double max}) {
  try {
    return normalizeFontSize(StoragePrefs.getDouble(key), fallback: fallback, min: min, max: max);
  } on Object {
    return fallback;
  }
}

Future<void> _storeSize(String key, double value) async {
  try {
    await StoragePrefs.setDouble(key, value);
  } on Object {
    // A preference; a closed store loses it.
  }
}

/// The reference's five typography sizes, applied to the theme's text roles.
final class AppFontSizesController extends Notifier<AppFontSizes> {
  @override
  AppFontSizes build() => AppFontSizes(
    bodySmall: _readSize(
      kFontSizeBodySmallPrefsKey,
      fallback: kDefaultFontSizeBodySmall,
      min: kMinFontSizeBodySmall,
      max: kMaxFontSizeBodySmall,
    ),
    bodyMedium: _readSize(
      kFontSizeBodyMediumPrefsKey,
      fallback: kDefaultFontSizeBodyMedium,
      min: kMinFontSizeBodyMedium,
      max: kMaxFontSizeBodyMedium,
    ),
    bodyLarge: _readSize(
      kFontSizeBodyLargePrefsKey,
      fallback: kDefaultFontSizeBodyLarge,
      min: kMinFontSizeBodyLarge,
      max: kMaxFontSizeBodyLarge,
    ),
    titleMedium: _readSize(
      kFontSizeTitleMediumPrefsKey,
      fallback: kDefaultFontSizeTitleMedium,
      min: kMinFontSizeTitleMedium,
      max: kMaxFontSizeTitleMedium,
    ),
    titleLarge: _readSize(
      kFontSizeTitleLargePrefsKey,
      fallback: kDefaultFontSizeTitleLarge,
      min: kMinFontSizeTitleLarge,
      max: kMaxFontSizeTitleLarge,
    ),
  );

  /// The viewer's micro-metadata size.
  double get bodySmall => state.bodySmall;

  set bodySmall(double value) {
    final normalized = normalizeFontSize(
      value,
      fallback: kDefaultFontSizeBodySmall,
      min: kMinFontSizeBodySmall,
      max: kMaxFontSizeBodySmall,
    );
    if (state.bodySmall == normalized) return;
    state = state.copyWith(bodySmall: normalized);
    unawaited(_storeSize(kFontSizeBodySmallPrefsKey, normalized));
  }

  /// The viewer's standard body size.
  double get bodyMedium => state.bodyMedium;

  set bodyMedium(double value) {
    final normalized = normalizeFontSize(
      value,
      fallback: kDefaultFontSizeBodyMedium,
      min: kMinFontSizeBodyMedium,
      max: kMaxFontSizeBodyMedium,
    );
    if (state.bodyMedium == normalized) return;
    state = state.copyWith(bodyMedium: normalized);
    unawaited(_storeSize(kFontSizeBodyMediumPrefsKey, normalized));
  }

  /// The viewer's prominent body size.
  double get bodyLarge => state.bodyLarge;

  set bodyLarge(double value) {
    final normalized = normalizeFontSize(
      value,
      fallback: kDefaultFontSizeBodyLarge,
      min: kMinFontSizeBodyLarge,
      max: kMaxFontSizeBodyLarge,
    );
    if (state.bodyLarge == normalized) return;
    state = state.copyWith(bodyLarge: normalized);
    unawaited(_storeSize(kFontSizeBodyLargePrefsKey, normalized));
  }

  /// The viewer's card and section header size.
  double get titleMedium => state.titleMedium;

  set titleMedium(double value) {
    final normalized = normalizeFontSize(
      value,
      fallback: kDefaultFontSizeTitleMedium,
      min: kMinFontSizeTitleMedium,
      max: kMaxFontSizeTitleMedium,
    );
    if (state.titleMedium == normalized) return;
    state = state.copyWith(titleMedium: normalized);
    unawaited(_storeSize(kFontSizeTitleMediumPrefsKey, normalized));
  }

  /// The viewer's page, dialog and app bar title size.
  double get titleLarge => state.titleLarge;

  set titleLarge(double value) {
    final normalized = normalizeFontSize(
      value,
      fallback: kDefaultFontSizeTitleLarge,
      min: kMinFontSizeTitleLarge,
      max: kMaxFontSizeTitleLarge,
    );
    if (state.titleLarge == normalized) return;
    state = state.copyWith(titleLarge: normalized);
    unawaited(_storeSize(kFontSizeTitleLargePrefsKey, normalized));
  }
}

/// The typography-size preference.
final appFontSizesProvider = NotifierProvider<AppFontSizesController, AppFontSizes>(
  AppFontSizesController.new,
);
