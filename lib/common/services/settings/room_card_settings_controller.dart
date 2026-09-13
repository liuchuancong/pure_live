import 'dart:convert';

import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

enum RoomCardViewport { mobile, desktop }

enum RoomCardPlatformBadgeMode { automatic, always, hidden }

enum RoomCardPreset {
  compact('compact'),
  standard('normal'),
  detailed('rich'),
  custom('custom');

  const RoomCardPreset(this.storageKey);

  final String storageKey;
}

@immutable
class RoomCardAppearance {
  const RoomCardAppearance({
    required this.showAvatar,
    required this.showAnchorName,
    required this.showPlatformBadge,
    required this.automaticPlatformBadge,
    required this.showAudience,
    required this.showReplayBadge,
    required this.cornerRadius,
  });

  static const double defaultCornerRadius = 20;
  static const double minCornerRadius = 0;
  static const double maxCornerRadius = 32;

  static const compact = RoomCardAppearance(
    showAvatar: false,
    showAnchorName: false,
    showPlatformBadge: false,
    automaticPlatformBadge: false,
    showAudience: true,
    showReplayBadge: true,
    cornerRadius: 12,
  );

  static const standard = RoomCardAppearance(
    showAvatar: true,
    showAnchorName: true,
    showPlatformBadge: false,
    automaticPlatformBadge: true,
    showAudience: true,
    showReplayBadge: true,
    cornerRadius: defaultCornerRadius,
  );

  static const detailed = RoomCardAppearance(
    showAvatar: true,
    showAnchorName: true,
    showPlatformBadge: true,
    automaticPlatformBadge: false,
    showAudience: true,
    showReplayBadge: true,
    cornerRadius: defaultCornerRadius,
  );

  final bool showAvatar;
  final bool showAnchorName;
  final bool showPlatformBadge;
  final bool automaticPlatformBadge;
  final bool showAudience;
  final bool showReplayBadge;
  final double cornerRadius;

  RoomCardPlatformBadgeMode get platformBadgeMode {
    if (automaticPlatformBadge) return RoomCardPlatformBadgeMode.automatic;
    return showPlatformBadge ? RoomCardPlatformBadgeMode.always : RoomCardPlatformBadgeMode.hidden;
  }

  static RoomCardAppearance fromPreset(RoomCardPreset preset) {
    return switch (preset) {
      RoomCardPreset.compact => compact,
      RoomCardPreset.detailed => detailed,
      RoomCardPreset.standard || RoomCardPreset.custom => standard,
    };
  }

  static double normalizeCornerRadius(num value) {
    final converted = value.toDouble();
    if (!converted.isFinite) return defaultCornerRadius;
    return converted.clamp(minCornerRadius, maxCornerRadius).toDouble();
  }

  static RoomCardAppearance fromJson(
    Map<String, dynamic> json, {
    RoomCardAppearance fallback = standard,
    bool strict = false,
  }) {
    bool readBool(String currentKey, String legacyKey, bool defaultValue) {
      final value = json.containsKey(currentKey) ? json[currentKey] : json[legacyKey];
      if (value == null) return defaultValue;
      if (strict && value is! bool) throw FormatException('$currentKey must be a boolean');
      return value is bool ? value : defaultValue;
    }

    double readRadius() {
      final value = json['cornerRadius'] ?? json['cardBorderRadius'];
      if (value == null) return fallback.cornerRadius;
      if (strict && value is! num) throw const FormatException('cornerRadius must be numeric');
      if (value is! num) return fallback.cornerRadius;
      if (strict && !value.toDouble().isFinite) throw const FormatException('cornerRadius must be finite');
      return normalizeCornerRadius(value);
    }

    final hasExplicitPlatformValue = json.containsKey('showPlatformBadge') || json.containsKey('showPlatform');
    final showPlatformBadge = readBool('showPlatformBadge', 'showPlatform', fallback.showPlatformBadge);
    final automaticPlatformBadge = json.containsKey('automaticPlatformBadge')
        ? readBool('automaticPlatformBadge', 'automaticPlatformBadge', fallback.automaticPlatformBadge)
        : hasExplicitPlatformValue
        ? false
        : fallback.automaticPlatformBadge;

    return RoomCardAppearance(
      showAvatar: readBool('showAvatar', 'showAvatar', fallback.showAvatar),
      showAnchorName: readBool('showAnchorName', 'showSubtitle', fallback.showAnchorName),
      showPlatformBadge: showPlatformBadge,
      automaticPlatformBadge: showPlatformBadge ? false : automaticPlatformBadge,
      showAudience: readBool('showAudience', 'showAudience', fallback.showAudience),
      showReplayBadge: readBool('showReplayBadge', 'showRecordBadge', fallback.showReplayBadge),
      cornerRadius: readRadius(),
    );
  }

