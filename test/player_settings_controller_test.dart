import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/player/utils/mpv_platform_profile.dart';
import 'package:pure_live/player/utils/player_consts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pure-live-player-settings-');
    Hive.init(hiveDirectory.path);
    await HivePrefUtil.init();
  });

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    debugDefaultTargetPlatformOverride = null;
    await HivePrefUtil.clear();
  });

  tearDown(() async {
    await HivePrefUtil.flush();
    Get.reset();
    Get.testMode = false;
    debugDefaultTargetPlatformOverride = null;
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('player settings migration', () {
    test('uses IJK only for a new iOS configuration', () {
      expect(defaultVideoPlayerKeyForPlatform(TargetPlatform.iOS), 'ijk');
      expect(defaultVideoPlayerKeyForPlatform(TargetPlatform.android), 'mpv');
      expect(defaultVideoPlayerKeyForPlatform(TargetPlatform.windows), 'mpv');
    });

    test('normalizes an old desktop IJK selection in imported and parsed settings', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final imported = PlayerSettingsController.extractConfig({
        'player': <String, dynamic>{'videoPlayerKey': 'ijk'},
      });
      final parsed = PlayerSettingsController.parseConfig(<String, dynamic>{'videoPlayerKey': 'ijk'});

      expect(imported['videoPlayerKey'], 'mpv');
      expect(parsed['videoPlayerKey'], 'mpv');
    });

    test('keeps supported mobile engines and replaces unknown selections with the platform default', () {
      expect(normalizeVideoPlayerKeyForPlatform('ijk', TargetPlatform.android), 'ijk');
      expect(normalizeVideoPlayerKeyForPlatform('missing', TargetPlatform.android), 'mpv');
      expect(normalizeVideoPlayerKeyForPlatform('missing', TargetPlatform.iOS), 'ijk');
      expect(availableVideoPlayerKeysForPlatform(TargetPlatform.windows), const <String>['mpv', 'fvp']);
    });

    test('normalizes Android-only and desktop MPV options imported on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final imported = PlayerSettingsController.extractConfig({
        'player': <String, dynamic>{
          'videoPlayerKey': 'mpv',
          'playerCompatMode': true,
          'customPlayerOutput': true,
          'videoOutputDriver': 'mediacodec_embed',
          'audioOutputDriver': 'wasapi',
          'videoHardwareDecoder': 'd3d11va',
          'enableRtxVsr': true,
        },
      });

      expect(imported['videoPlayerKey'], 'mpv');
      expect(imported['playerCompatMode'], isFalse);
      expect(imported['customPlayerOutput'], isTrue);
      expect(imported['videoOutputDriver'], 'libmpv');
      expect(imported['audioOutputDriver'], 'auto');
      expect(imported['videoHardwareDecoder'], 'auto');
      expect(imported['enableRtxVsr'], isFalse);
    });

    test('publishes an iOS MPV profile that keeps the Flutter texture and VideoToolbox choices', () {
      expect(mpvVideoOutputDriversForPlatform(TargetPlatform.iOS).keys, <String>['libmpv']);
      expect(mpvAudioOutputDriversForPlatform(TargetPlatform.iOS).keys, <String>['auto', 'audiounit', 'null']);
      expect(mpvHardwareDecodersForPlatform(TargetPlatform.iOS).keys, <String>[
        'auto',
        'auto-safe',
        'auto-copy',
        'no',
        'videotoolbox',
        'videotoolbox-copy',
      ]);
      expect(normalizeMpvVideoOutputDriverForPlatform('gpu', TargetPlatform.iOS), 'libmpv');
      expect(normalizeMpvHardwareDecoderForPlatform('videotoolbox', TargetPlatform.iOS), 'videotoolbox');
      expect(normalizeMpvHardwareDecoderForPlatform('mediacodec', TargetPlatform.iOS), 'auto');
    });

    test('publishes only Android audio outputs and prefers modern native backends with fallback', () {
      expect(mpvAudioOutputDriversForPlatform(TargetPlatform.android).keys, <String>[
        'auto',
        'audiotrack',
        'aaudio',
        'opensles',
        'null',
      ]);
      expect(normalizeMpvAudioOutputDriverForPlatform('wasapi', TargetPlatform.android), 'auto');
      expect(defaultMpvAudioOutputDriverForPlatform(TargetPlatform.android), 'audiotrack,aaudio,opensles,');
      expect(defaultMpvAudioOutputDriverForPlatform(TargetPlatform.linux), 'alsa');
      expect(defaultMpvAudioOutputDriverForPlatform(TargetPlatform.windows), isNull);
      expect(
        effectiveMpvAudioOutputDriverForPlatform(
          customOutput: true,
          configuredDriver: 'auto',
          platform: TargetPlatform.android,
        ),
        'audiotrack,aaudio,opensles,',
        reason:
            'Android automatic output must use the verified native fallback chain instead of a silent pseudo-driver',
      );
      expect(
        effectiveMpvAudioOutputDriverForPlatform(
          customOutput: true,
          configuredDriver: 'null',
          platform: TargetPlatform.android,
        ),
        'null',
      );
    });

    test('retires the legacy global audio-only default', () {
      final config = PlayerSettingsController.extractConfig({
        'player': <String, dynamic>{'audioOnly': true, 'floatPlay': true},
      });

      expect(config['audioOnly'], isFalse);
      expect(config['floatPlay'], isTrue);
    });

    test('keeps audio-only disabled for older backups without the field', () {
      final config = PlayerSettingsController.extractConfig({'player': <String, dynamic>{}});

      expect(config['audioOnly'], isFalse);
      expect(config['windowsPipAlwaysOnTop'], isFalse);
    });

    test('preserves the Windows mini-player stacking preference', () {
      final config = PlayerSettingsController.extractConfig({
        'player': <String, dynamic>{'windowsPipAlwaysOnTop': true},
      });

      expect(config['windowsPipAlwaysOnTop'], isTrue);
    });

    test('enables Windows mini-player geometry restore for old settings', () {
      final oldConfig = PlayerSettingsController.extractConfig({'player': <String, dynamic>{}});
      final optedOutConfig = PlayerSettingsController.extractConfig({
        'player': <String, dynamic>{'rememberPipPosition': false},
      });

      expect(oldConfig['rememberPipPosition'], isTrue);
      expect(optedOutConfig['rememberPipPosition'], isFalse);
    });

    test('migrates old backups to the safe portrait-source defaults', () {
      final config = PlayerSettingsController.extractConfig({'player': <String, dynamic>{}});

      expect(config['enablePortraitStreamAdaptation'], isTrue);
      expect(config['portraitAdaptiveHeight'], isTrue);
      expect(config['portraitLayoutMode'], 'balanced');
      expect(config['portraitFullscreenPolicy'], 'followSource');
      expect(config['portraitFullscreenDisplayMode'], 'ambient');
      expect(config['portraitPipFollowSource'], isTrue);
      expect(config['portraitDanmakuMode'], 'followGlobal');
      expect(config['portraitRoomOverrides'], isEmpty);
    });

    test('sanitizes invalid portrait enum names while retaining room overrides', () {
      final config = PlayerSettingsController.extractConfig({
        'player': <String, dynamic>{
          'portraitLayoutMode': 'broken',
          'portraitFullscreenPolicy': 'broken',
          'portraitFullscreenDisplayMode': 'broken',
          'portraitDanmakuMode': 'broken',
          'portraitRoomOverrides': <String, String>{'bilibili:1': 'portrait'},
        },
      });

      expect(config['portraitLayoutMode'], 'balanced');
      expect(config['portraitFullscreenPolicy'], 'followSource');
      expect(config['portraitFullscreenDisplayMode'], 'ambient');
      expect(config['portraitDanmakuMode'], 'followGlobal');
      expect(config['portraitRoomOverrides'], <String, String>{'bilibili:1': 'portrait'});
    });

    test('normalizes video fit and preferred quality in current and legacy backup paths', () {
      expect(PlayerSettingsController.normalizeVideoFitIndex(-1), 0);
      expect(PlayerSettingsController.normalizeVideoFitIndex(5), 5);
      expect(PlayerSettingsController.normalizeVideoFitIndex(6), 0);
      expect(PlayerSettingsController.normalizePreferredResolution('流畅'), '流畅');
      expect(PlayerSettingsController.normalizePreferredResolution('retired-quality'), PlayerConsts.resolutions.first);

      final parsed = PlayerSettingsController.parseConfig({
        'videoFitIndex': 99,
        'preferResolution': 'retired-wifi-quality',
        'preferResolutionCellular': 'retired-cellular-quality',
      });
      final extracted = PlayerSettingsController.extractConfig({
        'player': {'videoFitIndex': -4, 'preferResolution': 'retired-wifi-quality', 'preferResolutionCellular': '流畅'},
      });

      expect(parsed['videoFitIndex'], 0);
      expect(parsed['preferResolution'], PlayerConsts.resolutions.first);
      expect(parsed['preferResolutionCellular'], PlayerConsts.resolutions.first);
      expect(extracted['videoFitIndex'], 0);
      expect(extracted['preferResolution'], PlayerConsts.resolutions.first);
      expect(extracted['preferResolutionCellular'], '流畅');
      expect(() => PlayerSettingsController.parseConfig({'videoFitIndex': '5'}), throwsA(isA<TypeError>()));
      expect(() => PlayerSettingsController.parseConfig({'preferResolution': 42}), throwsA(isA<TypeError>()));
    });

    test('repairs invalid persisted playback preferences before their first consumer', () async {
      await HivePrefUtil.setInt('videoFitIndex', 99);
      await HivePrefUtil.setString('preferResolution', 'retired-wifi-quality');
      await HivePrefUtil.setString('preferResolutionCellular', 'retired-cellular-quality');

      final settings = Get.put(PlayerSettingsController());

      expect(settings.videoFitIndex.value, 0);
      expect(settings.resolvedVideoFitIndex, 0);
      expect(settings.preferResolution.value, PlayerConsts.resolutions.first);
      expect(settings.resolvedPreferResolution, PlayerConsts.resolutions.first);
      expect(settings.preferResolutionCellular.value, PlayerConsts.resolutions.first);
      expect(settings.resolvedPreferResolutionCellular, PlayerConsts.resolutions.first);

      await Future<void>.delayed(Duration.zero);
      await HivePrefUtil.flush();
      expect(HivePrefUtil.getInt('videoFitIndex'), 0);
      expect(HivePrefUtil.getString('preferResolution'), PlayerConsts.resolutions.first);
      expect(HivePrefUtil.getString('preferResolutionCellular'), PlayerConsts.resolutions.first);
    });

    test('repairs direct runtime writes and exports only canonical playback preferences', () async {
      final settings = Get.put(PlayerSettingsController());

      settings.videoFitIndex.value = -8;
      settings.preferResolution.value = 'runtime-wifi-quality';
      settings.preferResolutionCellular.value = 'runtime-cellular-quality';

      expect(settings.resolvedVideoFitIndex, 0);
      expect(settings.resolvedVideoFitDescriptionKey, 'video_fit_default');
      expect(settings.resolvedPreferResolution, PlayerConsts.resolutions.first);
      expect(settings.resolvedPreferResolutionCellular, PlayerConsts.resolutions.first);
      expect(settings.toJson(), containsPair('videoFitIndex', 0));
      expect(settings.toJson(), containsPair('preferResolution', PlayerConsts.resolutions.first));
      expect(settings.toJson(), containsPair('preferResolutionCellular', PlayerConsts.resolutions.first));
      expect(settings.advanceVideoFitIndex(), 1);
      expect(settings.videoFitIndex.value, 1);
      settings.videoFitIndex.value = 5;
      expect(settings.advanceVideoFitIndex(), 0);

      await Future<void>.delayed(Duration.zero);
      expect(settings.videoFitIndex.value, 0);
      expect(settings.preferResolution.value, PlayerConsts.resolutions.first);
      expect(settings.preferResolutionCellular.value, PlayerConsts.resolutions.first);
      await HivePrefUtil.flush();
      expect(HivePrefUtil.getInt('videoFitIndex'), 0);
      expect(HivePrefUtil.getString('preferResolution'), PlayerConsts.resolutions.first);
      expect(HivePrefUtil.getString('preferResolutionCellular'), PlayerConsts.resolutions.first);
    });
  });
}
