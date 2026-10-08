import 'package:rxdart/rxdart.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/models/refresh_config_model.dart';

class RefreshConfigController extends GetxController {
  static const int defaultRefreshInterval = 30;
  static const int minRefreshInterval = 5;
  static const int maxRefreshInterval = 360;
  static const int defaultMaxConcurrentRefresh = 4;
  static const int maxAllowedConcurrentRefresh = 20;

  static int normalizeRefreshInterval(int value) {
    return value.clamp(minRefreshInterval, maxRefreshInterval);
  }

  static int normalizeMaxConcurrentRefresh(Object? value) {
    final parsed = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
    return (parsed ?? defaultMaxConcurrentRefresh).clamp(1, maxAllowedConcurrentRefresh);
  }

  final RxBool autoRefreshFavorite = hiveBool('autoRefreshFavorite', false);
  // Foregrounding an existing process is the common Android interpretation of
  // "opening" the app. Default to a fresh status pass so cached live flags do
  // not survive indefinitely; users who prefer no foreground traffic can still
  // disable this independently from periodic refresh.
  final refreshFavoriteOnResume = hiveBool('refreshFavoriteOnResume', true);
  final RxInt autoRefreshInterval = hiveInt('autoRefreshInterval', defaultRefreshInterval);
  final RxInt maxConcurrentRefresh = hiveInt('maxConcurrentRefresh', defaultMaxConcurrentRefresh);
  final RxBool autoRefreshThumbnails = hiveBool('autoRefreshThumbnails', false);
  final RxInt thumbnailRefreshInterval = hiveInt('thumbnailRefreshInterval', defaultRefreshInterval);

  final _configStream = BehaviorSubject<RefreshConfig>();
  Stream<RefreshConfig> get configChanges => _configStream.stream;
  Worker? _configWorker;

  @override
  void onInit() {
    super.onInit();
    autoRefreshInterval.value = normalizeRefreshInterval(autoRefreshInterval.value);
    maxConcurrentRefresh.value = normalizeMaxConcurrentRefresh(maxConcurrentRefresh.value);
    thumbnailRefreshInterval.value = normalizeRefreshInterval(thumbnailRefreshInterval.value);
    _emitConfig();
    _configWorker = everAll([
      autoRefreshFavorite,
      refreshFavoriteOnResume,
      autoRefreshInterval,
      maxConcurrentRefresh,
      autoRefreshThumbnails,
      thumbnailRefreshInterval,
    ], (_) => _emitConfig());
  }

  void _emitConfig() {
    _configStream.add(
      RefreshConfig(
        autoRefreshFavorite: autoRefreshFavorite.value,
        refreshFavoriteOnResume: refreshFavoriteOnResume.value,
        autoRefreshInterval: autoRefreshInterval.value,
        maxConcurrentRefresh: maxConcurrentRefresh.value,
        autoRefreshThumbnails: autoRefreshThumbnails.value,
        thumbnailRefreshInterval: thumbnailRefreshInterval.value,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoRefreshFavorite': autoRefreshFavorite.v,
      'refreshFavoriteOnResume': refreshFavoriteOnResume.v,
      'autoRefreshInterval': autoRefreshInterval.v,
      'maxConcurrentRefresh': maxConcurrentRefresh.v,
      'autoRefreshThumbnails': autoRefreshThumbnails.v,
      'thumbnailRefreshInterval': thumbnailRefreshInterval.v,
    };
  }

  /// Parse the complete section without notifying observers or persisting values.
  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {
      'autoRefreshFavorite': (json['autoRefreshFavorite'] ?? false) as bool,
      'refreshFavoriteOnResume': (json['refreshFavoriteOnResume'] ?? true) as bool,
      'autoRefreshInterval': normalizeRefreshInterval((json['autoRefreshInterval'] ?? defaultRefreshInterval) as int),
      'maxConcurrentRefresh': normalizeMaxConcurrentRefresh(json['maxConcurrentRefresh']),
      'autoRefreshThumbnails': (json['autoRefreshThumbnails'] ?? false) as bool,
      'thumbnailRefreshInterval': normalizeRefreshInterval(
        (json['thumbnailRefreshInterval'] ?? defaultRefreshInterval) as int,
      ),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    autoRefreshFavorite.v = parsed['autoRefreshFavorite'];
    refreshFavoriteOnResume.v = parsed['refreshFavoriteOnResume'];
    autoRefreshInterval.v = parsed['autoRefreshInterval'];
    maxConcurrentRefresh.v = parsed['maxConcurrentRefresh'];
    autoRefreshThumbnails.v = parsed['autoRefreshThumbnails'];
    thumbnailRefreshInterval.v = parsed['thumbnailRefreshInterval'];
  }

  @override
  void onClose() {
    _configWorker?.dispose();
    _configStream.close();
    super.onClose();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final refresh = rootConfig?['refresh'] as Map<String, dynamic>? ?? {};
    return {
      'autoRefreshFavorite': refresh['autoRefreshFavorite'] ?? false,
      'refreshFavoriteOnResume': refresh['refreshFavoriteOnResume'] ?? true,
      'autoRefreshInterval': normalizeRefreshInterval(
        (refresh['autoRefreshInterval'] ?? defaultRefreshInterval) as int,
      ),
      'maxConcurrentRefresh': normalizeMaxConcurrentRefresh(refresh['maxConcurrentRefresh']),
      'autoRefreshThumbnails': refresh['autoRefreshThumbnails'] ?? false,
      'thumbnailRefreshInterval': normalizeRefreshInterval(
        (refresh['thumbnailRefreshInterval'] ?? defaultRefreshInterval) as int,
      ),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final refresh = Map<String, dynamic>.from(rootConfig['refresh'] ?? {});
    updateFields.forEach((k, v) => refresh[k] = v);
    rootConfig['refresh'] = refresh;
    return rootConfig;
  }
}
