import 'dart:io';

import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

/// The one bootstrap that decides whether the app has a usable database:
/// one shared open under concurrency, a retryable failure, and a shutdown
/// that really resets.
void main() {
  late Directory storageDir;

  setUp(() {
    storageDir = Directory.systemTemp.createTempSync('live_storage_bootstrap');
  });

  tearDown(() async {
    await StorageStores.closeInstance();
    try {
      storageDir.deleteSync(recursive: true);
    } on FileSystemException {
      // A Windows file handle can outlive close by a tick; the temp directory
      // is collected with the process.
    }
  });

  StorageBootstrap bootstrapFor({required int Function() onResolve}) {
    return StorageBootstrap(
      pathProvider: StoragePathProvider(
        resolver: () async {
          onResolve();
          return storageDir.path;
        },
      ),
    );
  }

  test('a successful initialization opens the database and resolves once', () async {
    var resolves = 0;
    final subject = bootstrapFor(onResolve: () => ++resolves);

    expect(subject.isInitialized, isFalse);

    await subject.initialize();

    expect(subject.isInitialized, isTrue);
    expect(StorageStores.isOpen, isTrue);
    expect(resolves, 1);
    expect(StorageStores.databaseFile(storageDir.path).existsSync(), isTrue);

    await subject.initialize();

    expect(resolves, 1, reason: 'an already-initialized store must not re-read the path');
  });

  test('concurrent callers share one initialization operation', () async {
    var resolves = 0;
    final subject = bootstrapFor(onResolve: () => ++resolves);

    await Future.wait([subject.initialize(), subject.initialize(), subject.initialize()]);

    expect(resolves, 1);
    expect(subject.isInitialized, isTrue);
  });

  test('a failed initialization can be retried instead of poisoning the store', () async {
    var attempt = 0;
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
    );

    await expectLater(subject.initialize(), throwsStateError);
    expect(subject.isInitialized, isFalse);
    expect(StorageStores.isOpen, isFalse);

    await subject.initialize();

    expect(subject.isInitialized, isTrue);
    expect(attempt, 2, reason: 'the second call must actually re-resolve, not await the stored failure');
  });

  test('concurrent callers of a failing initialization all see the same failure', () async {
    final subject = StorageBootstrap(
      pathProvider: StoragePathProvider(resolver: () async => throw StateError('unavailable')),
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

  test('shutdown closes the database and a later initialization starts it again', () async {
    var resolves = 0;
    final subject = bootstrapFor(onResolve: () => ++resolves);

    await subject.initialize();
    await subject.shutdown();

    expect(subject.isInitialized, isFalse);
    expect(StorageStores.isOpen, isFalse);

    await subject.initialize();

    expect(subject.isInitialized, isTrue);
    expect(resolves, 2, reason: 'after a shutdown the path must be resolved afresh');
  });

  test('shutdown before any initialization is a no-op', () async {
    var resolves = 0;
    final subject = bootstrapFor(onResolve: () => ++resolves);

    await subject.shutdown();

    expect(resolves, 0);
    expect(subject.isInitialized, isFalse);
  });
}
