import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class PlayerSettingsController extends GetxController {
  // 基础设置
  final videoFitIndex = HiveRx.int('videoFitIndex', 0);
  final videoPlayerKey = HiveRx.string('videoPlayerKey', 'mpv');

  // 画质
  final preferResolution = HiveRx.string('preferResolution', PlayerConsts.resolutions.first);
  final preferResolutionCellular = HiveRx.string('preferResolutionCellular', PlayerConsts.resolutions.first);

  // MPV/解码相关
  final enableCodec = HiveRx.bool('enableCodec', true);
  final playerCompatMode = HiveRx.bool('playerCompatMode', false);
  final customPlayerOutput = HiveRx.bool('customPlayerOutput', false);
  final videoOutputDriver = HiveRx.string('videoOutputDriver', 'gpu');
  final audioOutputDriver = HiveRx.string('audioOutputDriver', 'auto');
  final videoHardwareDecoder = HiveRx.string('videoHardwareDecoder', 'auto');

  // 播放行为
  final floatPlay = HiveRx.bool('floatPlay', false);
  final audioOnly = HiveRx.bool('audioOnly', false);
  final useHardStopOnExit = HiveRx.bool('useHardStopOnExit', false);

  // 画面适配列表
  List<BoxFit> get videoFitArray => const [
    BoxFit.contain,
    BoxFit.cover,
    BoxFit.fill,
    BoxFit.fitWidth,
    BoxFit.fitHeight,
  ];

  // WiFi画质
  void changePreferResolution(String resolution) {
    if (PlayerConsts.resolutions.contains(resolution)) {
      preferResolution.v = resolution;
    }
  }

  // 移动数据画质
  void changePreferResolutionCellular(String resolution) {
    if (PlayerConsts.resolutions.contains(resolution)) {
      preferResolutionCellular.v = resolution;
    }
  }

  // ✅ 重置MPV相关设置（你要的这个）
  void resetMpvPlayerSettings() {
    enableCodec.v = true;
    playerCompatMode.v = false;
    customPlayerOutput.v = false;
    videoOutputDriver.v = 'gpu';
    audioOutputDriver.v = 'auto';
    videoHardwareDecoder.v = 'auto';
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
      'audioOnly': audioOnly.v,
      'useHardStopOnExit': useHardStopOnExit.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    videoFitIndex.v = json['videoFitIndex'] ?? 0;
    videoPlayerKey.v = json['videoPlayerKey'] ?? 'mpv';
    preferResolution.v = json['preferResolution'] ?? PlayerConsts.resolutions.first;
    preferResolutionCellular.v = json['preferResolutionCellular'] ?? PlayerConsts.resolutions.first;
    enableCodec.v = json['enableCodec'] ?? true;
    playerCompatMode.v = json['playerCompatMode'] ?? false;
    customPlayerOutput.v = json['customPlayerOutput'] ?? false;
    videoOutputDriver.v = json['videoOutputDriver'] ?? 'gpu';
    audioOutputDriver.v = json['audioOutputDriver'] ?? 'auto';
    videoHardwareDecoder.v = json['videoHardwareDecoder'] ?? 'auto';
    floatPlay.v = json['floatPlay'] ?? false;
    audioOnly.v = json['audioOnly'] ?? false;
    useHardStopOnExit.v = json['useHardStopOnExit'] ?? false;
  }
}
