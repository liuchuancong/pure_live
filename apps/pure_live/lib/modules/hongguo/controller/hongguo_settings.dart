import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/l10n/translations.dart';

/// The rendition an episode asks the stream endpoint for. The source picks
/// the nearest track at or below the request when the exact one is missing.
enum HongguoQualityChoice {
  /// The largest track the source serves.
  best('best'),

  /// 1080P.
  p1080('1080p'),

  /// 720P.
  p720('720p'),

  /// 540P.
  p540('540p'),

  /// 480P.
  p480('480p'),

  /// 360P.
  p360('360p');

  const HongguoQualityChoice(this.wire);

  /// The value the stream endpoint's `quality` parameter takes.
  final String wire;

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

/// The station's link to its companion service: where it listens and the
/// key it presents, plus the rendition an episode opens with.
@immutable
final class HongguoSettings {
  /// Creates the settings.
  const HongguoSettings({required this.serverUrl, required this.apiKey, required this.quality});

  /// The companion service's defaults: the loopback address the backend
  /// binds by default, no key (the service is open until keys are issued)
  /// and the best rendition.
  static const HongguoSettings standard = HongguoSettings(
    serverUrl: 'http://127.0.0.1:8000',
    apiKey: '',
    quality: HongguoQualityChoice.best,
  );

  /// The companion service's base URL, without a trailing slash.
  final String serverUrl;

  /// The key the service's `x-api-key` header carries, when one is issued.
  final String apiKey;

  /// The rendition an episode opens with.
  final HongguoQualityChoice quality;

  /// A copy with selected fields replaced.
  HongguoSettings copyWith({String? serverUrl, String? apiKey, HongguoQualityChoice? quality}) => HongguoSettings(
    serverUrl: serverUrl ?? this.serverUrl,
    apiKey: apiKey ?? this.apiKey,
    quality: quality ?? this.quality,
  );
}

/// The keys the three choices are kept under.
const String kHongguoServerPrefsKey = 'hongguo.server.url';
const String kHongguoApiKeyPrefsKey = 'hongguo.api.key';
const String kHongguoQualityPrefsKey = 'hongguo.quality';

/// Owns the station's link to its companion service. Every change reaches
/// the client provider, so the next request the feeds make already speaks
/// to the new address.
final class HongguoSettingsController extends Notifier<HongguoSettings> {
  @override
  HongguoSettings build() => HongguoSettings(
    serverUrl: _readString(kHongguoServerPrefsKey) ?? HongguoSettings.standard.serverUrl,
    apiKey: _readString(kHongguoApiKeyPrefsKey) ?? '',
    quality: _readQuality(),
  );

  static String? _readString(String key) {
    try {
      return StoragePrefs.getString(key);
    } on Object {
      // A closed store keeps the default.
      return null;
    }
  }

  static HongguoQualityChoice _readQuality() {
    final wire = _readString(kHongguoQualityPrefsKey);
    for (final choice in HongguoQualityChoice.values) {
      if (choice.wire == wire) return choice;
    }
    return HongguoQualityChoice.best;
  }

  /// Points the station at [url]; trailing slashes are dropped so the
  /// request URLs stay clean.
  Future<void> setServerUrl(String url) async {
    final trimmed = url.trim();
    state = state.copyWith(serverUrl: trimmed.isEmpty ? null : trimmed);
    try {
      await StoragePrefs.setString(
        kHongguoServerPrefsKey,
        trimmed.isEmpty ? HongguoSettings.standard.serverUrl : trimmed,
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Sets the key the requests present.
  Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    state = state.copyWith(apiKey: trimmed);
    try {
      await StoragePrefs.setString(kHongguoApiKeyPrefsKey, trimmed);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Sets the rendition an episode opens with.
  Future<void> setQuality(HongguoQualityChoice quality) async {
    state = state.copyWith(quality: quality);
    try {
      unawaited(StoragePrefs.setString(kHongguoQualityPrefsKey, quality.wire));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The station's companion link and opening rendition.
final hongguoSettingsProvider =
    NotifierProvider<HongguoSettingsController, HongguoSettings>(HongguoSettingsController.new);
