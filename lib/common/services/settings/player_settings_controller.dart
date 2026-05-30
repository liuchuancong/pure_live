import 'package:pure_live/common/index.dart';
import 'package:pure_live/player/utils/player_consts.dart';

class PlayerSettingsController extends GetxController {
  final RxInt videoFitIndex = hiveInt('videoFitIndex', 0);
  final RxString videoPlayerKey = hiveString('videoPlayerKey', 'mpv');

  final RxString preferResolution = hiveString('preferResolution', PlayerConsts.resolutions.first);
  final RxString preferResolutionCellular = hiveString(
    'preferResolutionCellular',
    PlayerConsts.resolutions.first,
  );

  final RxBool enableCodec = hiveBool('enableCodec', true);
  final RxBool playerCompatMode = hiveBool('playerCompatMode', false);
  final RxBool customPlayerOutput = hiveBool('customPlayerOutput', false);
  final RxString videoOutputDriver = hiveString('videoOutputDriver', 'gpu');
  final RxString audioOutputDriver = hiveString('audioOutputDriver', 'auto');
  final RxString videoHardwareDecoder = hiveString('videoHardwareDecoder', 'auto');

  final RxBool floatPlay = hiveBool('floatPlay', false);
  final RxBool audioOnly = hiveBool('audioOnly', false);
  final RxBool useHardStopOnExit = hiveBool('useHardStopOnExit', false);

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
