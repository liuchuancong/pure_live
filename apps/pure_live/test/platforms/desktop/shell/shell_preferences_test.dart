import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_shell/live_shell.dart' show CloseAction;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart';

/// What survives the trip to the box and back.
///
/// The store is the whole persistence story for the desktop shell's own
/// choices — the close prompt's "remember" and the title-bar mode — so its
/// decode rules (unknown ids fall back, a broken document keeps defaults and
/// reports instead of throwing) are the behaviour under test.
void main() {
  final storage = _MapRepository();
  late ShellPreferencesStore store;

  setUp(() {
    storage.reset();
    store = ShellPreferencesStore(repository: storage);
  });

  test('a fresh install keeps the defaults: no pinned strip, ask on every close', () async {
    await store.load();

    // Null is the "never picked" answer: the runner asks the operating system
    // which frame arrangement to use, so a Windows 10 to 11 upgrade re-asks.
    expect(store.value.windowChrome, isNull);
    expect(store.value.closeAction, isNull);
  });

  test('a round trip carries both choices', () async {
    await store.load();
    await store.update((preferences) => preferences.copyWith(windowChrome: ShellWindowChrome.system));
    await store.update((preferences) => preferences.copyWith(closeAction: CloseAction.hideToTray));

    final reloaded = ShellPreferencesStore(repository: storage);
    await reloaded.load();

    expect(reloaded.value.windowChrome, ShellWindowChrome.system);
    expect(reloaded.value.closeAction, CloseAction.hideToTray);
  });

  test('clearing the remembered close action returns the shell to asking', () async {
    await store.load();
    await store.update((preferences) => preferences.copyWith(closeAction: CloseAction.quit));
    await store.update((preferences) => preferences.copyWith(clearCloseAction: true));

    expect(store.value.closeAction, isNull);
  });

  test('an unknown stored identifier counts as never picked', () async {
    storage.documents[ShellKeys.document] = {'windowChrome': 'aurora', 'closeAction': 'maybe'};
    await store.load();

    expect(store.value.windowChrome, isNull);
    expect(store.value.closeAction, isNull);
  });

  test('a broken document keeps the defaults and reports, never throws', () async {
    var failures = 0;
    final failing = ShellPreferencesStore(repository: storage, onError: (failure, error, stack) => failures++);
    storage.documents[ShellKeys.document] = {'windowChrome': 42};
    await failing.load();

    expect(failing.value.windowChrome, isNull);
    expect(failures, 1);
  });

  test('a failed write still applies in memory and reports', () async {
    var failures = 0;
    final failing = ShellPreferencesStore(
      repository: _ThrowingRepository(),
      onError: (failure, error, stack) => failures++,
    );
    await failing.load();
    await failing.update((preferences) => preferences.copyWith(windowChrome: ShellWindowChrome.system));

    expect(failing.value.windowChrome, ShellWindowChrome.system);
    expect(failures, 1);
  });
}

/// An in-memory stand-in for the hive-backed repository.
final class _MapRepository implements StorageRepository<Map<dynamic, dynamic>> {
  final Map<String, Map<dynamic, dynamic>> documents = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void reset() => documents.clear();

  @override
  Stream<void> watch({String? key}) => _changes.stream;

  @override
  Map<dynamic, dynamic>? get(String key) => documents[key];

  @override
  Map<String, Map<dynamic, dynamic>> getMany(Iterable<String> keys) => {
    for (final key in keys)
      if (documents.containsKey(key)) key: documents[key]!,
  };

  @override
  List<Map<dynamic, dynamic>> getAll() => List.of(documents.values);

  @override
  Map<String, Map<dynamic, dynamic>> getAllEntries() => Map.of(documents);

  @override
  List<String> getAllKeys() => List.of(documents.keys);

  @override
  bool contains(String key) => documents.containsKey(key);

  @override
  bool containsAll(Iterable<String> keys) => keys.every(documents.containsKey);

  @override
  Future<void> save(String key, Map<dynamic, dynamic> value) async {
    documents[key] = value;
    _changes.add(null);
  }

  @override
  Future<void> saveAll(Map<String, Map<dynamic, dynamic>> values) async {
    documents.addAll(values);
    _changes.add(null);
  }

  @override
  Future<bool> insertIfAbsent(String key, Map<dynamic, dynamic> value) async {
    final inserted = !documents.containsKey(key);
    if (inserted) {
      documents[key] = value;
      _changes.add(null);
    }
    return inserted;
  }

  @override
  Future<bool> update(String key, Map<dynamic, dynamic> Function(Map<dynamic, dynamic> current) updater) async {
    if (!documents.containsKey(key)) {
      return false;
    }
    documents[key] = updater(documents[key]!);
    _changes.add(null);
    return true;
  }

  @override
  Future<void> delete(String key) async {
    documents.remove(key);
    _changes.add(null);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    keys.forEach(documents.remove);
    _changes.add(null);
  }

  @override
  Future<int> deleteWhere(bool Function(String key, Map<dynamic, dynamic> value) test) async {
    final doomed = [
      for (final entry in documents.entries)
        if (test(entry.key, entry.value)) entry.key,
    ]..forEach(documents.remove);
    _changes.add(null);
    return doomed.length;
  }

  @override
  int get count => documents.length;

  @override
  bool get isEmpty => documents.isEmpty;

  @override
  bool get isNotEmpty => documents.isNotEmpty;

  @override
  Future<void> clear() async {
    documents.clear();
    _changes.add(null);
  }

  @override
  Future<void> flush() async {}
}

/// A repository whose writes fail, for the report-don't-throw contract.
final class _ThrowingRepository extends _MapRepository {
  @override
  Future<void> save(String key, Map<dynamic, dynamic> value) async => throw StateError('disk full');
}
