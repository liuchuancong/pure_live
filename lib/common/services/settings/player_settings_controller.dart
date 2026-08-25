import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/player/utils/player_consts.dart';

@visibleForTesting
String defaultVideoPlayerKeyForPlatform(TargetPlatform platform) => platform == TargetPlatform.iOS ? 'ijk' : 'mpv';

String get _defaultVideoPlayerKey => defaultVideoPlayerKeyForPlatform(defaultTargetPlatform);

class PlayerSettingsController extends GetxController {
  final RxInt videoFitIndex = hiveInt('videoFitIndex', 0);
  final RxString videoPlayerKey = hiveString('videoPlayerKey', _defaultVideoPlayerKey);

  final RxString preferResolution = hiveString('preferResolution', PlayerConsts.resolutions.first);
  final RxString preferResolutionCellular = hiveString('preferResolutionCellular', PlayerConsts.resolutions.first);

  final RxBool enableCodec = hiveBool('enableCodec', true);
  final RxBool playerCompatMode = hiveBool('playerCompatMode', false);
  final RxBool customPlayerOutput = hiveBool('customPlayerOutput', false);
  final RxString videoOutputDriver = hiveString('videoOutputDriver', 'gpu');
  final RxString audioOutputDriver = hiveString('audioOutputDriver', 'auto');
  final RxString videoHardwareDecoder = hiveString('videoHardwareDecoder', 'auto');

  final RxBool floatPlay = hiveBool('floatPlay', false);
  final RxBool windowsPipAlwaysOnTop = hiveBool('windowsPipAlwaysOnTop', false);
  final RxBool enableRtxVsr = hiveBool('enableRtxVsr', false);
  // Kept as an inert compatibility field for old backups. Audio-only is now
  // room-scoped and controlled by the headphone action or ASMR auto-start.
  final RxBool audioOnly = false.obs;
  final RxBool useHardStopOnExit = hiveBool('useHardStopOnExit', false);

  // Portrait-source presentation. These are deliberately separate from the
  // device orientation and from the global danmaku style.
  final RxBool enablePortraitStreamAdaptation = hiveBool('enablePortraitStreamAdaptation', true);
  final RxBool portraitAdaptiveHeight = hiveBool('portraitAdaptiveHeight', true);
  final RxString portraitLayoutModeName = hiveString('portraitLayoutMode', PortraitLayoutMode.balanced.name);
  final RxString portraitFullscreenPolicyName = hiveString(
    'portraitFullscreenPolicy',
    PortraitFullscreenPolicy.followSource.name,
  );
  final RxBool portraitPipFollowSource = hiveBool('portraitPipFollowSource', true);
  final RxString portraitDanmakuModeName = hiveString('portraitDanmakuMode', PortraitDanmakuMode.followGlobal.name);
  final RxBool rememberPortraitRoomOverride = hiveBool('rememberPortraitRoomOverride', true);
  final RxBool showPortraitDiagnostics = hiveBool('showPortraitDiagnostics', false);
  final RxString _portraitRoomOverridesRaw = hiveString('portraitRoomOverrides', '{}');
  final RxMap<String, String> portraitRoomOverrides = <String, String>{}.obs;
  final RxMap<String, String> _sessionPortraitRoomOverrides = <String, String>{}.obs;

  PortraitLayoutMode get portraitLayoutMode =>
      _enumByName(PortraitLayoutMode.values, portraitLayoutModeName.v, PortraitLayoutMode.balanced);

  PortraitFullscreenPolicy get portraitFullscreenPolicy => _enumByName(
    PortraitFullscreenPolicy.values,
    portraitFullscreenPolicyName.v,
    PortraitFullscreenPolicy.followSource,
  );

  PortraitDanmakuMode get portraitDanmakuMode =>
      _enumByName(PortraitDanmakuMode.values, portraitDanmakuModeName.v, PortraitDanmakuMode.followGlobal);

  List<BoxFit> get videoFitArray => AppConsts().videoFitType.map((e) => e['attr'] as BoxFit).toList();

  @override
  void onInit() {
    super.onInit();
    _loadPortraitRoomOverrides(_portraitRoomOverridesRaw.v);
  }

  PortraitOrientationOverride portraitOverrideForRoom(LiveRoom? room) {
    if (room == null || room.identityKey == ':') return PortraitOrientationOverride.automatic;
    final value = _sessionPortraitRoomOverrides[room.identityKey] ?? portraitRoomOverrides[room.identityKey];
    return _enumByName(PortraitOrientationOverride.values, value, PortraitOrientationOverride.automatic);
  }

