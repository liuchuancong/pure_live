import 'package:live_storage/live_storage.dart';
import 'package:test/test.dart';

/// The guard in front of the database open: a path that is not empty.
void main() {
  group('StoragePathProvider', () {
    test('trims the resolved directory before handing it on', () async {
      final provider = StoragePathProvider(resolver: () async => '  D:/data/pure_live  ');

      expect(await provider.getStoragePath(), 'D:/data/pure_live');
    });

    test('refuses an empty path rather than writing beside the working directory', () async {
      final provider = StoragePathProvider(resolver: () async => '   ');

      // The failure is deliberately loud: an empty string would put the
      // database beside whatever directory the process happened to start in,
      // and the viewer's data would appear lost rather than misplaced.
      await expectLater(provider.getStoragePath(), throwsStateError);
    });
  });
}
