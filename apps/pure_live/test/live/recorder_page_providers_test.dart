import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/providers/network/network_providers.dart' show networkFactoryProvider;
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_settings.dart';
import 'package:pure_live/modules/live/recorder/engine/recorder_engine.dart' show recorderEngineProvider;

void main() {
  setUpAll(() async {
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  test('the providers the recorder page watches all build', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(recordingRepositoryProvider.future);
    final tasks = container.read(recordingTasksProvider);
    expect(tasks.ready, isTrue);

    container.read(recordingSettingsProvider);

    await container.read(followRepositoryProvider.future);
    container.read(followsProvider);

    await container.read(historyRepositoryProvider.future);
    container
      ..read(historyProvider)
      ..read(sitesProvider)
      ..read(recorderEngineProvider)
      ..read(networkFactoryProvider);
  });
}
