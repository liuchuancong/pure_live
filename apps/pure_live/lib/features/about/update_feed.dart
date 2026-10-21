import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:live_net/live_net.dart';

/// Where the app's releases live.
const String updateOwner = 'liuchuancong';

/// The repository the releases publish under.
const String updateRepo = 'pure_live';

/// The project page.
final Uri projectUrl = Uri.parse('https://github.com/$updateOwner/$updateRepo');

/// One file published with a release (a GitHub release asset).
final class ReleaseAsset {
  /// Parses one entry of the release's `assets` array.
  new fromJson(Map<Object?, Object?> json)
    : name = '${json['name'] ?? ''}',
      sizeBytes = (json['size'] as num?)?.toInt() ?? 0,
      downloads = (json['download_count'] as num?)?.toInt() ?? 0,
      url = '${json['browser_download_url'] ?? ''}';

  /// The file's name (e.g. `pure_live-1.2.0.apk`).
  final String name;

  /// The file's size in bytes; 0 when the feed omits it.
  final int sizeBytes;

  /// How often the file was downloaded.
  final int downloads;

  /// The direct download URL; empty when the feed omits it.
  final String url;

  /// The extensions a release file can carry and still be an app package a
  /// device could install or a desktop could run.
  static const Set<String> _installableExtensions = <String>{
    '.apk',
    '.exe',
    '.msix',
    '.appx',
    '.dmg',
    '.pkg',
    '.deb',
    '.rpm',
    '.appimage',
    '.zip',
  };

  /// The download URL as a URI; null when the feed omitted it or it does not
  /// parse.
  Uri? get uri {
    final text = url.trim();
    if (text.isEmpty) {
      return null;
    }
    return Uri.tryParse(text);
  }

  /// Whether the file looks like an installable app package (by extension),
  /// as opposed to source archives or checksum sidecars.
  bool get installable {
    final path = uri?.path.toLowerCase() ?? '';
    return _installableExtensions.any(path.endsWith);
  }

  /// The size as a human-readable label (`12.34 MB`, `845 KB`, `512 B`).
  String get sizeLabel {
    const kilo = 1024;
    const mega = kilo * kilo;
    if (sizeBytes >= mega) {
      return '${(sizeBytes / mega).toStringAsFixed(2)} MB';
    }
    if (sizeBytes >= kilo) {
      return '${(sizeBytes / kilo).toStringAsFixed(0)} KB';
    }
    return '$sizeBytes B';
  }
}

/// One GitHub release of the app's repository.
final class AppRelease {
  /// Parses one release entry of the GitHub releases API.
  new fromJson(Map<Object?, Object?> json)
    : tag = '${json['tag_name'] ?? ''}',
      name = '${json['name'] ?? json['tag_name'] ?? ''}',
      body = '${json['body'] ?? ''}',
      publishedAt = DateTime.tryParse('${json['published_at'] ?? ''}'),
      htmlUrl = '${json['html_url'] ?? ''}',
      prerelease = json['prerelease'] == true,
      assets = _assets(json['assets']);

  /// The release tag (e.g. `v3.2.0`).
  final String tag;

  /// The release title.
  final String name;

  /// The release notes, markdown.
  final String body;

  /// When the release was published; null while unpublished/draft-shaped.
  final DateTime? publishedAt;

  /// The release's page on the project site; empty when the feed omits it.
  final String htmlUrl;

  /// Whether the release is marked prerelease.
  final bool prerelease;

  /// The files published with the release, in feed order.
  final List<ReleaseAsset> assets;

  /// The release's installable packages, in feed order.
  List<ReleaseAsset> get installableAssets => [
    for (final asset in assets)
      if (asset.installable) asset,
  ];

  /// Decodes the release's `assets` array, skipping unreadable entries.
  static List<ReleaseAsset> _assets(Object? raw) => [
    if (raw is List)
      for (final entry in raw)
        if (entry is Map<Object?, Object?>) ReleaseAsset.fromJson(entry),
  ];

  /// Whether [tag] carries a readable version for comparisons.
  bool get hasVersion => tag.trim().isNotEmpty;
}

