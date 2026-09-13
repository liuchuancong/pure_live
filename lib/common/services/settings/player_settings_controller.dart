import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/player/utils/mpv_platform_profile.dart';
import 'package:pure_live/player/utils/player_consts.dart';

@visibleForTesting
String defaultVideoPlayerKeyForPlatform(TargetPlatform platform) => platform == TargetPlatform.iOS ? 'ijk' : 'mpv';

List<String> availableVideoPlayerKeysForPlatform(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS
    ? PlayerConsts.engines.keys.toList(growable: false)
    : const <String>['mpv'];

String normalizeVideoPlayerKeyForPlatform(String key, TargetPlatform platform) {
  final availableKeys = availableVideoPlayerKeysForPlatform(platform);
  if (availableKeys.contains(key)) return key;
  final fallback = defaultVideoPlayerKeyForPlatform(platform);
  return availableKeys.contains(fallback) ? fallback : availableKeys.first;
}

String get _defaultVideoPlayerKey => defaultVideoPlayerKeyForPlatform(defaultTargetPlatform);

class PlayerSettingsController extends GetxController {
  static const int defaultVideoFitIndex = 0;

  final List<Worker> _workers = [];
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
  final RxString portraitFullscreenDisplayModeName = hiveString(
    'portraitFullscreenDisplayMode',
    PortraitFullscreenDisplayMode.ambient.name,
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

  PortraitFullscreenDisplayMode get portraitFullscreenDisplayMode => _enumByName(
    PortraitFullscreenDisplayMode.values,
    portraitFullscreenDisplayModeName.v,
    PortraitFullscreenDisplayMode.ambient,
  );

  PortraitDanmakuMode get portraitDanmakuMode =>
      _enumByName(PortraitDanmakuMode.values, portraitDanmakuModeName.v, PortraitDanmakuMode.followGlobal);

  List<BoxFit> get videoFitArray => AppConsts().videoFitType.map((e) => e['attr'] as BoxFit).toList();
  int get resolvedVideoFitIndex => normalizeVideoFitIndex(videoFitIndex.v);
  String get resolvedVideoFitDescriptionKey {
    final options = AppConsts().videoFitType;
    return options.isEmpty ? '' : options[resolvedVideoFitIndex]['desc'] as String;
  }

  String get resolvedPreferResolution => normalizePreferredResolution(preferResolution.v);
  String get resolvedPreferResolutionCellular => normalizePreferredResolution(preferResolutionCellular.v);

  int? advanceVideoFitIndex() {
    final optionCount = videoFitArray.length;
    if (optionCount == 0) return null;
    final nextIndex = (resolvedVideoFitIndex + 1) % optionCount;
    videoFitIndex.v = nextIndex;
    return nextIndex;
  }

  @override
  void onInit() {
    super.onInit();
    _repairPlaybackPreferences();
    final normalizedPlayerKey = normalizeVideoPlayerKeyForPlatform(videoPlayerKey.v, defaultTargetPlatform);
    if (videoPlayerKey.v != normalizedPlayerKey) videoPlayerKey.v = normalizedPlayerKey;
    _normalizeMpvSettingsForPlatform(defaultTargetPlatform);
    _loadPortraitRoomOverrides(_portraitRoomOverridesRaw.v);
    _workers.addAll([
      ever<int>(videoFitIndex, (_) => _repairPlaybackPreferences()),
      ever<String>(preferResolution, (_) => _repairPlaybackPreferences()),
      ever<String>(preferResolutionCellular, (_) => _repairPlaybackPreferences()),
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

  static int normalizeVideoFitIndex(int value) {
    final optionCount = AppConsts().videoFitType.length;
    if (value < 0 || value >= optionCount) return defaultVideoFitIndex;
    return value;
  }

  static String normalizePreferredResolution(String value) {
    final normalized = value.trim();
    return PlayerConsts.resolutions.contains(normalized) ? normalized : PlayerConsts.resolutions.first;
  }

  void _repairPlaybackPreferences() {
    final fitIndex = resolvedVideoFitIndex;
    if (videoFitIndex.v != fitIndex) videoFitIndex.v = fitIndex;

    final wifiResolution = resolvedPreferResolution;
    if (preferResolution.v != wifiResolution) preferResolution.v = wifiResolution;

    final cellularResolution = resolvedPreferResolutionCellular;
    if (preferResolutionCellular.v != cellularResolution) preferResolutionCellular.v = cellularResolution;
  }

  void _normalizeMpvSettingsForPlatform(TargetPlatform platform) {
    if (platform != TargetPlatform.android && playerCompatMode.v) playerCompatMode.v = false;
    if (platform != TargetPlatform.windows && enableRtxVsr.v) enableRtxVsr.v = false;

    final normalizedVideoOutput = normalizeMpvVideoOutputDriverForPlatform(videoOutputDriver.v, platform);
    if (videoOutputDriver.v != normalizedVideoOutput) videoOutputDriver.v = normalizedVideoOutput;

    final normalizedAudioOutput = normalizeMpvAudioOutputDriverForPlatform(audioOutputDriver.v, platform);
    if (audioOutputDriver.v != normalizedAudioOutput) audioOutputDriver.v = normalizedAudioOutput;

    final normalizedHardwareDecoder = normalizeMpvHardwareDecoderForPlatform(videoHardwareDecoder.v, platform);
    if (videoHardwareDecoder.v != normalizedHardwareDecoder) videoHardwareDecoder.v = normalizedHardwareDecoder;
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
    portraitFullscreenDisplayModeName.v = PortraitFullscreenDisplayMode.ambient.name;
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
      final values = parsePortraitRoomOverrides(raw);
      portraitRoomOverrides.assignAll(values);
      _persistPortraitRoomOverrides();
    } catch (_) {
      portraitRoomOverrides.clear();
      _portraitRoomOverridesRaw.v = '{}';
    }
  }

  static Map<String, String> parsePortraitRoomOverrides(dynamic raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) throw const FormatException('Expected portrait room map');
    final values = <String, String>{};
    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      final value = entry.value.toString();
      if (key != ':' && PortraitOrientationOverride.values.any((item) => item.name == value)) {
        values[key] = value;
      }
    }
    return values;
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
    videoOutputDriver.v = defaultMpvVideoOutputDriverForPlatform(defaultTargetPlatform);
    audioOutputDriver.v = 'auto';
    videoHardwareDecoder.v = 'auto';
    enableRtxVsr.v = false;
    preferResolution.v = PlayerConsts.resolutions.first;
    preferResolutionCellular.v = PlayerConsts.resolutions.first;
    useHardStopOnExit.v = false;
  }

  Map<String, dynamic> toJson() {
    return {
      'videoFitIndex': resolvedVideoFitIndex,
      'videoPlayerKey': videoPlayerKey.v,
      'preferResolution': resolvedPreferResolution,
      'preferResolutionCellular': resolvedPreferResolutionCellular,
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
      'portraitFullscreenDisplayMode': portraitFullscreenDisplayMode.name,
      'portraitPipFollowSource': portraitPipFollowSource.v,
      'portraitDanmakuMode': portraitDanmakuMode.name,
      'rememberPortraitRoomOverride': rememberPortraitRoomOverride.v,
      'showPortraitDiagnostics': showPortraitDiagnostics.v,
      'portraitRoomOverrides': Map<String, String>.from(portraitRoomOverrides),
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    T typed<T>(dynamic value) => value as T;
    return {
      'portraitRoomOverrides': parsePortraitRoomOverrides(json['portraitRoomOverrides'] ?? '{}'),
      'videoFitIndex': normalizeVideoFitIndex(typed<int>(json['videoFitIndex'] ?? defaultVideoFitIndex)),
      'videoPlayerKey': normalizeVideoPlayerKeyForPlatform(
        typed<String>(json['videoPlayerKey'] ?? _defaultVideoPlayerKey),
        defaultTargetPlatform,
      ),
      'preferResolution': normalizePreferredResolution(
        typed<String>(json['preferResolution'] ?? PlayerConsts.resolutions.first),
      ),
      'preferResolutionCellular': normalizePreferredResolution(
        typed<String>(json['preferResolutionCellular'] ?? PlayerConsts.resolutions.first),
      ),
      'enableCodec': typed<bool>(json['enableCodec'] ?? true),
      'playerCompatMode': defaultTargetPlatform == TargetPlatform.android
          ? typed<bool>(json['playerCompatMode'] ?? false)
          : false,
      'customPlayerOutput': typed<bool>(json['customPlayerOutput'] ?? false),
      'videoOutputDriver': normalizeMpvVideoOutputDriverForPlatform(
        typed<String>(json['videoOutputDriver'] ?? defaultMpvVideoOutputDriverForPlatform(defaultTargetPlatform)),
        defaultTargetPlatform,
      ),
      'audioOutputDriver': normalizeMpvAudioOutputDriverForPlatform(
        typed<String>(json['audioOutputDriver'] ?? 'auto'),
        defaultTargetPlatform,
      ),
      'videoHardwareDecoder': normalizeMpvHardwareDecoderForPlatform(
        typed<String>(json['videoHardwareDecoder'] ?? 'auto'),
        defaultTargetPlatform,
      ),
      'floatPlay': typed<bool>(json['floatPlay'] ?? false),
      'windowsPipAlwaysOnTop': typed<bool>(json['windowsPipAlwaysOnTop'] ?? false),
      'enableRtxVsr': defaultTargetPlatform == TargetPlatform.windows
          ? typed<bool>(json['enableRtxVsr'] ?? false)
          : false,
      'audioOnly': typed<bool>(false),
      'useHardStopOnExit': typed<bool>(json['useHardStopOnExit'] ?? false),
      'enablePortraitStreamAdaptation': typed<bool>(json['enablePortraitStreamAdaptation'] ?? true),
      'portraitAdaptiveHeight': typed<bool>(json['portraitAdaptiveHeight'] ?? true),
      'portraitLayoutModeName': typed<String>(
        _enumName(PortraitLayoutMode.values, json['portraitLayoutMode'], PortraitLayoutMode.balanced),
      ),
      'portraitFullscreenPolicyName': typed<String>(
        _enumName(
          PortraitFullscreenPolicy.values,
          json['portraitFullscreenPolicy'],
          PortraitFullscreenPolicy.followSource,
        ),
      ),
      'portraitFullscreenDisplayModeName': typed<String>(
        _enumName(
          PortraitFullscreenDisplayMode.values,
          json['portraitFullscreenDisplayMode'],
          PortraitFullscreenDisplayMode.ambient,
        ),
      ),
      'portraitPipFollowSource': typed<bool>(json['portraitPipFollowSource'] ?? true),
      'portraitDanmakuModeName': typed<String>(
        _enumName(PortraitDanmakuMode.values, json['portraitDanmakuMode'], PortraitDanmakuMode.followGlobal),
      ),
      'rememberPortraitRoomOverride': typed<bool>(json['rememberPortraitRoomOverride'] ?? true),
      'showPortraitDiagnostics': typed<bool>(json['showPortraitDiagnostics'] ?? false),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    videoFitIndex.v = parsed['videoFitIndex'];
    videoPlayerKey.v = parsed['videoPlayerKey'];
    preferResolution.v = parsed['preferResolution'];
    preferResolutionCellular.v = parsed['preferResolutionCellular'];
    enableCodec.v = parsed['enableCodec'];
    playerCompatMode.v = parsed['playerCompatMode'];
    customPlayerOutput.v = parsed['customPlayerOutput'];
    videoOutputDriver.v = parsed['videoOutputDriver'];
    audioOutputDriver.v = parsed['audioOutputDriver'];
    videoHardwareDecoder.v = parsed['videoHardwareDecoder'];
    floatPlay.v = parsed['floatPlay'];
    windowsPipAlwaysOnTop.v = parsed['windowsPipAlwaysOnTop'];
    enableRtxVsr.v = parsed['enableRtxVsr'];
    audioOnly.v = parsed['audioOnly'];
    useHardStopOnExit.v = parsed['useHardStopOnExit'];
    enablePortraitStreamAdaptation.v = parsed['enablePortraitStreamAdaptation'];
    portraitAdaptiveHeight.v = parsed['portraitAdaptiveHeight'];
    portraitLayoutModeName.v = parsed['portraitLayoutModeName'];
    portraitFullscreenPolicyName.v = parsed['portraitFullscreenPolicyName'];
    portraitFullscreenDisplayModeName.v = parsed['portraitFullscreenDisplayModeName'];
    portraitPipFollowSource.v = parsed['portraitPipFollowSource'];
    portraitDanmakuModeName.v = parsed['portraitDanmakuModeName'];
    rememberPortraitRoomOverride.v = parsed['rememberPortraitRoomOverride'];
    showPortraitDiagnostics.v = parsed['showPortraitDiagnostics'];
    portraitRoomOverrides.assignAll(parsed['portraitRoomOverrides']);
    _persistPortraitRoomOverrides();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final player = rootConfig?['player'] as Map<String, dynamic>? ?? {};
    return {
      'videoFitIndex': normalizeVideoFitIndex((player['videoFitIndex'] ?? defaultVideoFitIndex) as int),
      'videoPlayerKey': normalizeVideoPlayerKeyForPlatform(
        (player['videoPlayerKey'] ?? _defaultVideoPlayerKey) as String,
        defaultTargetPlatform,
      ),
      'preferResolution': normalizePreferredResolution(
        (player['preferResolution'] ?? PlayerConsts.resolutions.first) as String,
      ),
      'preferResolutionCellular': normalizePreferredResolution(
        (player['preferResolutionCellular'] ?? PlayerConsts.resolutions.first) as String,
      ),
      'enableCodec': player['enableCodec'] ?? true,
      'playerCompatMode': defaultTargetPlatform == TargetPlatform.android ? player['playerCompatMode'] ?? false : false,
      'customPlayerOutput': player['customPlayerOutput'] ?? false,
      'videoOutputDriver': normalizeMpvVideoOutputDriverForPlatform(
        (player['videoOutputDriver'] ?? defaultMpvVideoOutputDriverForPlatform(defaultTargetPlatform)) as String,
        defaultTargetPlatform,
      ),
      'audioOutputDriver': normalizeMpvAudioOutputDriverForPlatform(
        (player['audioOutputDriver'] ?? 'auto') as String,
        defaultTargetPlatform,
      ),
      'videoHardwareDecoder': normalizeMpvHardwareDecoderForPlatform(
        (player['videoHardwareDecoder'] ?? 'auto') as String,
        defaultTargetPlatform,
      ),
      'floatPlay': player['floatPlay'] ?? false,
      'windowsPipAlwaysOnTop': player['windowsPipAlwaysOnTop'] ?? false,
      // Compatibility-only input for backups created before the ownership of
      // this setting moved to WindowSizeController. New exports store it in
      // the windowSize section.
      'rememberPipPosition': player['rememberPipPosition'] ?? true,
      'enableRtxVsr': defaultTargetPlatform == TargetPlatform.windows ? player['enableRtxVsr'] ?? false : false,
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
      'portraitFullscreenDisplayMode': _enumName(
        PortraitFullscreenDisplayMode.values,
        player['portraitFullscreenDisplayMode'],
        PortraitFullscreenDisplayMode.ambient,
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