  void setPortraitOverrideForRoom(LiveRoom room, PortraitOrientationOverride value, {required bool remember}) {
    final key = room.identityKey;
    if (key == ':') return;
    _sessionPortraitRoomOverrides.remove(key);
    if (value == PortraitOrientationOverride.automatic) {
      portraitRoomOverrides.remove(key);
      _persistPortraitRoomOverrides();
      return;
    }
    if (remember) {
      portraitRoomOverrides.remove(key);
      portraitRoomOverrides[key] = value.name;
      while (portraitRoomOverrides.length > 300) {
        portraitRoomOverrides.remove(portraitRoomOverrides.keys.first);
      }
      _persistPortraitRoomOverrides();
    } else {
      portraitRoomOverrides.remove(key);
      _persistPortraitRoomOverrides();
      _sessionPortraitRoomOverrides[key] = value.name;
    }
  }

  void resetPortraitStreamSettings() {
    enablePortraitStreamAdaptation.v = true;
    portraitAdaptiveHeight.v = true;
    portraitLayoutModeName.v = PortraitLayoutMode.balanced.name;
    portraitFullscreenPolicyName.v = PortraitFullscreenPolicy.followSource.name;
    portraitPipFollowSource.v = true;
    portraitDanmakuModeName.v = PortraitDanmakuMode.followGlobal.name;
    rememberPortraitRoomOverride.v = true;
    showPortraitDiagnostics.v = false;
    portraitRoomOverrides.clear();
    _sessionPortraitRoomOverrides.clear();
    _persistPortraitRoomOverrides();
  }

