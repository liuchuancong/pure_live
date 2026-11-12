import 'dart:convert' show jsonEncode;
import 'dart:io';

import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

/// The big-document path: a list past the isolate threshold round-trips
/// through the background encode and the background decode and comes back
/// whole. The threshold's value lives in the store; this writes enough rows
/// to be past it either way.
void main() {
  late Directory storageDir;

  setUp(() {
    storageDir = Directory.systemTemp.createTempSync('live_storage_big_document');
  });

  tearDown(() async {
    await StorageStores.closeInstance();
    try {
      storageDir.deleteSync(recursive: true);
    } on FileSystemException {
      // A Windows file handle can outlive close by a tick; the temp
      // directory is collected with the process.
    }
  });

  test('a big list document round-trips through the background codec', () async {
    await StorageBootstrap(pathProvider: StoragePathProvider(resolver: () async => storageDir.path)).initialize();
    final listStore = JsonListStore(await StorageStores.instance.openStore('roundtrip'));

    final rows = [
      for (var i = 0; i < 4500; i++) {'n': i, 't': '第 $i 行'},
    ];
    await listStore.save('big', rows);
    expect(jsonEncode(listStore.get('big')), jsonEncode(rows));

    // The read-back half runs at store open, so the decode is proven by
    // reopening the same directory with a fresh instance.
    await StorageStores.closeInstance();
    await StorageBootstrap(pathProvider: StoragePathProvider(resolver: () async => storageDir.path)).initialize();
    final reopened = JsonListStore(await StorageStores.instance.openStore('roundtrip'));
    expect(jsonEncode(reopened.get('big')), jsonEncode(rows));
  });
}
