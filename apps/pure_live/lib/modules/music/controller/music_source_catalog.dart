/// The community source catalog — the scripts collected at
/// <https://awaw.cc/post/lx-music-source> (repo `pdone/lx-music-source`),
/// offered in the sources pane for one-tap import. The catalog only names
/// where the latest script lives; importing downloads it and runs it through
/// the normal `MusicCustomSource.parse` path, so the stored copy always
/// matches what upstream serves that day.
library;

/// One catalog entry: the repo folder and the names the script is known by.
///
/// `scriptName` is the script's `@name` at catalog-write time; matching an
/// already-imported source compares against both it and the display name, so
/// an upstream rename does not double the entry.
final class MusicCatalogEntry {
  /// Creates one entry.
  const MusicCatalogEntry({
    required this.id,
    required this.name,
    required this.scriptName,
  });

  /// The repo folder the `latest.js` lives under.
  final String id;

  /// The display name shown in the pane.
  final String name;

  /// The script's own `@name` as of the catalog's writing.
  final String scriptName;

  /// The names an import of this entry may carry.
  List<String> get names => <String>[scriptName, name];
}

/// The upstream repo, newest-checked daily by its maintainer.
const String _catalogRepo = 'https://raw.githubusercontent.com/pdone/lx-music-source/main';

/// Mirror prefixes that serve the same repo path, tried in order when the
/// raw host is unreachable.
const List<String> _catalogMirrors = <String>[
  'https://ghproxy.net/raw.githubusercontent.com/pdone/lx-music-source/main',
  'https://github.moeyy.xyz/raw.githubusercontent.com/pdone/lx-music-source/main',
  'https://gh.llkk.cc/raw.githubusercontent.com/pdone/lx-music-source/main',
];

/// The catalog, in the order the collection page lists them.
const List<MusicCatalogEntry> kMusicSourceCatalog = <MusicCatalogEntry>[
  MusicCatalogEntry(id: 'changqing', name: '长青', scriptName: '长青SVIP音源'),
  MusicCatalogEntry(id: 'fish', name: 'Fish', scriptName: 'fish_music'),
  MusicCatalogEntry(id: 'flower', name: '野花', scriptName: '野花🌷'),
  MusicCatalogEntry(id: 'grass', name: '野草', scriptName: '野草🌾'),
  MusicCatalogEntry(id: 'helloworld', name: 'HelloWorld', scriptName: '𝖧౿ᥣᥣ𝗈 Ԝ𝗈𝗋ᥣᑯ'),
  MusicCatalogEntry(id: 'huanyin', name: '幻音', scriptName: '幻音音源'),
  MusicCatalogEntry(id: 'huibq', name: 'Huibq', scriptName: 'Huibq_lxmusic源'),
  MusicCatalogEntry(id: 'hyw', name: 'HYW', scriptName: 'HYWmusic_公益版'),
  MusicCatalogEntry(id: 'ikun', name: 'ikun', scriptName: 'ikun音源'),
  MusicCatalogEntry(id: 'jiexiang', name: '杰翔', scriptName: '杰翔聚合音源'),
  MusicCatalogEntry(id: 'juhe', name: '聚合API', scriptName: '聚合API接口 (CF)'),
  MusicCatalogEntry(id: 'lx', name: '独家', scriptName: '独家音源'),
  MusicCatalogEntry(id: 'qdy', name: '全豆要', scriptName: '全豆要[聚合音源]'),
  MusicCatalogEntry(id: 'sixyin', name: '六音', scriptName: '六音音源'),
  MusicCatalogEntry(id: 'xinghai', name: '星海', scriptName: '星海音乐源'),
  MusicCatalogEntry(id: 'yuningxi', name: '玉宁熙', scriptName: 'lx-玉宁熙-Pro'),
];

/// The addresses a catalog entry's script is served from — the raw host
/// first, then the mirrors.
List<Uri> musicCatalogScriptUrls(MusicCatalogEntry entry) => <Uri>[
  for (final base in <String>[_catalogRepo, ..._catalogMirrors]) Uri.parse('$base/${entry.id}/latest.js'),
];

/// Downloads a catalog entry's script, walking the mirror list; the first
/// non-empty body wins. [fetch] is the transport — the app passes
/// `LiveHttp`'s `getText`, tests pass a stub.
Future<String> fetchCatalogScript(
  MusicCatalogEntry entry,
  Future<String> Function(Uri uri) fetch,
) async {
  String? lastFailure;
  for (final uri in musicCatalogScriptUrls(entry)) {
    try {
      final body = await fetch(uri);
      if (body.trim().isNotEmpty) return body;
      lastFailure = 'empty body';
    } on Object catch (error) {
      lastFailure = '$error';
    }
  }
  throw MusicCatalogFetchException(lastFailure ?? 'no mirrors');
}

/// Every address answered nothing usable.
final class MusicCatalogFetchException implements Exception {
  /// The failure, carrying how the last mirror died.
  const MusicCatalogFetchException(this.cause);

  /// How the last address failed.
  final String cause;

  @override
  String toString() => 'MusicCatalogFetchException: $cause';
}