  void _loadPortraitRoomOverrides(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) throw const FormatException('Expected map');
      final values = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final value = entry.value.toString();
        if (key != ':' && PortraitOrientationOverride.values.any((item) => item.name == value)) {
          values[key] = value;
        }
      }
      portraitRoomOverrides.assignAll(values);
      _persistPortraitRoomOverrides();
    } catch (_) {
      portraitRoomOverrides.clear();
      _portraitRoomOverridesRaw.v = '{}';
    }
  }

  void _persistPortraitRoomOverrides() {
    _portraitRoomOverridesRaw.v = jsonEncode(portraitRoomOverrides);
  }

  void changePreferResolution(String resolution) {
    if (PlayerConsts.resolutions.contains(resolution)) {
      preferResolution.v = resolution;
    }
  }

  void changePreferResolutionCellular(String resolution) {
    if (PlayerConsts.resolutions.contains(resolution)) {
      preferResolutionCellular.v = resolution;
    }
  }

  void resetMpvPlayerSettings() {
    enableCodec.v = true;
    playerCompatMode.v = false;
    customPlayerOutput.v = false;
    videoOutputDriver.v = 'gpu';
    audioOutputDriver.v = 'auto';
    videoHardwareDecoder.v = 'auto';
    enableRtxVsr.v = false;
    preferResolution.v = PlayerConsts.resolutions.first;
    preferResolutionCellular.v = PlayerConsts.resolutions.first;
    useHardStopOnExit.v = false;
  }

  Map<String, dynamic> toJson() {
    return {
      'videoFitIndex': videoFitIndex.v,
      'videoPlayerKey': videoPlayerKey.v,
      'preferResolution': preferResolution.v,
      'preferResolutionCellular': preferResolutionCellular.v,
      'enableCodec': enableCodec.v,
      'playerCompatMode': playerCompatMode.v,
      'customPlayerOutput': customPlayerOutput.v,
      'videoOutputDriver': videoOutputDriver.v,
      'audioOutputDriver': audioOutputDriver.v,
      'videoHardwareDecoder': videoHardwareDecoder.v,
      'floatPlay': floatPlay.v,
      'windowsPipAlwaysOnTop': windowsPipAlwaysOnTop.v,
      'enableRtxVsr': enableRtxVsr.v,
      'audioOnly': false,
      'useHardStopOnExit': useHardStopOnExit.v,
      'enablePortraitStreamAdaptation': enablePortraitStreamAdaptation.v,
      'portraitAdaptiveHeight': portraitAdaptiveHeight.v,
      'portraitLayoutMode': portraitLayoutMode.name,
      'portraitFullscreenPolicy': portraitFullscreenPolicy.name,
      'portraitPipFollowSource': portraitPipFollowSource.v,
      'portraitDanmakuMode': portraitDanmakuMode.name,
      'rememberPortraitRoomOverride': rememberPortraitRoomOverride.v,
      'showPortraitDiagnostics': showPortraitDiagnostics.v,
      'portraitRoomOverrides': Map<String, String>.from(portraitRoomOverrides),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    videoFitIndex.v = json['videoFitIndex'] ?? 0;
    videoPlayerKey.v = json['videoPlayerKey'] ?? _defaultVideoPlayerKey;
    preferResolution.v = json['preferResolution'] ?? PlayerConsts.resolutions.first;
    preferResolutionCellular.v = json['preferResolutionCellular'] ?? PlayerConsts.resolutions.first;
    enableCodec.v = json['enableCodec'] ?? true;
    playerCompatMode.v = json['playerCompatMode'] ?? false;
    customPlayerOutput.v = json['customPlayerOutput'] ?? false;
    videoOutputDriver.v = json['videoOutputDriver'] ?? 'gpu';
    audioOutputDriver.v = json['audioOutputDriver'] ?? 'auto';
    videoHardwareDecoder.v = json['videoHardwareDecoder'] ?? 'auto';
    floatPlay.v = json['floatPlay'] ?? false;
    windowsPipAlwaysOnTop.v = json['windowsPipAlwaysOnTop'] ?? false;
    enableRtxVsr.v = json['enableRtxVsr'] ?? false;
    audioOnly.v = false;
    useHardStopOnExit.v = json['useHardStopOnExit'] ?? false;
    enablePortraitStreamAdaptation.v = json['enablePortraitStreamAdaptation'] ?? true;
    portraitAdaptiveHeight.v = json['portraitAdaptiveHeight'] ?? true;
    portraitLayoutModeName.v = _enumName(
      PortraitLayoutMode.values,
      json['portraitLayoutMode'],
      PortraitLayoutMode.balanced,
    );
    portraitFullscreenPolicyName.v = _enumName(
      PortraitFullscreenPolicy.values,
      json['portraitFullscreenPolicy'],
      PortraitFullscreenPolicy.followSource,
    );
    portraitPipFollowSource.v = json['portraitPipFollowSource'] ?? true;
    portraitDanmakuModeName.v = _enumName(
      PortraitDanmakuMode.values,
      json['portraitDanmakuMode'],
      PortraitDanmakuMode.followGlobal,
    );
    rememberPortraitRoomOverride.v = json['rememberPortraitRoomOverride'] ?? true;
    showPortraitDiagnostics.v = json['showPortraitDiagnostics'] ?? false;
    _loadPortraitRoomOverrides(json['portraitRoomOverrides'] ?? '{}');
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final player = rootConfig?['player'] as Map<String, dynamic>? ?? {};
    return {
      'videoFitIndex': player['videoFitIndex'] ?? 0,
      'videoPlayerKey': player['videoPlayerKey'] ?? _defaultVideoPlayerKey,
      'preferResolution': player['preferResolution'] ?? PlayerConsts.resolutions.first,
      'preferResolutionCellular': player['preferResolutionCellular'] ?? PlayerConsts.resolutions.first,
      'enableCodec': player['enableCodec'] ?? true,
      'playerCompatMode': player['playerCompatMode'] ?? false,
      'customPlayerOutput': player['customPlayerOutput'] ?? false,
      'videoOutputDriver': player['videoOutputDriver'] ?? 'gpu',
      'audioOutputDriver': player['audioOutputDriver'] ?? 'auto',
      'videoHardwareDecoder': player['videoHardwareDecoder'] ?? 'auto',
      'floatPlay': player['floatPlay'] ?? false,
      'windowsPipAlwaysOnTop': player['windowsPipAlwaysOnTop'] ?? false,
      // Compatibility-only input for backups created before the ownership of
      // this setting moved to WindowSizeController. New exports store it in
      // the windowSize section.
      'rememberPipPosition': player['rememberPipPosition'] ?? true,
      'enableRtxVsr': player['enableRtxVsr'] ?? false,
      'audioOnly': false,
      'useHardStopOnExit': player['useHardStopOnExit'] ?? false,
      'enablePortraitStreamAdaptation': player['enablePortraitStreamAdaptation'] ?? true,
      'portraitAdaptiveHeight': player['portraitAdaptiveHeight'] ?? true,
      'portraitLayoutMode': _enumName(
        PortraitLayoutMode.values,
        player['portraitLayoutMode'],
        PortraitLayoutMode.balanced,
      ),
      'portraitFullscreenPolicy': _enumName(
        PortraitFullscreenPolicy.values,
        player['portraitFullscreenPolicy'],
        PortraitFullscreenPolicy.followSource,
      ),
      'portraitPipFollowSource': player['portraitPipFollowSource'] ?? true,
      'portraitDanmakuMode': _enumName(
        PortraitDanmakuMode.values,
        player['portraitDanmakuMode'],
        PortraitDanmakuMode.followGlobal,
      ),
      'rememberPortraitRoomOverride': player['rememberPortraitRoomOverride'] ?? true,
      'showPortraitDiagnostics': player['showPortraitDiagnostics'] ?? false,
      'portraitRoomOverrides': player['portraitRoomOverrides'] ?? {},
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final player = Map<String, dynamic>.from(rootConfig['player'] ?? {});
    updateFields.forEach((k, v) => player[k] = v);
    rootConfig['player'] = player;
    return rootConfig;
  }
}

T _enumByName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

String _enumName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  return _enumByName(values, raw, fallback).name;
}