/// The update feed: the repository's published releases, newest first.
final class UpdateFeed {
  /// A feed over [http]. [githubOnly] (the 更新源 setting) asks GitHub
  /// itself; off, the release JSON is raced across the mirrors first with
  /// GitHub as the last door — the reference's `updateRepository.mirrors`.
  const new({required this.http, this.githubOnly = true});

  /// The app's shared HTTP client.
  final LiveHttp http;

  /// Whether only GitHub is asked.
  final bool githubOnly;

  /// The mirrors that stand in for `api.github.com` when the setting does not
  /// ask for the origin itself: each is a prefix put in front of the whole
  /// origin URL, which is how this kind of proxy addresses the API.
  ///
  /// Measured from a Chinese network on 2026-10-21, these seven answer the
  /// release JSON; the reference's other prefixes serve raw files only and
  /// reply to an API path with HTML or a 403, so they are not listed.
  static const List<String> _mirrors = [
    'https://cdn.gh-proxy.org/',
    'https://edgeone.gh-proxy.org/',
    'https://hk.gh-proxy.org/',
    'https://v6.gh-proxy.org/',
    'https://gh.noki.eu.org/',
    'https://gh-proxy.com/',
    'https://wget.la/',
  ];

  /// Fetches up to [limit] published releases.
  ///
  /// Any non-200 answer and any transport failure becomes an exception —
  /// the caller renders it and offers a retry. With mirrors on, the first
  /// source to answer a valid list wins; every one failing together is the
  /// `FeedUnavailable` the page shows.
  Future<List<AppRelease>> fetch({int limit = 10}) async {
    const path = '/repos/$updateOwner/$updateRepo/releases';
    const timeout = Duration(seconds: 10);
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final query = {'per_page': '$limit', 'ts': stamp};
    // The release JSON is an api.github.com document; `github.com/repos/…` is
    // a 404 page, not the same answer prettily dressed.
    final origin = Uri.https('api.github.com', path, query);
    final uris = <Uri>[
      // A mirror of this kind is addressed by prefixing the whole origin URL:
      // `https://gh-proxy.com/https://api.github.com/…`. Replaying only the
      // path against the mirror host asks it for a repository it does not have.
      if (!githubOnly)
        for (final prefix in _mirrors) Uri.parse('$prefix$origin'),
      origin,
    ];
    Exception? lastError;
    for (final uri in uris) {
      try {
        final response = await http.send(
          LiveRequest.get(uri, headers: {'Accept': 'application/vnd.github+json'}, timeout: timeout),
        );
        if (response.statusCode != 200) {
          lastError = FeedUnavailable('${uri.host} answered ${response.statusCode}');
          continue;
        }
        final decoded = response.json;
        if (decoded is! List) {
          lastError = const FeedUnavailable('unexpected releases payload');
          continue;
        }
        return [
          for (final entry in decoded)
            if (entry is Map<Object?, Object?>) AppRelease.fromJson(entry),
        ];
      } on Object catch (error) {
        lastError = error is Exception ? error : FeedUnavailable('$error');
      }
    }
    throw lastError ?? const FeedUnavailable('no update source answered');
  }
}

/// The feed could not be read.
final class FeedUnavailable implements Exception {
  /// A feed failure.
  const new(this.message);

  /// What went wrong, safe to show.
  final String message;

  @override
  String toString() => message;
}

/// Whether [asset] is the package built for the device running the app —
/// the reference marks it 本机 on the update and history pages. Name
/// patterns only; a build this app cannot install never claims the tag.
bool isNativeAsset(ReleaseAsset asset) {
  final name = asset.name.toLowerCase();
  if (defaultTargetPlatform == TargetPlatform.windows) return name.endsWith('.exe');
  if (defaultTargetPlatform == TargetPlatform.linux) {
    return name.endsWith('.appimage') || name.endsWith('.deb') || name.endsWith('.tar.xz');
  }
  if (defaultTargetPlatform == TargetPlatform.macOS) return name.endsWith('.dmg');
  if (defaultTargetPlatform == TargetPlatform.android) {
    // The modern 64-bit phone package; a 32-bit or tablet-only build is not
    // this device's answer.
    return name.endsWith('.apk') && name.contains('arm64-v8a');
  }
  return false;
}
