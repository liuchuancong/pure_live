import 'dart:io';
import 'dart:convert';

import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/storage/hive_rx.dart';

class VolumeSettingsController extends GetxController {
  final RxDouble defaultMobileVolume = hiveDouble('defaultMobileVolume', 0.5);
  final RxDouble defaultDesktopVolume = hiveDouble('defaultDesktopVolume', 1.0);
  final RxBool globalVolumeMute = hiveBool('globalVolumeMute', false);
  final RxString _roomVolumesRaw = hiveString('roomVolumes', '{}');
  final RxMap<String, double> rxRoomVolumes = <String, double>{}.obs;
  Map<String, double> get roomVolumes => rxRoomVolumes;

  set roomVolumes(Map<String, double> value) {
    final normalized = <String, double>{};
    for (final entry in value.entries) {
      if (!entry.value.isFinite) {
        throw ArgumentError.value(entry.value, entry.key, 'Room volume must be finite');
      }
      normalized[entry.key] = entry.value.clamp(0.0, 1.0).toDouble();
    }
    rxRoomVolumes.assignAll(normalized);
    _roomVolumesRaw.v = jsonEncode(rxRoomVolumes);
  }

  @override
  void onInit() {
    super.onInit();
    final mobile = normalizeVolume(defaultMobileVolume.v, fallback: 0.5);
    final desktop = normalizeVolume(defaultDesktopVolume.v, fallback: 1.0);
    if (!defaultMobileVolume.v.isFinite || defaultMobileVolume.v != mobile) defaultMobileVolume.v = mobile;
    if (!defaultDesktopVolume.v.isFinite || defaultDesktopVolume.v != desktop) defaultDesktopVolume.v = desktop;
    try {
      final parsed = parseRoomVolumes(_roomVolumesRaw.v);
      rxRoomVolumes.assignAll(parsed);
      final normalizedRaw = jsonEncode(parsed);
      if (_roomVolumesRaw.v != normalizedRaw) _roomVolumesRaw.v = normalizedRaw;
    } catch (_) {
      rxRoomVolumes.clear();
      _roomVolumesRaw.v = '{}';
    }
  }

  void setRoomVolume(String roomId, double volume) {
    if (!volume.isFinite) return;
    rxRoomVolumes[roomId] = volume.clamp(0.0, 1.0).toDouble();
    _roomVolumesRaw.v = jsonEncode(rxRoomVolumes);
  }

  double get currentPlatformDefaultVolume {
    return Platform.isAndroid || Platform.isIOS
        ? normalizeVolume(defaultMobileVolume.v, fallback: 0.5)
        : normalizeVolume(defaultDesktopVolume.v, fallback: 1.0);
  }

  void setCurrentPlatformDefaultVolume(double volume) {
    if (!volume.isFinite) return;
    final v = volume.clamp(0.0, 1.0).toDouble();
    if (Platform.isAndroid || Platform.isIOS) {
      defaultMobileVolume.v = v;
    } else {
      defaultDesktopVolume.v = v;
    }
  }

  void resetVolumeToDefault() {
    defaultMobileVolume.v = 0.5;
    defaultDesktopVolume.v = 1.0;
    globalVolumeMute.v = false;
    rxRoomVolumes.clear();
    _roomVolumesRaw.v = '{}';
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultMobileVolume': defaultMobileVolume.v,
      'defaultDesktopVolume': defaultDesktopVolume.v,
      'globalVolumeMute': globalVolumeMute.v,
      'roomVolumes': rxRoomVolumes,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    defaultMobileVolume.v = parsed.mobile;
    defaultDesktopVolume.v = parsed.desktop;
    globalVolumeMute.v = parsed.mute;
    rxRoomVolumes.assignAll(parsed.volumes);
    _roomVolumesRaw.v = jsonEncode(parsed.volumes);
  }

  static ({double mobile, double desktop, bool mute, Map<String, double> volumes}) parseConfig(
    Map<String, dynamic> json,
  ) {
    final mobile = _parseVolume(json['defaultMobileVolume'], fallback: 0.5);
    final desktop = _parseVolume(json['defaultDesktopVolume'], fallback: 1.0);
    final mute = json['globalVolumeMute'] as bool? ?? false;
    final volumes = parseRoomVolumes(json['roomVolumes']);
    return (mobile: mobile, desktop: desktop, mute: mute, volumes: volumes);
  }

  static double normalizeVolume(double value, {required double fallback}) {
    if (!value.isFinite) return fallback;
    return value.clamp(0.0, 1.0).toDouble();
  }

  static double _parseVolume(dynamic value, {required double fallback}) {
    if (value == null) return fallback;
    if (value is! num) throw const FormatException('Invalid default volume');
    final parsed = value.toDouble();
    if (!parsed.isFinite) throw const FormatException('Invalid default volume');
    return parsed.clamp(0.0, 1.0).toDouble();
  }

  /// Parse before changing Rx values: malformed imports must not erase volumes.
  static Map<String, double> parseRoomVolumes(dynamic data) {
    if (data == null) return {};
    final decoded = data is String ? jsonDecode(data) : data;
    if (decoded is! Map) throw const FormatException('Invalid roomVolumes');
    final result = <String, double>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (entry.key is! String || value is! num || !value.isFinite) {
        throw const FormatException('Invalid roomVolumes entry');
      }
      result[entry.key as String] = value.toDouble().clamp(0.0, 1.0).toDouble();
    }
    return result;
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final volume = rootConfig?['volume'] as Map<String, dynamic>? ?? {};
    return {
      'defaultMobileVolume': (volume['defaultMobileVolume'] ?? 0.5).toDouble(),
      'defaultDesktopVolume': (volume['defaultDesktopVolume'] ?? 1.0).toDouble(),
      'globalVolumeMute': volume['globalVolumeMute'] ?? false,
      'roomVolumes': volume['roomVolumes'] ?? {},
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final volume = Map<String, dynamic>.from(rootConfig['volume'] ?? {});
    updateFields.forEach((k, v) => volume[k] = v);
    rootConfig['volume'] = volume;
    return rootConfig;
  }
}
