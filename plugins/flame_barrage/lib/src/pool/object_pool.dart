abstract class Poolable {
  void reset();
}

class ObjectPool<T extends Poolable> {
  ObjectPool(this._factory, {this.maxSize = 200});

  final T Function() _factory;
  final int maxSize;
  final List<T> _pool = [];

  T obtain() {
    return _pool.isNotEmpty ? _pool.removeLast() : _factory();
  }

  void recycle(T object) {
    object.reset();
    if (_pool.length < maxSize) {
      _pool.add(object);
    }
  }

  void clear() {
    _pool.clear();
  }
}
