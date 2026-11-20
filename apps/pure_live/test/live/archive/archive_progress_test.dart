import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/live/archive/archive_progress.dart';

/// The replay walk's progress store: the part positions it keeps, the part
/// a recording resumes from, and the bound that keeps a long walk from
/// growing the preference forever.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  test('a part without a saved walk reads as none, not as zero', () async {
    final progress = ArchiveProgress();
    expect(progress.position('part-a'), const Duration(milliseconds: -1));

    await progress.save('part-a', const Duration(seconds: 90));
    expect(progress.position('part-a'), const Duration(seconds: 90));
  });

  test('zero keeps its meaning of watched from the start', () async {
    final progress = ArchiveProgress();
    await progress.save('part-a', Duration.zero);
    expect(progress.position('part-a'), Duration.zero);
  });

  test('a re-save replaces the part and lifts it to the newest', () async {
    final progress = ArchiveProgress();
    await progress.save('rec:a', const Duration(seconds: 1));
    await progress.save('rec:b', const Duration(seconds: 2));
    expect(progress.recent('rec:'), 'rec:b');

    await progress.save('rec:a', const Duration(seconds: 9));
    expect(progress.position('rec:a'), const Duration(seconds: 9));
    // The re-save is the walk's newest fact about the recording.
    expect(progress.recent('rec:'), 'rec:a');
  });

  test('the part the recording stopped in last answers by its prefix', () async {
    final progress = ArchiveProgress();
    await progress.save('rec:one', const Duration(seconds: 5));
    await progress.save('rec:two', const Duration(seconds: 6));
    await progress.save('other:three', const Duration(seconds: 7));

    expect(progress.recent('rec:'), 'rec:two');
    expect(progress.recent('other:'), 'other:three');
    expect(progress.recent('nothing:'), isNull);
  });

  test('the store holds two hundred positions and drops the oldest', () async {
    final progress = ArchiveProgress();
    for (var i = 0; i < 201; i++) {
      await progress.save('p$i', Duration(seconds: i));
    }
    // The store itself is the bound: the raw preference keeps the newest
    // two hundred, the first save fell off the front.
    final kept = jsonDecode(StoragePrefs.getString('archive.replay.progress')!) as Map;
    expect(kept.length, 200);
    expect(kept.containsKey('p0'), isFalse);
    expect(kept.containsKey('p200'), isTrue);
    expect(progress.position('p0'), const Duration(milliseconds: -1));
    expect(progress.position('p200'), const Duration(seconds: 200));
  });

  test('a store another writer mangled reads as empty, not a crash', () async {
    await StoragePrefs.setString('archive.replay.progress', 'not json at all');
    final progress = ArchiveProgress();
    expect(progress.position('part-a'), const Duration(milliseconds: -1));
    expect(progress.recent('rec:'), isNull);

    // A list is not the map the store keeps.
    await StoragePrefs.setString('archive.replay.progress', jsonEncode([1, 2, 3]));
    expect(progress.position('part-a'), const Duration(milliseconds: -1));
  });

  test('a closed store only loses the persistence', () async {
    final progress = ArchiveProgress();
    await stores.close();

    await progress.save('part-a', const Duration(seconds: 30)); // must not throw
    expect(progress.position('part-a'), const Duration(milliseconds: -1));
  });
}
