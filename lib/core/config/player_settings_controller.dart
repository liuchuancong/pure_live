import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/consts/app_consts.dart';
import 'package:pure_live/core/player/core/portrait_stream_support.dart';
import 'package:pure_live/core/player/kernel/player_preset.dart';
import 'package:pure_live/core/player/super_resolution.dart';
import 'package:pure_live/core/player/kernel/mpv_platform_profile.dart';
import 'package:pure_live/core/player/kernel/player_consts.dart';

@visibleForTesting
/// mpv is the default engine on every platform: it has the widest codec
/// coverage, the recovery ladder works on it and the tuning table is
/// engine-spelled for it. ijk/exo stay selectable where available.
String defaultVideoPlayerKeyForPlatform(TargetPlatform platform) => 'mpv';

List<String> availableVideoPlayerKeysForPlatform(TargetPlatform platform) =>
    PlayerConsts.mobileOnlyEnginesAvailable(platform)
    ? PlayerConsts.engines.keys.toList(growable: false)
    // Desktop ships libmpv only; IJK and Exo are mobile-only.
    : const <String>['mpv'];

String normalizeVideoPlayerKeyForPlatform(String key, TargetPlatform platform) {
  final availableKeys = availableVideoPlayerKeysForPlatform(platform);
  if (availableKeys.contains(key)) return key;
  final fallback = defaultVideoPlayerKeyForPlatform(platform);
  return availableKeys.contains(fallback) ? fallback : availableKeys.first;
}

String get _defaultVideoPlayerKey => defaultVideoPlayerKeyForPlatform(defaultTargetPlatform);

class PlayerSettingsController extends GetxController {
  /// Player-layer hook, installed by PlayerKernelService at startup.
  ///
  /// Invoked whenever a live-appliable output setting changes. `rebuild`
  /// marks that the change cannot take effect on a running engine (the
  /// mpv render context is bound to the video output driver) and the
  /// engine must be rebuilt to pick it up.
  static void Function({required bool rebuild})? outputSettingsDispatcher;

  static const int defaultVideoFitIndex = 0;

  final List<Worker> _workers = [];
  final RxInt videoFitIndex = hiveInt('videoFitIndex', 0);
  final RxString videoPlayerKey = hiveString('videoPlayerKey', _defaultVideoPlayerKey);

  final RxString preferResolution = hiveString('preferResolution', PlayerConsts.resolutions.first);
  final RxString preferResolutionCellular = hiveString('preferResolutionCellular', PlayerConsts.resolutions.first);

  // ---------------------------------------------------------------------------
  // Engine x platform output segments
  //
  // Every engine keeps its own output settings per platform group. The map
  // is the single source of truth and lives under one hive key; the Rx
  // fields below are an in-memory projection of the segment for the
  // *current* engine and platform. Backups carry the whole map, so a
  // restore overwrites each platform's segment directly instead of
  // rerouting writes through the view fields.
  // ---------------------------------------------------------------------------

  static const String _engineOutputsKey = 'engineOutputs';

  /// Bumped on every segment write so preset/segment UI can react: the
  /// segments map itself is a plain in-memory structure, an [Obx] that
  /// only reads `currentPreset` would never rebuild.
  final RxInt outputSegmentRevision = 0.obs;

  final Map<String, Map<String, PlayerEngineOutput>> _engineOutputs = <String, Map<String, PlayerEngineOutput>>{};

  Map<String, PlayerEngineOutput> _segmentsOf(String engineKey) {
    return _engineOutputs.putIfAbsent(engineKey, () => <String, PlayerEngineOutput>{});
  }

  PlayerEngineOutput _segmentForCurrent() {
    return _segmentsOf(videoPlayerKey.v)[platformGroupName()] ?? const PlayerEngineOutput();
  }

  void _writeSegment(PlayerEngineOutput segment) {
    _segmentsOf(videoPlayerKey.v)[platformGroupName()] = segment;
    _persistSegments();
  }

  void _persistSegments() {
    outputSegmentRevision.v++;
    hiveString(_engineOutputsKey, '').v = jsonEncode(<String, dynamic>{
      for (final engine in _engineOutputs.entries)
        engine.key: <String, dynamic>{for (final segment in engine.value.entries) segment.key: segment.value.toJson()},
    });
  }

