import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class PlayerSettingsController extends GetxController {
  final HiveRxInt videoFitIndex = HiveRxInt('videoFitIndex', 0);
  final HiveRxString videoPlayerKey = HiveRxString('videoPlayerKey', 'mpv');

  final HiveRxString preferResolution = HiveRxString('preferResolution', PlayerConsts.resolutions.first);
  final HiveRxString preferResolutionCellular = HiveRxString(
    'preferResolutionCellular',
    PlayerConsts.resolutions.first,
  );

  final HiveRxBool enableCodec = HiveRxBool('enableCodec', true);
  final HiveRxBool playerCompatMode = HiveRxBool('playerCompatMode', false);
  final HiveRxBool customPlayerOutput = HiveRxBool('customPlayerOutput', false);
  final HiveRxString videoOutputDriver = HiveRxString('videoOutputDriver', 'gpu');
  final HiveRxString audioOutputDriver = HiveRxString('audioOutputDriver', 'auto');
  final HiveRxString videoHardwareDecoder = HiveRxString('videoHardwareDecoder', 'auto');

  final HiveRxBool floatPlay = HiveRxBool('floatPlay', false);
  final HiveRxBool audioOnly = HiveRxBool('audioOnly', false);
  final HiveRxBool useHardStopOnExit = HiveRxBool('useHardStopOnExit', false);

  List<BoxFit> get videoFitArray => const [
    BoxFit.contain,
    BoxFit.cover,
    BoxFit.fill,
    BoxFit.fitWidth,
    BoxFit.fitHeight,
  ];

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
