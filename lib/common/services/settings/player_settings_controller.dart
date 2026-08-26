import 'package:flutter/foundation.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';

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

  // Kept as an inert compatibility field for old backups.
  // Audio-only is now room-scoped and controlled by the headphone action
  // or ASMR auto-start.
  final RxBool audioOnly = false.obs;

  final RxBool useHardStopOnExit = hiveBool('useHardStopOnExit', false);

  // ---------------------------------------------------------------------------
  // Portrait live settings
  // ---------------------------------------------------------------------------

  /// Portrait stream layout mode.
  final RxString portraitLayoutModeName = hiveString('portraitLayoutMode', PortraitLayoutMode.balanced.name);

  PortraitLayoutMode get portraitLayoutMode =>
      _enumByName(PortraitLayoutMode.values, portraitLayoutModeName.v, PortraitLayoutMode.balanced);

  void changePortraitLayoutMode(PortraitLayoutMode mode) {
    portraitLayoutModeName.v = mode.name;
  }

  void resetPortraitLayoutMode() {
    portraitLayoutModeName.v = PortraitLayoutMode.balanced.name;
  }

  /// Portrait stream danmaku mode.
  final RxString portraitDanmakuModeName = hiveString('portraitDanmakuMode', PortraitDanmakuMode.followGlobal.name);

  PortraitDanmakuMode get portraitDanmakuMode =>
      _enumByName(PortraitDanmakuMode.values, portraitDanmakuModeName.v, PortraitDanmakuMode.followGlobal);

  void changePortraitDanmakuMode(PortraitDanmakuMode mode) {
    portraitDanmakuModeName.v = mode.name;
  }

  void resetPortraitDanmakuMode() {
    portraitDanmakuModeName.v = PortraitDanmakuMode.followGlobal.name;
  }

  // ---------------------------------------------------------------------------
  // Video fit
  // ---------------------------------------------------------------------------

  List<BoxFit> get videoFitArray => AppConsts().videoFitType.map((e) => e['attr'] as BoxFit).toList();

  // ---------------------------------------------------------------------------
  // Resolution
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

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

    // Portrait settings
    portraitLayoutModeName.v = PortraitLayoutMode.balanced.name;

    portraitDanmakuModeName.v = PortraitDanmakuMode.followGlobal.name;
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

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

      // Audio-only is intentionally not persisted as a global setting.
      'audioOnly': false,

      'useHardStopOnExit': useHardStopOnExit.v,

      // Portrait live
      'portraitLayoutMode': portraitLayoutMode.name,
      'portraitDanmakuMode': portraitDanmakuMode.name,
    };
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

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

    // Audio-only is intentionally not restored globally.
    audioOnly.v = false;

    useHardStopOnExit.v = json['useHardStopOnExit'] ?? false;

    // Portrait layout mode.
    portraitLayoutModeName.v = _enumName(
      PortraitLayoutMode.values,
      json['portraitLayoutMode'],
      PortraitLayoutMode.balanced,
    );

    // Portrait danmaku mode.
    portraitDanmakuModeName.v = _enumName(
      PortraitDanmakuMode.values,
      json['portraitDanmakuMode'],
      PortraitDanmakuMode.followGlobal,
    );
  }

  // ---------------------------------------------------------------------------
  // Config extraction
  // ---------------------------------------------------------------------------

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

      // Compatibility-only input for backups created before the ownership
      // of this setting moved to WindowSizeController.
      // New exports store it in the windowSize section.
      'rememberPipPosition': player['rememberPipPosition'] ?? true,

      'enableRtxVsr': player['enableRtxVsr'] ?? false,

      // Audio-only is intentionally not restored globally.
      'audioOnly': false,

      'useHardStopOnExit': player['useHardStopOnExit'] ?? false,

      // Portrait layout mode.
      'portraitLayoutMode': _enumName(
        PortraitLayoutMode.values,
        player['portraitLayoutMode'],
        PortraitLayoutMode.balanced,
      ),

      // Portrait danmaku mode.
      'portraitDanmakuMode': _enumName(
        PortraitDanmakuMode.values,
        player['portraitDanmakuMode'],
        PortraitDanmakuMode.followGlobal,
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Config merge
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final player = Map<String, dynamic>.from(rootConfig['player'] ?? {});

    updateFields.forEach((key, value) {
      player[key] = value;
    });

    rootConfig['player'] = player;

    return rootConfig;
  }

  // ---------------------------------------------------------------------------
  // Enum helpers
  // ---------------------------------------------------------------------------

  static T _enumByName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
    final name = raw?.toString();

    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }

    return fallback;
  }

  static String _enumName<T extends Enum>(List<T> values, dynamic raw, T fallback) {
    return _enumByName(values, raw, fallback).name;
  }
}
