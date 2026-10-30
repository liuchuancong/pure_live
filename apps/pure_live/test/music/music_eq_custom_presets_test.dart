import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/modules/music/controller/eq/music_eq_config.dart';
import 'package:pure_live/modules/music/controller/eq/music_eq_custom_presets.dart';

void main() {
  setUpAll(() async {
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  setUp(() async {
    // The store survives across tests; each starts with an empty shelf.
    await StoragePrefs.setString(kMusicCustomPresetsKey, '[]');
  });

  test('save snapshots the curve in force and applyCustomPreset rides it back', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final eq = container.read(musicEqProvider.notifier);
    await eq.applyPreset(kMusicEqPresets.first);
    await eq.setPreamp(2.5);
    await eq.setEffect('bass', enabled: true, amount: 0.6);

    final custom = container.read(musicCustomPresetsProvider.notifier);
    final saved = await custom.save('深夜人声');

    expect(container.read(musicCustomPresetsProvider), hasLength(1));
    expect(saved.name, '深夜人声');
    expect(saved.gains, kMusicEqPresets.first.gains);
    expect(saved.preampDb, 2.5);
    expect(saved.effects['bass']?.enabled, isTrue);

    // A different curve, then the saved preset back — curve, preamp,
    // effects and the preset id all return.
    await eq.applyPreset(kMusicEqPresets.last);
    await eq.applyCustomPreset(saved);
    final restored = container.read(musicEqProvider);
    expect(restored.gains, saved.gains);
    expect(restored.preampDb, 2.5);
    expect(restored.effectOf('bass').enabled, isTrue);
    expect(restored.presetId, '$kMusicCustomPresetPrefix${saved.id}');
  });

  test('remove forgets the preset and the configuration keeps its curve', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final eq = container.read(musicEqProvider.notifier);
    final custom = container.read(musicCustomPresetsProvider.notifier);
    final saved = await custom.save('roads');
    await eq.applyCustomPreset(saved);

    await custom.remove(saved.id);
    expect(container.read(musicCustomPresetsProvider), isEmpty);
    final kept = container.read(musicEqProvider);
    expect(kept.gains, saved.gains);
    // The id points nowhere now — the curve plays but no preset owns it.
    expect(customPresetIdOf(kept.presetId), isNotNull);
    expect(container.read(musicCustomPresetsProvider), isEmpty);
  });

  test('a damaged store entry is dropped, not thrown', () {
    expect(MusicCustomEqPreset.fromJson(null), isNull);
    expect(MusicCustomEqPreset.fromJson(<String, Object?>{}), isNull);
    expect(
      MusicCustomEqPreset.fromJson(<String, Object?>{
        'id': 'x',
        'name': 'n',
        'gains': <Object?>[1, 2, 3],
      }),
      isNull,
    );
  });
}
