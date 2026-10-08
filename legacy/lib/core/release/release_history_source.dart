import 'package:pure_live/core/models/release_model.dart';

typedef ReleaseHistoryProvider = Future<List<ReleaseModel>> Function({bool forceRefresh});

abstract final class ReleaseHistorySource {
  static ReleaseHistoryProvider? provider;

  static Future<List<ReleaseModel>> load({bool forceRefresh = false}) async {
    final current = provider;
    if (current == null) return const <ReleaseModel>[];
    return current(forceRefresh: forceRefresh);
  }
}