  RoomCardAppearance copyWith({
    bool? showAvatar,
    bool? showAnchorName,
    bool? showPlatformBadge,
    bool? automaticPlatformBadge,
    bool? showAudience,
    bool? showReplayBadge,
    double? cornerRadius,
  }) {
    return RoomCardAppearance(
      showAvatar: showAvatar ?? this.showAvatar,
      showAnchorName: showAnchorName ?? this.showAnchorName,
      showPlatformBadge: showPlatformBadge ?? this.showPlatformBadge,
      automaticPlatformBadge: automaticPlatformBadge ?? this.automaticPlatformBadge,
      showAudience: showAudience ?? this.showAudience,
      showReplayBadge: showReplayBadge ?? this.showReplayBadge,
      cornerRadius: normalizeCornerRadius(cornerRadius ?? this.cornerRadius),
    );
  }

  RoomCardAppearance withPlatformBadgeMode(RoomCardPlatformBadgeMode mode) {
    return copyWith(
      showPlatformBadge: mode == RoomCardPlatformBadgeMode.always,
      automaticPlatformBadge: mode == RoomCardPlatformBadgeMode.automatic,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showAvatar': showAvatar,
      'showAnchorName': showAnchorName,
      'showPlatformBadge': showPlatformBadge,
      'automaticPlatformBadge': automaticPlatformBadge,
      'showAudience': showAudience,
      'showReplayBadge': showReplayBadge,
      'cornerRadius': normalizeCornerRadius(cornerRadius),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RoomCardAppearance &&
        other.showAvatar == showAvatar &&
        other.showAnchorName == showAnchorName &&
        other.showPlatformBadge == showPlatformBadge &&
        other.automaticPlatformBadge == automaticPlatformBadge &&
        other.showAudience == showAudience &&
        other.showReplayBadge == showReplayBadge &&
        other.cornerRadius == cornerRadius;
  }

  @override
  int get hashCode => Object.hash(
    showAvatar,
    showAnchorName,
    showPlatformBadge,
    automaticPlatformBadge,
    showAudience,
    showReplayBadge,
    cornerRadius,
  );
}

class RoomCardSettingsController extends GetxController {
  RoomCardSettingsController()
    : mobilePreset = hiveString('room_card_mobile_preset', RoomCardPreset.standard.storageKey),
      desktopPreset = hiveString('room_card_desktop_preset', RoomCardPreset.standard.storageKey),
      mobileConfig = hiveObject<RoomCardAppearance>(
        'room_card_mobile_config',
        _storedPresetFallback('room_card_mobile_preset'),
        fromJson: (json) =>
            RoomCardAppearance.fromJson(json, fallback: _storedPresetFallback('room_card_mobile_preset')),
        toJson: (value) => value.toJson(),
      ),
      desktopConfig = hiveObject<RoomCardAppearance>(
        'room_card_desktop_config',
        _storedPresetFallback('room_card_desktop_preset'),
        fromJson: (json) =>
            RoomCardAppearance.fromJson(json, fallback: _storedPresetFallback('room_card_desktop_preset')),
        toJson: (value) => value.toJson(),
      );

  static RoomCardSettingsController get to => Get.find<RoomCardSettingsController>();

  final RxString mobilePreset;
  final RxString desktopPreset;
  final Rx<RoomCardAppearance> mobileConfig;
  final Rx<RoomCardAppearance> desktopConfig;
  final List<Worker> _workers = [];

  static RoomCardPreset normalizePreset(String? value) {
    final key = value?.trim().toLowerCase();
    return RoomCardPreset.values.firstWhere(
      (candidate) => candidate.storageKey == key,
      orElse: () => RoomCardPreset.standard,
    );
  }

  static RoomCardAppearance _storedPresetFallback(String key) {
    return RoomCardAppearance.fromPreset(normalizePreset(HivePrefUtil.getString(key)));
  }

  @override
  void onInit() {
    super.onInit();
    _repairTarget(RoomCardViewport.mobile);
    _repairTarget(RoomCardViewport.desktop);
    _workers.addAll([
      ever<String>(mobilePreset, (_) => _repairPreset(RoomCardViewport.mobile)),
      ever<String>(desktopPreset, (_) => _repairPreset(RoomCardViewport.desktop)),
    ]);
  }

  @override
  void onClose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
    super.onClose();
  }

  RoomCardViewport get currentViewport => PlatformUtils.isMobile ? RoomCardViewport.mobile : RoomCardViewport.desktop;

  Rx<RoomCardAppearance> configRxFor(RoomCardViewport viewport) {
    return viewport == RoomCardViewport.mobile ? mobileConfig : desktopConfig;
  }

  RxString presetRxFor(RoomCardViewport viewport) {
    return viewport == RoomCardViewport.mobile ? mobilePreset : desktopPreset;
  }

  RoomCardAppearance configFor(RoomCardViewport viewport) => configRxFor(viewport).value;

  RoomCardAppearance resolve({RoomCardViewport? viewport}) => configFor(viewport ?? currentViewport);

  RoomCardPreset presetFor(RoomCardViewport viewport) => normalizePreset(presetRxFor(viewport).value);

