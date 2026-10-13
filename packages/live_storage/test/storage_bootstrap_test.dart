import 'dart:io';

import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

/// `StorageBootstrap` is the only thing that decides whether the app has a usable
/// database, so these cases target the promises its own documentation makes: one
/// shared initialization under concurrency, a retryable failure, and a shutdown
/// that really resets.
void main() {
  late Directory storageDir;

  setUp(() {
    storageDir = Directory.systemTemp.createTempSync('live_storage_bootstrap');
  });

  tearDown(() {
    // Hive holds a process-wide path, so every case must leave with nothing open
    // or the next one inherits it.
    try {
      storageDir.deleteSync(recursive: true);
    } on FileSystemException {
      // A Windows file lock after a closed box is transient; the temp directory is
      // collected with the process anyway.
    }
  });

  StorageBootstrap bootstrapFor(StorageAdapterRegistry registry, {required int Function() onResolve}) {
    return StorageBootstrap(
      pathProvider: StoragePathProvider(
        resolver: () async {
          onResolve();
          return storageDir.path;
        },
      ),
      adapterRegistry: registry,
    );
  }

  test('a successful initialization runs the resolver and the registrars once each', () async {
    var resolves = 0;
    var registrations = 0;
    final subject = bootstrapFor(
      StorageAdapterRegistry()..add('iptv', () => registrations++),
      onResolve: () => ++resolves,
    );

    expect(subject.isInitialized, isFalse);

    await subject.initialize();

    expect(subject.isInitialized, isTrue);
    expect(resolves, 1);
    expect(registrations, 1);

    await subject.initialize();

    expect(resolves, 1, reason: 'an already-initialized store must not re-read the path');
    expect(registrations, 1, reason: 'a second adapter registration would throw inside Hive');
  });

  test('concurrent callers share one initialization operation', () async {
    var resolves = 0;
    var registrations = 0;
    final subject = bootstrapFor(
      StorageAdapterRegistry()..add('library', () => registrations++),
      onResolve: () => ++resolves,
    );

    // Two start-up paths (a page and a service, say) racing to initialize is the
    // common case, not an exotic one; the shared future is what prevents a
    // double `Hive.init` and a duplicate adapter registration.
    await Future.wait([subject.initialize(), subject.initialize(), subject.initialize()]);

    expect(resolves, 1);
    expect(registrations, 1);
    expect(subject.isInitialized, isTrue);
  });

  test('a failed initialization can be retried instead of poisoning the store', () async {
    var attempt = 0;
    var registrations = 0;
    final registry = StorageAdapterRegistry()..add('library', () => registrations++);
    final subject = StorageBootstrap(
      pathProvider: StoragePathProvider(
        resolver: () async {
          attempt++;
          if (attempt == 1) {
            throw StateError('the configured directory is not available');
          }
          return storageDir.path;
        },
      ),
      adapterRegistry: registry,
    );

    await expectLater(subject.initialize(), throwsStateError);
    expect(subject.isInitialized, isFalse);

    await subject.initialize();

    expect(subject.isInitialized, isTrue);
    expect(attempt, 2, reason: 'the second call must actually re-resolve, not await the stored failure');
    expect(registrations, 1);
  });

  test('concurrent callers of a failing initialization all see the same failure', () async {
    final subject = StorageBootstrap(
      pathProvider: StoragePathProvider(resolver: () async => throw StateError('unavailable')),
      adapterRegistry: StorageAdapterRegistry(),
    );

    final results = await Future.wait(
      [
        subject.initialize(),
        subject.initialize(),
      ].map((future) => future.then((_) => 'ok').catchError((Object _) => 'failed')),
    );

    expect(results, ['failed', 'failed']);
    expect(subject.isInitialized, isFalse);
  });

  test('shutdown closes the store and a later initialization starts it again', () async {
    var resolves = 0;
    final subject = bootstrapFor(StorageAdapterRegistry(), onResolve: () => ++resolves);

    await subject.initialize();
    await subject.shutdown();

    expect(subject.isInitialized, isFalse);

    await subject.initialize();

    expect(subject.isInitialized, isTrue);
    expect(resolves, 2, reason: 'after a shutdown the path must be resolved afresh');
  });

  test('shutdown before any initialization is a no-op', () async {
    var resolves = 0;
    final subject = bootstrapFor(StorageAdapterRegistry(), onResolve: () => ++resolves);

    await subject.shutdown();

    expect(resolves, 0);
    expect(subject.isInitialized, isFalse);
  });
}