  void _loadSegments() {
    final raw = hiveString(_engineOutputsKey, '')();
    if (raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final engine in decoded.entries) {
        if (engine.value is! Map) continue;
        _segmentsOf(engine.key).addEntries([
          for (final platform in (engine.value as Map).entries)
            MapEntry(platform.key as String, PlayerEngineOutput.fromJson(platform.value)),
        ]);
      }
    } catch (_) {
      // A corrupt map resets to defaults; the view fields below then show
      // the balanced segment.
    }
  }

  /// Serialized form for backups: every engine x platform segment.
  Map<String, dynamic> engineOutputsToJson() => <String, dynamic>{
    for (final engine in _engineOutputs.entries)
      engine.key: <String, dynamic>{for (final segment in engine.value.entries) segment.key: segment.value.toJson()},
  };

  /// Restores segments from a backup. Platforms present in the backup are
  /// overwritten as a whole; platforms absent keep their local settings.
  void engineOutputsFromJson(Object? json) {
    if (json is! Map) return;

    for (final engine in json.entries) {
      if (engine.value is! Map) continue;
      _segmentsOf(engine.key as String).addEntries([
        for (final platform in (engine.value as Map).entries)
          MapEntry(platform.key as String, PlayerEngineOutput.fromJson(platform.value)),
      ]);
    }

    _persistSegments();
    reloadOutputView();
  }

  /// Reloads the view fields from the current engine x platform segment.
  void reloadOutputView() {
    final segment = _segmentForCurrent();
    enableCodec.v = segment.enableCodec;
    customPlayerOutput.v = segment.customPlayerOutput;
    videoOutputDriver.v = segment.videoOutputDriver;
    audioOutputDriver.v = segment.audioOutputDriver;
    videoHardwareDecoder.v = segment.videoHardwareDecoder;
    videoSync.v = segment.videoSync;
    interpolation.v = segment.interpolation == 'yes';
    scale.v = segment.scale;
    deinterlace.v = segment.deinterlace;
    hwdecCodecs.v = segment.hwdecCodecs;
    audioExclusive.v = segment.audioExclusive == 'yes';
  }

  /// Persists the view fields back into the current segment.
  void _persistOutputView() {
    _writeSegment(
      PlayerEngineOutput(
        presetId: _segmentForCurrent().presetId,
        enableCodec: enableCodec.v,
        customPlayerOutput: customPlayerOutput.v,
        videoOutputDriver: videoOutputDriver.v,
        videoHardwareDecoder: videoHardwareDecoder.v,
        audioOutputDriver: audioOutputDriver.v,
      ),
    );
  }

  /// Applies a one-click preset to the current engine x platform segment.
  void applyPreset(PlayerPresetId id) {
    final detail = id.outputOverride;
    final segment = _segmentForCurrent().copyWith(
      presetId: id,
      enableCodec: detail.enableCodec,
      // A preset that pins hwdec alone (RTX: d3d11va) needs the custom-output
      // gate armed as well, otherwise the pick never reaches the engine.
      customPlayerOutput: detail.vo != null || detail.hwdec != null,
      videoOutputDriver: detail.vo ?? 'auto',
      videoHardwareDecoder: detail.hwdec ?? 'auto-safe',
    );

    _writeSegment(segment);
    reloadOutputView();
  }

  /// The preset currently active on the current engine x platform.
  PlayerPresetId get currentPreset => _segmentForCurrent().presetId;

  // In-memory projection of the current segment; never persisted directly.
  late final RxBool enableCodec = true.obs;
  late final RxBool customPlayerOutput = false.obs;
  late final RxString videoOutputDriver = 'auto'.obs;
  late final RxString audioOutputDriver = 'auto'.obs;
  late final RxString videoHardwareDecoder = 'auto-safe'.obs;
  late final RxString videoSync = 'audio'.obs;
  late final RxBool interpolation = false.obs;
  late final RxString scale = 'lanczos'.obs;
  late final RxString deinterlace = 'auto'.obs;
  late final RxString hwdecCodecs = 'all'.obs;
  late final RxBool audioExclusive = false.obs;

  PlayerSettingsController() {
    _loadSegments();
    reloadOutputView();
    void persist() => _persistOutputView();
    enableCodec.listen((_) => persist());
    customPlayerOutput.listen((_) => persist());
    videoOutputDriver.listen((_) => persist());
    audioOutputDriver.listen((_) => persist());
    videoHardwareDecoder.listen((_) => persist());
    _installOutputDispatcher();
    videoSync.listen((_) => persist());
    interpolation.listen((_) => persist());
    scale.listen((_) => persist());
    deinterlace.listen((_) => persist());
    hwdecCodecs.listen((_) => persist());
    audioExclusive.listen((_) => persist());
  }

  final RxBool floatPlay = hiveBool('floatPlay', false);

  /// 应用内悬浮窗记住的位置与尺寸（横竖屏各一套），JSON 编码。
  ///
  /// 坐标是应用表面内的逻辑坐标；`media_core_floating` 在恢复时会按当前表面重新夹取，
  /// 所以旋转或改变窗口大小之后不会把悬浮窗丢到看不见的地方。
  final RxString floatWindowGeometry = hiveString('floatWindowGeometry', '');
  final RxBool windowsPipAlwaysOnTop = hiveBool('windowsPipAlwaysOnTop', false);

  /// 小窗是否可以不按视频比例自由拉伸（仅 Windows 小窗）。
  ///
  /// 默认关闭时小窗始终等于视频形状，画面没有黑边；开启后可以单独压扁或拉窄窗口，
  /// 画面按比例适配，在不等的一侧留黑边。
  final RxBool windowsPipFreeAspect = hiveBool('windowsPipFreeAspect', false);

  /// Compact-window size policy. [windowsPipBaseSize] is the long side of the
  /// small window for landscape streams (the height for portrait ones); the
  /// short side always follows the video's aspect.
  ///
  /// [windowsPipMinWidth] / [windowsPipMinHeight] are the floor the viewer can
  /// drag the compact window down to: `media_core_pip` applies them as the
  /// window's minimum size for the duration of the small window and restores
  /// the host's normal minimum on exit. They only affect the small window.
  final RxDouble windowsPipBaseSize = hiveDouble('windowsPipBaseSize', 360.0);
  final RxDouble windowsPipMinWidth = hiveDouble('windowsPipMinWidth', 140.0);
  final RxDouble windowsPipMinHeight = hiveDouble('windowsPipMinHeight', 90.0);
  // Kept as an inert compatibility field for old backups. Audio-only is now
  // room-scoped and controlled by the headphone action or ASMR auto-start.
  final RxBool audioOnly = false.obs;
  final RxBool useHardStopOnExit = hiveBool('useHardStopOnExit', false);

  /// Anime4K super-resolution mode (Windows/desktop GPUs only).
  final RxString superResolutionMode = hiveString('superResolutionMode', SuperResolutionMode.off.name);

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

  /// Previous values of the render-context settings, to tell a live
  /// property update apart from one that needs an engine rebuild.
  String _lastVo = 'libmpv';
  bool _lastCustomOutput = false;

  void _installOutputDispatcher() {
    void dispatch() {
      final hook = outputSettingsDispatcher;
      if (hook == null) return;

      final voChanged = videoOutputDriver.v != _lastVo || customPlayerOutput.v != _lastCustomOutput;
      _lastVo = videoOutputDriver.v;
      _lastCustomOutput = customPlayerOutput.v;

      hook(rebuild: voChanged);
    }

    enableCodec.listen((_) => dispatch());
    videoHardwareDecoder.listen((_) => dispatch());
    videoOutputDriver.listen((_) => dispatch());
    customPlayerOutput.listen((_) => dispatch());
  }

  void _normalizeMpvSettingsForPlatform(TargetPlatform platform) {
    // mpv has no 'auto' value for --video-sync; its default is 'audio'.
    // Migrate segments saved while the settings page spelled it 'auto'.
    if (videoSync.v == 'auto') videoSync.v = 'audio';

    final normalizedVideoOutput = normalizeMpvVideoOutputDriverForPlatform(videoOutputDriver.v, platform);
    if (videoOutputDriver.v != normalizedVideoOutput) videoOutputDriver.v = normalizedVideoOutput;

    final normalizedAudioOutput = normalizeMpvAudioOutputDriverForPlatform(audioOutputDriver.v, platform);
    if (audioOutputDriver.v != normalizedAudioOutput) audioOutputDriver.v = normalizedAudioOutput;

    final normalizedHardwareDecoder = normalizeMpvHardwareDecoderForPlatform(videoHardwareDecoder.v, platform);
    if (videoHardwareDecoder.v != normalizedHardwareDecoder) videoHardwareDecoder.v = normalizedHardwareDecoder;
  }

  PortraitOrientationOverride portraitOverrideForRoom(LiveRoom? liveroom) {
    if (liveroom == null || liveroom.identityKey == ':') return PortraitOrientationOverride.automatic;
    final value = _sessionPortraitRoomOverrides[liveroom.identityKey] ?? portraitRoomOverrides[liveroom.identityKey];
    return _enumByName(PortraitOrientationOverride.values, value, PortraitOrientationOverride.automatic);
  }

  void setPortraitOverrideForRoom(LiveRoom liveroom, PortraitOrientationOverride value, {required bool remember}) {
    final key = liveroom.identityKey;
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
    customPlayerOutput.v = false;
    videoOutputDriver.v = defaultMpvVideoOutputDriverForPlatform(defaultTargetPlatform);
    audioOutputDriver.v = 'auto';
    videoHardwareDecoder.v = 'auto';
    preferResolution.v = PlayerConsts.resolutions.first;
    preferResolutionCellular.v = PlayerConsts.resolutions.first;
    useHardStopOnExit.v = false;
  }

  Map<String, dynamic> toJson() {
    return {
      'engineOutputs': engineOutputsToJson(),
      'videoFitIndex': resolvedVideoFitIndex,
      'videoPlayerKey': videoPlayerKey.v,
      'preferResolution': resolvedPreferResolution,
      'preferResolutionCellular': resolvedPreferResolutionCellular,
      'enableCodec': enableCodec.v,
      'customPlayerOutput': customPlayerOutput.v,
      'videoOutputDriver': videoOutputDriver.v,
      'audioOutputDriver': audioOutputDriver.v,
      'videoHardwareDecoder': videoHardwareDecoder.v,
      'floatPlay': floatPlay.v,
      'floatWindowGeometry': floatWindowGeometry.v,
      'windowsPipAlwaysOnTop': windowsPipAlwaysOnTop.v,
      'windowsPipFreeAspect': windowsPipFreeAspect.v,
      'windowsPipBaseSize': windowsPipBaseSize.v,
      'windowsPipMinWidth': windowsPipMinWidth.v,
      'windowsPipMinHeight': windowsPipMinHeight.v,
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
      'floatWindowGeometry': typed<String>(json['floatWindowGeometry']?.toString() ?? ''),
      'windowsPipAlwaysOnTop': typed<bool>(json['windowsPipAlwaysOnTop'] ?? false),
      'windowsPipFreeAspect': typed<bool>(json['windowsPipFreeAspect'] ?? false),
      'windowsPipBaseSize': typed<double>((json['windowsPipBaseSize'] ?? 360.0).toDouble().clamp(200.0, 720.0)),
      'windowsPipMinWidth': typed<double>((json['windowsPipMinWidth'] ?? 140.0).toDouble().clamp(100.0, 320.0)),
      'windowsPipMinHeight': typed<double>((json['windowsPipMinHeight'] ?? 90.0).toDouble().clamp(60.0, 240.0)),
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
    customPlayerOutput.v = parsed['customPlayerOutput'];
    videoOutputDriver.v = parsed['videoOutputDriver'];
    audioOutputDriver.v = parsed['audioOutputDriver'];
    videoHardwareDecoder.v = parsed['videoHardwareDecoder'];
    floatPlay.v = parsed['floatPlay'];
    floatWindowGeometry.v = parsed['floatWindowGeometry'];
    windowsPipAlwaysOnTop.v = parsed['windowsPipAlwaysOnTop'];
    windowsPipFreeAspect.v = parsed['windowsPipFreeAspect'];
    windowsPipBaseSize.v = parsed['windowsPipBaseSize'];
    windowsPipMinWidth.v = parsed['windowsPipMinWidth'];
    windowsPipMinHeight.v = parsed['windowsPipMinHeight'];
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
    engineOutputsFromJson(json['engineOutputs']);
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
      'floatWindowGeometry': player['floatWindowGeometry']?.toString() ?? '',
      'windowsPipAlwaysOnTop': player['windowsPipAlwaysOnTop'] ?? false,
      'windowsPipFreeAspect': player['windowsPipFreeAspect'] ?? false,
      // Compatibility-only input for backups created before the ownership of
      // this setting moved to WindowSizeController. New exports store it in
      // the windowSize section.
      'rememberPipPosition': player['rememberPipPosition'] ?? true,
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
