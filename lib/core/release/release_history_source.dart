import 'package:pure_live/core/models/release_model.dart';

/// GitHub Release 历史的来源接口。
///
/// Core 只认识这个签名：本地缓存、多镜像竞速拉取、APK 下载入口等实现细节属于
/// Features（features/about 的 ReleaseHistoryRepository）。实现由 App 装配层在
/// 启动时通过 [provider] 注入，Core 因此不会反向 import Features。
typedef ReleaseHistoryProvider = Future<List<ReleaseModel>> Function({bool forceRefresh});

abstract final class ReleaseHistorySource {
  static ReleaseHistoryProvider? provider;

  /// 未注入实现时返回空列表：更新检查仍可完成，只是拿不到逐版本资源清单。
  static Future<List<ReleaseModel>> load({bool forceRefresh = false}) async {
    final current = provider;
    if (current == null) return const <ReleaseModel>[];
    return current(forceRefresh: forceRefresh);
  }
}
