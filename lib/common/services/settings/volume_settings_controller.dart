import 'dart:io';
import 'dart:convert';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class VolumeSettingsController extends GetxController {
  final defaultMobileVolume = HiveRx.double('defaultMobileVolume', 0.5);
  final defaultDesktopVolume = HiveRx.double('defaultDesktopVolume', 1.0);
  final globalVolumeMute = HiveRx.bool('globalVolumeMute', false);
  final _roomVolumesRaw = HiveRx.string('roomVolumes', '{}');
  final rxRoomVolumes = <String, double>{}.obs;
  Map<String, double> get roomVolumes => rxRoomVolumes;

  set roomVolumes(Map<String, double> value) {
    rxRoomVolumes.assignAll(value);
    _roomVolumesRaw.v = jsonEncode(rxRoomVolumes);
  }

  @override
  void onInit() {
    super.onInit();
    try {
      final map = jsonDecode(_roomVolumesRaw.v) as Map<String, dynamic>;
      rxRoomVolumes.assignAll(map.map((k, v) => MapEntry(k, (v as num).toDouble())));
    } catch (_) {
      rxRoomVolumes.clear();
    }
  }

  void setRoomVolume(String roomId, double volume) {
    rxRoomVolumes[roomId] = volume.clamp(0.0, 1.0);
    _roomVolumesRaw.v = jsonEncode(rxRoomVolumes);
  }

  double get currentPlatformDefaultVolume {
    return Platform.isAndroid || Platform.isIOS ? defaultMobileVolume.v : defaultDesktopVolume.v;
  }

  void setCurrentPlatformDefaultVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
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
    defaultMobileVolume.v = json['defaultMobileVolume'] ?? 0.5;
    defaultDesktopVolume.v = json['defaultDesktopVolume'] ?? 1.0;
    globalVolumeMute.v = json['globalVolumeMute'] ?? false;

    if (json['roomVolumes'] != null) {
      final map = Map<String, dynamic>.from(json['roomVolumes']);
      rxRoomVolumes.assignAll(map.map((k, v) => MapEntry(k, (v as num).toDouble())));
      _roomVolumesRaw.v = jsonEncode(rxRoomVolumes);
    }
  }
}
