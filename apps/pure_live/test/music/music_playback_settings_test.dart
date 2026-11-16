// The music module's playback switches and their reset: the reset must land
// on the declared defaults, not drift past them — the autoplay switch once
// came back off a reset that promised on.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/modules/music/music.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await StoragePrefs.initSeeded({});
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('reset lands on the declared defaults, autoplay on', () async {
    final controller = container.read(musicPlaybackSettingsProvider.notifier);
    await controller.setAutoplay(value: false);
    expect(container.read(musicPlaybackSettingsProvider).autoplay, isFalse);

    await controller.reset();
    expect(container.read(musicPlaybackSettingsProvider).autoplay, isTrue);
  });
}
