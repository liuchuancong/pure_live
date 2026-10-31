import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/music/controller/music_sync_server.dart';

void main() {
  setUpAll(() async {
    // The same memory-only storage the other provider tests use; a fresh
    // install keeps the sync server off, which is the path the regression
    // runs through.
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  test('building musicSyncServerProvider must not modify a provider while initializing', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Regression: the provider used to run its first start/stop inside its
    // own build, and the first status emit then wrote to the status notifier
    // while Riverpod still considered this provider initializing — tripping
    // the `_debugAssertNotificationAllowed` assert at startup. The build now
    // defers the sync to a microtask, so this read must complete without
    // throwing.
    container.read(musicSyncServerProvider);

    // Long enough for the deferred sync and the provider's 2s retry timer to
    // both fire while the container is still alive.
    await Future<void>.delayed(const Duration(milliseconds: 2600));

    expect(container.read(musicSyncServerStatusProvider).running, isFalse);
  });
}
