import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/l10n/translations.dart';

/// The rendition tier an episode opens with. The platform answers the
/// nearest track at or below the request when the exact one is missing.
enum HongguoQualityChoice {
  /// The best tier the platform serves a TV box (1080P).
  best(1080),

  /// 1080P.
  p1080(1080),

  /// 720P.
  p720(720),

  /// 540P.
  p540(540),

  /// 480P.
  p480(480),

  /// 360P.
  p360(360);

  HongguoQualityChoice(this.maxHeight);

  /// The tallest rendition the ladder may pick.
  final int maxHeight;

  /// The choice's short name.
  String label(Translations t) => switch (this) {
    HongguoQualityChoice.best => t.settings.hongguoQualityBest,
    HongguoQualityChoice.p1080 => t.settings.hongguoQuality1080,
    HongguoQualityChoice.p720 => t.settings.hongguoQuality720,
    HongguoQualityChoice.p540 => t.settings.hongguoQuality540,
    HongguoQualityChoice.p480 => t.settings.hongguoQuality480,
    HongguoQualityChoice.p360 => t.settings.hongguoQuality360,
  };
}

/// The station's own preference: the tier an episode opens with. Everything
/// else — the device identity, the signatures — the station manages itself.
@immutable
final class HongguoSettings {
  /// Creates the settings.
  const HongguoSettings({required this.quality});

  /// The reference's default: the best tier a TV box decodes.
  static const HongguoSettings standard = HongguoSettings(quality: HongguoQualityChoice.best);

  /// The rendition an episode opens with.
  final HongguoQualityChoice quality;
}

/// The key the choice is kept under.
const String kHongguoQualityPrefsKey = 'hongguo.quality';

/// Owns the station's opening rendition.
final class HongguoSettingsController extends Notifier<HongguoSettings> {
  @override
  HongguoSettings build() => HongguoSettings(quality: _readQuality());

  static HongguoQualityChoice _readQuality() {
    try {
      final stored = StoragePrefs.getString(kHongguoQualityPrefsKey);
      for (final choice in HongguoQualityChoice.values) {
        if (choice.name == stored) return choice;
      }
    } on Object {
      // A closed store keeps the default.
    }
    return HongguoQualityChoice.best;
  }

  /// Sets the rendition an episode opens with.
  Future<void> setQuality(HongguoQualityChoice quality) async {
    state = HongguoSettings(quality: quality);
    try {
      unawaited(StoragePrefs.setString(kHongguoQualityPrefsKey, quality.name));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The station's opening rendition.
final hongguoSettingsProvider =
    NotifierProvider<HongguoSettingsController, HongguoSettings>(HongguoSettingsController.new);
