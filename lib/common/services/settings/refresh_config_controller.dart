import 'package:rxdart/rxdart.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/medels/refresh_config_model.dart';

class RefreshConfigController extends GetxController {
  static const int defaultMaxConcurrentRefresh = 4;
  static const int maxAllowedConcurrentRefresh = 20;

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
  final RxInt autoRefreshInterval = hiveInt('autoRefreshInterval', 30);
  final RxInt maxConcurrentRefresh = hiveInt('maxConcurrentRefresh', defaultMaxConcurrentRefresh);
  final RxBool autoRefreshThumbnails = hiveBool('autoRefreshThumbnails', false);
  final RxInt thumbnailRefreshInterval = hiveInt('thumbnailRefreshInterval', 30);

  final _configStream = BehaviorSubject<RefreshConfig>();
  Stream<RefreshConfig> get configChanges => _configStream.stream;
  Worker? _configWorker;

  @override
  void onInit() {
    super.onInit();
    maxConcurrentRefresh.value = normalizeMaxConcurrentRefresh(maxConcurrentRefresh.value);
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

  void fromJson(Map<String, dynamic> json) {
    autoRefreshFavorite.v = json['autoRefreshFavorite'] ?? false;
    refreshFavoriteOnResume.v = json['refreshFavoriteOnResume'] ?? true;
    autoRefreshInterval.v = json['autoRefreshInterval'] ?? 30;
    maxConcurrentRefresh.v = normalizeMaxConcurrentRefresh(json['maxConcurrentRefresh']);
    autoRefreshThumbnails.v = json['autoRefreshThumbnails'] ?? false;
    thumbnailRefreshInterval.v = json['thumbnailRefreshInterval'] ?? 30;
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
      'autoRefreshInterval': refresh['autoRefreshInterval'] ?? 30,
      'maxConcurrentRefresh': normalizeMaxConcurrentRefresh(refresh['maxConcurrentRefresh']),
      'autoRefreshThumbnails': refresh['autoRefreshThumbnails'] ?? false,
      'thumbnailRefreshInterval': refresh['thumbnailRefreshInterval'] ?? 30,
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final refresh = Map<String, dynamic>.from(rootConfig['refresh'] ?? {});
    updateFields.forEach((k, v) => refresh[k] = v);
    rootConfig['refresh'] = refresh;
    return rootConfig;
  }
}
