import 'package:live_net/live_net.dart';

/// Where the app's releases live.
const String updateOwner = 'liuchuancong';
const String updateRepo = 'pure_live';

/// The project page.
final Uri projectUrl = Uri.parse('https://github.com/$updateOwner/$updateRepo');

/// One GitHub release of the app's repository.
final class AppRelease {
  /// Parses one release entry of the GitHub releases API.
  AppRelease.fromJson(Map<Object?, Object?> json)
    : tag = '${json['tag_name'] ?? ''}',
      name = '${json['name'] ?? json['tag_name'] ?? ''}',
      body = '${json['body'] ?? ''}',
      publishedAt = DateTime.tryParse('${json['published_at'] ?? ''}'),
      prerelease = json['prerelease'] == true;

  /// The release tag (e.g. `v3.2.0`).
  final String tag;

  /// The release title.
  final String name;

  /// The release notes, markdown.
  final String body;

  /// When the release was published; null while unpublished/draft-shaped.
  final DateTime? publishedAt;

  /// Whether the release is marked prerelease.
  final bool prerelease;

  /// Whether [tag] carries a readable version for comparisons.
  bool get hasVersion => tag.trim().isNotEmpty;
}

/// The update feed: the repository's published releases, newest first.
final class UpdateFeed {
  /// A feed over [http].
  const UpdateFeed({required this.http});

  /// The app's shared HTTP client.
  final LiveHttp http;

  /// Fetches up to [limit] published releases.
  ///
  /// Any non-200 answer and any transport failure becomes an exception —
  /// the caller renders it and offers a retry.
  Future<List<AppRelease>> fetch({int limit = 10}) async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https('api.github.com', '/repos/$updateOwner/$updateRepo/releases', {'per_page': '$limit'}),
        headers: {'Accept': 'application/vnd.github+json'},
      ),
    );
    if (response.statusCode != 200) {
      throw FeedUnavailable('GitHub answered ${response.statusCode}');
    }
    final decoded = response.json;
    if (decoded is! List) {
      throw const FeedUnavailable('unexpected releases payload');
    }
    return [
      for (final entry in decoded)
        if (entry is Map<Object?, Object?>) AppRelease.fromJson(entry),
    ];
  }
}

/// The feed could not be read.
final class FeedUnavailable implements Exception {
  /// A feed failure.
  const FeedUnavailable(this.message);

  /// What went wrong, safe to show.
  final String message;

  @override
  String toString() => message;
}
