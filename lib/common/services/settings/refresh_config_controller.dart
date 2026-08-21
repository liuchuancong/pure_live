import 'package:rxdart/rxdart.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/medels/refresh_config_model.dart';

class RefreshConfigController extends GetxController {
  final RxBool autoRefreshFavorite = hiveBool('autoRefreshFavorite', false);
  final RxInt autoRefreshInterval = hiveInt('autoRefreshInterval', 30);
  final RxInt maxConcurrentRefresh = hiveInt('maxConcurrentRefresh', 2);
  final RxBool autoRefreshThumbnails = hiveBool('autoRefreshThumbnails', false);
  final RxInt thumbnailRefreshInterval = hiveInt('thumbnailRefreshInterval', 30);

  final _configStream = BehaviorSubject<RefreshConfig>();
  Stream<RefreshConfig> get configChanges => _configStream.stream;
  Worker? _configWorker;

  @override
  void onInit() {
    super.onInit();
    _emitConfig();
    _configWorker = everAll([
      autoRefreshFavorite,
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
      'autoRefreshInterval': autoRefreshInterval.v,
      'maxConcurrentRefresh': maxConcurrentRefresh.v,
      'autoRefreshThumbnails': autoRefreshThumbnails.v,
      'thumbnailRefreshInterval': thumbnailRefreshInterval.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    autoRefreshFavorite.v = json['autoRefreshFavorite'] ?? false;
    autoRefreshInterval.v = json['autoRefreshInterval'] ?? 30;
    maxConcurrentRefresh.v = json['maxConcurrentRefresh'] ?? 2;
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
      'autoRefreshInterval': refresh['autoRefreshInterval'] ?? 30,
      'maxConcurrentRefresh': refresh['maxConcurrentRefresh'] ?? 2,
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
