import 'dart:collection';
import '../../src/model/barrage/barrage_item.dart';
import '../../src/model/barrage/barrage_entry.dart';

class BarragePool {
  BarragePool({required this.maxSize});

  int maxSize;
  final Queue<BarrageEntry> _pool = Queue<BarrageEntry>();

  int get currentSize => _pool.length;

  BarrageEntry obtain({required BarrageItem item, required int creationTime}) {
    if (_pool.isNotEmpty) {
      final entry = _pool.removeFirst();
      entry.reset(newItem: item, newCreationTime: creationTime);
      return entry;
    }
    return BarrageEntry(item: item, creationTime: creationTime);
  }

  void recycle(BarrageEntry entry) {
    if (_pool.length < maxSize) {
      _pool.addLast(entry);
    }
  }

  void updateMaxSize(int newMaxSize) {
    if (newMaxSize <= 0) return;
    maxSize = newMaxSize;
    while (_pool.length > maxSize && _pool.isNotEmpty) {
      _pool.removeFirst();
    }
  }

  void clear() {
    _pool.clear();
  }
}
