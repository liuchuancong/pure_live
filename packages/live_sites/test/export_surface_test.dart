import 'dart:io';

import 'package:test/test.dart';

/// Guards the package's export surface: every hand-written library under
/// `src/platforms/<site>/` and `src/common/` must be reachable through its
/// barrel — a nested role barrel counts, because its own exports are followed
/// — every site barrel through `platforms.dart`, and both barrels
/// through the package's public `live_sites.dart`. A new file or a new site
/// that skips its barrel fails here, not in an app's IDE weeks later.
void main() {
  List<String> libsIn(Directory dir, String barrelName) => dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => file.path.replaceAll(r'\', '/'))
      .where((path) => path.endsWith('.dart'))
      .where((path) => !path.endsWith('.freezed.dart') && !path.endsWith('.g.dart'))
      .where((path) => !path.endsWith('/$barrelName'))
      .toList();

  Set<String> exportsOf(File barrel) {
    final seen = <String>{};
    void visit(File file) {
      for (final line in file.readAsLinesSync()) {
        final match = RegExp("^export '([^']+)'").firstMatch(line);
        if (match == null) continue;
        final path = file.parent.uri.resolve(match.group(1)!).toFilePath().replaceAll(r'\', '/');
        if (!seen.add(path)) continue;
        final nested = File(path);
        final segments = path.split('/');
        final isBarrel = segments.length > 1 && segments.last == '${segments[segments.length - 2]}.dart';
        if (nested.existsSync() && isBarrel) visit(nested);
      }
    }

    visit(barrel);
    return seen;
  }

  test('every site ships a barrel and every hand-written lib is in it', () {
    final sites = Directory('lib/src/platforms').listSync().whereType<Directory>().toList();
    expect(sites, isNotEmpty);
    for (final site in sites) {
      final name = site.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      final barrel = File('${site.path}/$name.dart'.replaceAll(r'\', '/'));
      expect(barrel.existsSync(), isTrue, reason: '${site.path} has no $name.dart barrel');
      expect(exportsOf(barrel), containsAll(libsIn(site, '$name.dart')));
    }
  });

  test('common.dart covers the shared primitives', () {
    final barrel = File('lib/src/common/common.dart');
    expect(exportsOf(barrel), containsAll(libsIn(Directory('lib/src/common'), 'common.dart')));
  });

  test('platforms.dart lists every site barrel and the public barrel lists both', () {
    final barrel = File('lib/src/platforms/platforms.dart');
    final listed = exportsOf(barrel);
    for (final site in Directory('lib/src/platforms').listSync().whereType<Directory>()) {
      final name = site.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      expect(listed, contains('lib/src/platforms/$name/$name.dart'));
    }
    final public = File('lib/live_sites.dart').readAsLinesSync();
    expect(public, contains("export 'src/platforms/platforms.dart';"));
    expect(public, contains("export 'src/common/common.dart';"));
  });
}