  void applyPreset(RoomCardViewport viewport, RoomCardPreset preset) {
    if (preset == RoomCardPreset.custom) return;
    configRxFor(viewport).value = RoomCardAppearance.fromPreset(preset);
    presetRxFor(viewport).v = preset.storageKey;
  }

  void updateConfig(RoomCardViewport viewport, RoomCardAppearance value) {
    var normalized = value.copyWith(cornerRadius: value.cornerRadius);
    if (normalized.showPlatformBadge && normalized.automaticPlatformBadge) {
      normalized = normalized.copyWith(automaticPlatformBadge: false);
    }
    configRxFor(viewport).value = normalized;
    presetRxFor(viewport).v = _matchingPreset(normalized).storageKey;
  }

  void reset(RoomCardViewport viewport) => applyPreset(viewport, RoomCardPreset.standard);

  static RoomCardPreset _matchingPreset(RoomCardAppearance config) {
    if (config == RoomCardAppearance.compact) return RoomCardPreset.compact;
    if (config == RoomCardAppearance.standard) return RoomCardPreset.standard;
    if (config == RoomCardAppearance.detailed) return RoomCardPreset.detailed;
    return RoomCardPreset.custom;
  }

  void _repairTarget(RoomCardViewport viewport) {
    var config = configFor(viewport).copyWith(cornerRadius: configFor(viewport).cornerRadius);
    if (config.showPlatformBadge && config.automaticPlatformBadge) {
      config = config.copyWith(automaticPlatformBadge: false);
    }
    if (config != configFor(viewport)) configRxFor(viewport).value = config;
    final canonical = _matchingPreset(config).storageKey;
    if (presetRxFor(viewport).v != canonical) presetRxFor(viewport).v = canonical;
  }

  void _repairPreset(RoomCardViewport viewport) {
    final canonical = _matchingPreset(configFor(viewport)).storageKey;
    if (presetRxFor(viewport).v != canonical) presetRxFor(viewport).v = canonical;
  }

  Map<String, dynamic> toJson() {
    return {
      'mobilePreset': presetFor(RoomCardViewport.mobile).storageKey,
      'desktopPreset': presetFor(RoomCardViewport.desktop).storageKey,
      'mobileConfig': configFor(RoomCardViewport.mobile).toJson(),
      'desktopConfig': configFor(RoomCardViewport.desktop).toJson(),
    };
  }

  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    final source = json['roomCard'] is Map ? Map<String, dynamic>.from(json['roomCard'] as Map) : json;
    final mobilePreset = normalizePreset(_readString(source, 'mobilePreset', legacyKey: 'room_card_mobile_preset'));
    final desktopPreset = normalizePreset(_readString(source, 'desktopPreset', legacyKey: 'room_card_desktop_preset'));
    final mobileJson = _readConfigMap(source, 'mobileConfig', legacyKey: 'room_card_mobile_config');
    final desktopJson = _readConfigMap(source, 'desktopConfig', legacyKey: 'room_card_desktop_config');
    final mobile = mobileJson == null
        ? RoomCardAppearance.fromPreset(mobilePreset)
        : RoomCardAppearance.fromJson(mobileJson, fallback: RoomCardAppearance.fromPreset(mobilePreset), strict: true);
    final desktop = desktopJson == null
        ? RoomCardAppearance.fromPreset(desktopPreset)
        : RoomCardAppearance.fromJson(
            desktopJson,
            fallback: RoomCardAppearance.fromPreset(desktopPreset),
            strict: true,
          );
    return {
      'mobilePreset': _matchingPreset(mobile).storageKey,
      'desktopPreset': _matchingPreset(desktop).storageKey,
      'mobileConfig': mobile,
      'desktopConfig': desktop,
    };
  }

  static String? _readString(Map<String, dynamic> json, String key, {required String legacyKey}) {
    final value = json.containsKey(key) ? json[key] : json[legacyKey];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key must be a string');
    return value;
  }

  static Map<String, dynamic>? _readConfigMap(Map<String, dynamic> json, String key, {required String legacyKey}) {
    final value = json.containsKey(key) ? json[key] : json[legacyKey];
    if (value == null) return null;
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw FormatException('$key must be an object');
    }
    if (value is Map) return Map<String, dynamic>.from(value);
    throw FormatException('$key must be an object');
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    mobileConfig.value = parsed['mobileConfig'] as RoomCardAppearance;
    desktopConfig.value = parsed['desktopConfig'] as RoomCardAppearance;
    mobilePreset.v = parsed['mobilePreset'] as String;
    desktopPreset.v = parsed['desktopPreset'] as String;
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final parsed = parseConfig(rootConfig ?? const {});
    return {
      'mobilePreset': parsed['mobilePreset'],
      'desktopPreset': parsed['desktopPreset'],
      'mobileConfig': (parsed['mobileConfig'] as RoomCardAppearance).toJson(),
      'desktopConfig': (parsed['desktopConfig'] as RoomCardAppearance).toJson(),
    };
  }
}
