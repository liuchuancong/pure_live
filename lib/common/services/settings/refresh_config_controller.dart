import 'package:rxdart/rxdart.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/medels/refresh_config_model.dart';

class RefreshConfigController extends GetxController {
  final RxBool autoRefreshFavorite = hiveBool('autoRefreshFavorite', false);
  final RxInt autoRefreshInterval = hiveInt('autoRefreshInterval', 30);
  final RxInt maxConcurrentRefresh = hiveInt('maxConcurrentRefresh', 2);

  final _configStream = BehaviorSubject<RefreshConfig>();
  Stream<RefreshConfig> get configChanges => _configStream.stream;

  @override
  void onInit() {
    super.onInit();
    everAll([autoRefreshFavorite, autoRefreshInterval, maxConcurrentRefresh], (_) {
      _configStream.add(
        RefreshConfig(
          autoRefreshFavorite: autoRefreshFavorite.value,
          autoRefreshInterval: autoRefreshInterval.value,
          maxConcurrentRefresh: maxConcurrentRefresh.value,
        ),
      );
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'autoRefreshFavorite': autoRefreshFavorite.v,
      'autoRefreshInterval': autoRefreshInterval.v,
      'maxConcurrentRefresh': maxConcurrentRefresh.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    autoRefreshFavorite.v = json['autoRefreshFavorite'] ?? false;
    autoRefreshInterval.v = json['autoRefreshInterval'] ?? 30;
    maxConcurrentRefresh.v = json['maxConcurrentRefresh'] ?? 2;
  }

  @override
  void onClose() {
    _configStream.close();
    super.onClose();
  }
}
