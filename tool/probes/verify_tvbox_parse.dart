import 'dart:io';

// Probe: run the TVBox/M3U parsers against a real-world file. Opt-in tool,
// not part of the quality gate (tool/probes is excluded from CI).
import 'package:pure_live_external_tvbox/pure_live_external_tvbox.dart';

void main(List<String> args) {
  final text = File(args[0]).readAsStringSync();
  final sw = Stopwatch()..start();
  if (text.trimLeft().startsWith('#EXTM3U')) {
    final channels = const M3uParser().parse(text);
    sw.stop();
    final groups = channels.map((c) => c.group).toSet();
    final withHeaders = channels.where((c) => c.headers.isNotEmpty).length;
    final malformed = channels.where((c) => c.urls.isEmpty).length;
    print('parsed ${channels.length} channels in ${sw.elapsedMilliseconds}ms');
    print('groups: ${groups.length}, first 5: ${groups.take(5).toList()}');
    print('channels with headers: $withHeaders, malformed: $malformed');
    print('sample: ${channels.first.name} | ${channels.first.group} | ${channels.first.urls.first}');
  } else {
    final config = const TvBoxConfigParser().parse(text);
    sw.stop();
    print('parsed in ${sw.elapsedMilliseconds}ms');
    print('sites: ${config.sites.length}, lives: ${config.lives.length}');
    for (final site in config.sites.take(3)) {
      final api = site.api.length > 60 ? site.api.substring(0, 60) : site.api;
      final ext = site.ext.isEmpty ? '-' : site.ext.substring(0, site.ext.length.clamp(0, 40));
      print('site: ${site.key} type=${site.type} api=$api ext=$ext');
    }
  }
}
