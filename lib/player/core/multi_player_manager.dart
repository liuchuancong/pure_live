import 'package:pure_live/player/core/player_manager.dart';

class MultiPlayerManager {
  final Map<String, PlayerManager> _managers = {};

  final PlayerManager Function() factory;

  MultiPlayerManager({required this.factory});

  PlayerManager get(String id) {
    return _managers.putIfAbsent(id, factory);
  }

  PlayerManager? find(String id) {
    return _managers[id];
  }

  Future<void> remove(String id) async {
    final manager = _managers.remove(id);

    if (manager != null) {
      await manager.dispose();
    }
  }

  Future<void> disposeAll() async {
    final managers = List<PlayerManager>.from(_managers.values);
    _managers.clear();
    await Future.wait(managers.map((manager) => manager.dispose()));
  }
}
