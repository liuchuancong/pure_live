import 'dart:convert' show jsonDecode;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;

import 'package:pure_live/features/version/app_version.dart';

/// The project's release feed (the reference's `assets/version.json`,
/// shared with 3.x): its own fork, so the build the page offers is this
/// app's, not another project's.
const String updateFeedUrl = 'https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/version.json';

/// The release history feed (`assets/releases.json`).
const String releaseFeedUrl = 'https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/releases.json';

/// The project page, for when a release carries no download address.
const String versionProjectUrl = 'https://github.com/liuchuancong/pure_live';

/// A feed that cannot be read; the message names why, without a stack.
final class UpdateFeedException implements Exception {
  const UpdateFeedException(this.message);

  /// What went wrong, in the viewer's language or the transport's words.
  final String message;

  @override
  String toString() => message;
}

/// The newest release for this platform, from the feed's top level
/// overridden by `platforms.<own>`.
final class UpdateInfo {
  /// Creates the record.
  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.log,
    required this.prerelease,
    required this.downloadUrl,
  });

  /// Reads the feed; throws [FormatException] without a version or a
  /// positive build number.
  factory UpdateInfo.fromJson(Map<String, Object?> json) {
    final platforms = json['platforms'];
    final own = switch (platforms) {
      final Map<Object?, Object?> map when _platformKey != null => map[_platformKey],
      _ => null,
    };
    final data = <String, Object?>{...json, if (own is Map) ...own.cast<String, Object?>()};
    final version = data['version']?.toString().trim() ?? '';
    final build = int.tryParse(data['build_number']?.toString().trim() ?? '');
    if (version.isEmpty || build == null || build <= 0) {
      throw const FormatException('The release has no version or build number');
    }
    return UpdateInfo(
      version: version,
      buildNumber: build,
      log: data['version_desc']?.toString().trim() ?? '',
      prerelease: data['prerelease'] == true,
      downloadUrl: data['download_url']?.toString().trim() ?? '',
    );
  }

  /// Version name.
  final String version;

  /// Build number.
  final int buildNumber;

  /// What changed (Markdown).
  final String log;

  /// Whether it is a pre-release.
  final bool prerelease;

  /// The release page (the feed's own download address).
  final String downloadUrl;

  /// Whether this release is newer than [installed]: a newer version, or
  /// the same version with a newer build.
  bool isNewerThan(InstalledVersion installed) =>
      installed.version.isNotEmpty &&
      (isNewerVersion(version, installed.version) ||
          (sameVersion(version, installed.version) && buildNumber > installed.build));
}

/// One release in the history feed.
final class ReleaseInfo {
  /// Creates the record.
  const ReleaseInfo({
    required this.version,
    required this.title,
    required this.date,
    required this.url,
    required this.author,
    required this.changelog,
  });

  /// Reads one entry; throws [FormatException] without a version.
  factory ReleaseInfo.fromJson(Map<String, Object?> json) {
    final version = json['version']?.toString().trim() ?? '';
    if (version.isEmpty) throw const FormatException('A release has no version');
    final author = json['author'];
    return ReleaseInfo(
      version: version,
      title: json['title']?.toString().trim() ?? '',
      date: json['date']?.toString().trim() ?? '',
      url: json['github']?.toString().trim() ?? '',
      author: switch (author) {
        final Map<Object?, Object?> map => map['name']?.toString().trim() ?? '',
        _ => '',
      },
      changelog: json['changelog']?.toString().trim() ?? '',
    );
  }

  /// Version name.
  final String version;

  /// The release's own title.
  final String title;

  /// The release date (`2026-10-25`).
  final String date;

  /// Its GitHub page.
  final String url;

  /// Who published it.
  final String author;

  /// What changed (Markdown).
  final String changelog;
}

/// Reads the newest release from [http], falling back to the `main` branch
/// when the fork's default branch is not called `master`.
Future<UpdateInfo> fetchUpdateInfo(LiveHttp http) async {
  final text = await _read(http, updateFeedUrl);
  final decoded = _json(text);
  if (decoded is! Map<String, Object?>) throw const UpdateFeedException('The release feed is not an object');
  return UpdateInfo.fromJson(decoded);
}

/// Reads the published releases, newest first as the feed lists them.
Future<List<ReleaseInfo>> fetchReleases(LiveHttp http) async {
  final text = await _read(http, releaseFeedUrl);
  final decoded = _json(text);
  if (decoded is! List<Object?>) throw const UpdateFeedException('The release history is not a list');
  final releases = <ReleaseInfo>[];
  for (final entry in decoded) {
    if (entry is Map<String, Object?>) releases.add(ReleaseInfo.fromJson(entry));
  }
  return releases;
}

/// Reads [url], retrying once on `<default branch>/main` when the raw file
/// is missing (a fork that renamed its branch).
Future<String> _read(LiveHttp http, String url) async {
  var response = await http.send(LiveRequest.get(Uri.parse(url), headers: const {'accept': 'application/json'}));
  if (response.statusCode == 404) {
    final main = url.replaceFirst('/master/', '/main/');
    if (main != url) {
      response = await http.send(LiveRequest.get(Uri.parse(main), headers: const {'accept': 'application/json'}));
    }
  }
  if (!response.isOk) throw UpdateFeedException('HTTP ${response.statusCode}');
  return response.text;
}

Object? _json(String text) {
  try {
    return jsonDecode(text);
  } on FormatException catch (error) {
    throw UpdateFeedException('The feed is not valid JSON: ${error.message}');
  }
}

String? get _platformKey {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.windows => 'windows',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => null,
  };
}
