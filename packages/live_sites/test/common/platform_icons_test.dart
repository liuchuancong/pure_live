import 'dart:io';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:test/test.dart';

/// The platform icons the app draws on its platform list: every built-in
/// site names one, and the file it names is shipped beside the package.
void main() {
  test('every built-in site names a bundled icon that ships', () {
    final sites = createBuiltInLiveSites(http: _FakeHttp());
    expect(sites, isNotEmpty);
    for (final site in sites) {
      final icon = site.manifest.icon;
      expect(icon, isNotNull, reason: site.manifest.id);
      expect(icon!.type, LiveAssetType.bundled, reason: site.manifest.id);
      final path = icon.path ?? '';
      expect(path, startsWith('assets/platforms/'), reason: site.manifest.id);
      expect(File(path).existsSync(), isTrue, reason: '${site.manifest.id}: $path');
    }
  });

  test('every shipped icon is a PNG', () {
    final icons = Directory('assets/platforms')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.png'));
    expect(icons, isNotEmpty);
    const magic = [0x89, 0x50, 0x4E, 0x47];
    for (final icon in icons) {
      final head = icon.readAsBytesSync().take(4).toList();
      expect(head, magic, reason: icon.path);
    }
  });
}

final class _FakeHttp implements LiveHttp {
  @override
  Future<LiveResponse> send(LiveRequest request) async =>
      LiveResponse(statusCode: 200, headers: const {}, bodyBytes: Uint8List(0));

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}
