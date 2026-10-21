import 'dart:math';

/// How the queue moves on.
enum PlayMode {
  /// In order; the last item wraps to the first.
  sequence,

  /// The current item again when it ends; a manual next still moves on.
  repeatOne,

  /// A shuffled order that plays every item once before reshuffling.
  shuffle;

  /// The mode a mode button cycles to.
  PlayMode get next => switch (this) {
    sequence => repeatOne,
    repeatOne => shuffle,
    shuffle => sequence,
  };
}

/// What [PlayQueue.playNext] did.
enum PlayNextResult {
  /// Added after the current item.
  inserted,

  /// Was elsewhere in the queue; moved after the current item.
  moved,

  /// Already next; nothing changed.
  alreadyNext,

  /// The queue was empty; the item is now the only one.
  started,
}

/// The play queue of the music page and of a multi-part video, without a
/// player: items, the current one, and how "next" and "previous" move.
///
/// Shuffle walks a shuffled order — every item once, then a new order whose
/// first item is not the one just played — so a song never repeats before the
/// others have played and "previous" goes back along the order heard.
/// Consecutive failures are counted here, so the player layer can stop after
/// [failureBudget] without owning the rule.
final class PlayQueue<T> {
  /// An empty queue; [idOf] gives an item's identity.
  ///
  /// The mode is set through the `mode` setter — a queue starts in
  /// [PlayMode.sequence], and a caller that wants shuffle sets it before
  /// [replace], which then opens the order on the first item.
  new({required this.idOf, this.wrap = true, Random? random}) : _mode = PlayMode.sequence, _random = random ?? Random();

  /// The queue of [items], with [start] current and [mode] in force.
  factory of(
    Iterable<T> items, {
    required String Function(T item) idOf,
    int start = 0,
    bool wrap = true,
    PlayMode mode = PlayMode.sequence,
  }) => PlayQueue<T>(idOf: idOf, wrap: wrap)
    ..mode = mode
    ..replace(items, start: start);

  /// Identity of an item; equal ids are the same item.
  final String Function(T item) idOf;

  /// Whether next after the last item begins again (music) or ends (parts).
  final bool wrap;

  /// How many failures in a row end the queue.
  static const int failureBudget = 5;

  final Random _random;
  final List<T> _items = [];
  final List<int> _order = [];
  int _index = -1;
  PlayMode _mode;
  int _failures = 0;

  /// Items in list order.
  List<T> get items => List.unmodifiable(_items);

  /// The current item's index; -1 when the queue is empty.
  int get index => _index;

  /// The current item.
  T? get current => _index >= 0 && _index < _items.length ? _items[_index] : null;

  /// Whether there is anything to play.
  bool get isNotEmpty => _items.isNotEmpty;

  /// The mode.
  PlayMode get mode => _mode;

  set mode(PlayMode value) {
    if (value == _mode) {
      return;
    }
    _mode = value;
    if (value == PlayMode.shuffle) {
      _reshuffle(keepCurrentFirst: true);
    }
  }

  /// The failures counted since the last success.
  int get failures => _failures;

  /// Replaces the queue with [items] and starts at [start].
  void replace(Iterable<T> items, {int start = 0}) {
    _items
      ..clear()
      ..addAll(_unique(items));
    _index = _items.isEmpty ? -1 : start.clamp(0, _items.length - 1);
    _failures = 0;
    _reshuffle(keepCurrentFirst: true);
  }

  /// Puts [item] right after the current one.
  PlayNextResult playNext(T item) {
    if (_items.isEmpty) {
      replace([item]);
      return PlayNextResult.started;
    }
    final existing = _find(item);
    if (existing == _index || existing == _index + 1) {
      return PlayNextResult.alreadyNext;
    }
    if (existing >= 0) {
      _items.removeAt(existing);
      if (existing < _index) {
        _index--;
      }
    }
    _items.insert(_index + 1, item);
    _reshuffle(keepCurrentFirst: true);
    return existing >= 0 ? PlayNextResult.moved : PlayNextResult.inserted;
  }

  /// Appends [item]; false when it is already queued. An empty queue starts
  /// with it.
  bool enqueue(T item) {
    if (_find(item) >= 0) {
      return false;
    }
    _items.add(item);
    if (_index < 0) {
      _index = 0;
    }
    if (_mode == PlayMode.shuffle) {
      final at = _order.indexOf(_index) + 1 + _random.nextInt(max(1, _order.length - _order.indexOf(_index)));
      _order.insert(at.clamp(0, _order.length), _items.length - 1);
    } else {
      _order.add(_items.length - 1);
    }
    return true;
  }

  /// Removes [item]; when it was current the next one becomes current.
  bool remove(T item) {
    final at = _find(item);
    if (at < 0) {
      return false;
    }
    _items.removeAt(at);
    _order.removeWhere((value) => value == at);
    for (var i = 0; i < _order.length; i++) {
      if (_order[i] > at) {
        _order[i]--;
      }
    }
    if (_items.isEmpty) {
      _index = -1;
    } else if (at < _index) {
      _index--;
    } else if (at == _index && _index >= _items.length) {
      _index = _items.length - 1;
    }
    return true;
  }

  /// Moves to the next item; null when the queue ends (no wrap) or is empty.
  T? next() {
    if (_items.isEmpty) {
      return null;
    }
    if (_mode == PlayMode.repeatOne && _failures == 0) {
      return current;
    }
    final at = _order.indexOf(_index);
    final following = at + 1;
    if (following >= _order.length) {
      if (!wrap) {
        return null;
      }
      _reshuffle(keepCurrentFirst: false);
      _index = _order.isEmpty ? -1 : _order.first;
      return current;
    }
    _index = _order[following];
    return current;
  }

  /// Moves to the previous item; null when there is none before it.
  T? previous() {
    if (_items.isEmpty) {
      return null;
    }
    final at = _order.indexOf(_index);
    if (at <= 0) {
      return null;
    }
    _index = _order[at - 1];
    return current;
  }

  /// Jumps to the item at list position [at].
  T? jumpTo(int at) {
    if (at < 0 || at >= _items.length) {
      return null;
    }
    _index = at;
    return current;
  }

  /// Records the current item's outcome: a success clears the failure count,
  /// a failure counts toward the budget.
  void settled({required bool failed}) => _failures = failed ? _failures + 1 : 0;

  /// Whether the failure budget is spent — the player should stop instead of
  /// skipping again.
  bool get spent => _failures >= min(_items.isEmpty ? 1 : _items.length, failureBudget);

  /// A new shuffled order; the current item leads when asked, and a fresh
  /// order never opens with the item just played.
  void _reshuffle({required bool keepCurrentFirst}) {
    final natural = List<int>.generate(_items.length, (i) => i);
    if (_mode != PlayMode.shuffle) {
      // Sequence and repeat-one walk the list's own order; only shuffle
      // invents one.
      _order
        ..clear()
        ..addAll(natural);
      return;
    }
    final played = _index;
    final order = [...natural]..shuffle(_random);
    if (keepCurrentFirst && _index >= 0) {
      order
        ..remove(_index)
        ..insert(0, _index);
    } else if (!keepCurrentFirst && order.length > 1 && order.first == played) {
      order
        ..removeAt(0)
        ..insert(1, played);
    }
    _order
      ..clear()
      ..addAll(order);
  }

  Iterable<T> _unique(Iterable<T> items) {
    final seen = <String>{};
    return items.where((item) => seen.add(idOf(item)));
  }

  int _find(T item) {
    final id = idOf(item);
    return _items.indexWhere((other) => idOf(other) == id);
  }
}
