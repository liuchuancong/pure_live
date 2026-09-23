import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/update.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/models/release_model.dart';

typedef ReleaseHistoryExternalLauncher = Future<bool> Function(Uri uri);
typedef ReleaseHistoryDownloadHandler = Future<void> Function(String url, {String? fileName});

class ReleaseHistoryRepository {
  ReleaseHistoryRepository._();

  static final ReleaseHistoryRepository instance = ReleaseHistoryRepository._();

  static const Map<String, String> defaultHeaders = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
    'Accept': 'application/json,text/plain,*/*',
  };

  static const String releaseAssetPath = 'assets/releases.json';

  static const Duration _resolveTimeout = Duration(seconds: 10);
  static const Duration _fetchTimeout = Duration(seconds: 15);

  List<ReleaseModel>? _cache;

  Future<List<ReleaseModel>> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) {
      return _cache!;
    }

    final url = await _resolveSourceUrl();
    final response = await HttpClient.instance.getJson(url, header: defaultHeaders).timeout(_fetchTimeout);

    final decoded = response is String ? json.decode(response) : response;
    final releases = parse(decoded);
    _cache = releases;
    return releases;
  }

  void clearCache() {
    _cache = null;
  }

  Future<String> _resolveSourceUrl() async {
    final raw = VersionUtil.mirror.rawUrl(releaseAssetPath);
    final mirrors = VersionUtil.mirror.mirrors(releaseAssetPath);

    final sourceUrls = SettingsService.to.app.useGitHubOriginForUpdates.v
        ? <String>[raw, ...mirrors]
        : <String>[...mirrors, raw];

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final urls = sourceUrls
        .map((source) {
          final uri = Uri.parse(source);
          return uri.replace(queryParameters: {...uri.queryParameters, 'ts': timestamp}).toString();
        })
        .toList(growable: false);

    final url = await RaceHttp.findFastestUrl(urls, headers: defaultHeaders).timeout(_resolveTimeout);

    if (url == null) {
      throw StateError('No release history source responded');
    }
    return url;
  }

  List<ReleaseModel> parse(Object? decoded) {
    final rawReleases = switch (decoded) {
      List values => values,
      Map values when values['releases'] is List => values['releases'] as List,
      _ => null,
    };
    if (rawReleases == null) {
      throw const FormatException('Invalid release history payload');
    }

    final releases = <ReleaseModel>[];
    for (final entry in rawReleases) {
      if (entry is! Map) continue;
      final release = ReleaseModel.fromJson(Map<String, dynamic>.from(entry));
      if (release.version.trim().isEmpty) continue;
      releases.add(release);
    }
    releases.sort((left, right) {
      final byDate = right.date.compareTo(left.date);
      return byDate != 0 ? byDate : right.version.compareTo(left.version);
    });
    return List.unmodifiable(releases);
  }

  Uri? webUri(String rawUrl) => updateDownloadUri(rawUrl);
}
