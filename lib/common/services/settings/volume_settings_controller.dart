import 'dart:io';
import 'dart:convert';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class VolumeSettingsController extends GetxController {
  final HiveRxDouble defaultMobileVolume = HiveRxDouble('defaultMobileVolume', 0.5);
  final HiveRxDouble defaultDesktopVolume = HiveRxDouble('defaultDesktopVolume', 1.0);
  final HiveRxBool globalVolumeMute = HiveRxBool('globalVolumeMute', false);
  final HiveRxString _roomVolumesRaw = HiveRxString('roomVolumes', '{}');
  final RxMap<String, double> rxRoomVolumes = <String, double>{}.obs;
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
    defaultMobileVolume.v = (json['defaultMobileVolume'] as num?)?.toDouble() ?? 0.5;
    defaultDesktopVolume.v = (json['defaultDesktopVolume'] as num?)?.toDouble() ?? 1.0;
    globalVolumeMute.v = json['globalVolumeMute'] ?? false;
    final roomVolumesData = json['roomVolumes'];
    if (roomVolumesData == null) {
      rxRoomVolumes.clear();
      _roomVolumesRaw.v = '{}';
      return;
    }
    try {
      Map<String, dynamic> map;
      if (roomVolumesData is String) {
        map = Map<String, dynamic>.from(jsonDecode(roomVolumesData));
      } else if (roomVolumesData is Map) {
        map = Map<String, dynamic>.from(roomVolumesData);
      } else {
        map = {};
      }
      rxRoomVolumes.assignAll(map.map((k, v) => MapEntry(k, (v as num).toDouble())));
      _roomVolumesRaw.v = jsonEncode(rxRoomVolumes);
    } catch (_) {
      rxRoomVolumes.clear();
      _roomVolumesRaw.v = '{}';
    }
  }
}
