// Module: lib/src/update_feed.dart
// Purpose: Reads a releases feed, decides whether to update, and names the
// asset for the running platform.
// Author: liuchuancong
// Created: 2026-10-10
//
// The feed is the repository's releases.json (newest first): one entry per
// release with version/date/changelog and a files array of {name, url}. The
// platform asset is picked by name pattern, newest entry wins, and entries
// whose version fails to parse are skipped rather than poisoning the choice.

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';

import 'version.dart';

/// The platform an update asset is picked for.
enum UpdateTarget { android, windows, linux, macos }

/// One downloadable asset of a release.
final class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url});

  final String name;
  final String url;
}

/// One release entry as the feed carries it.
final class ReleaseEntry {
  const ReleaseEntry({
    required this.version,
    required this.title,
    required this.date,
    required this.assets,
    this.changelog,
    this.githubUrl,
  });

  final AppVersion version;
  final String title;
  final String date;
  final List<ReleaseAsset> assets;
  final String? changelog;
  final String? githubUrl;

  /// The asset for [target], matched by the name patterns each platform's
  /// artifacts carry. Null when this release built nothing for the platform.
  ReleaseAsset? assetFor(UpdateTarget target) {
    final patterns = <UpdateTarget, List<RegExp>>{
      UpdateTarget.android: [RegExp(r'\.apk$', caseSensitive: false)],
      UpdateTarget.windows: [
        RegExp(r'windows.*\.zip$', caseSensitive: false),
        RegExp(r'windows.*\.(exe|msix)$', caseSensitive: false),
        RegExp(r'\.zip$', caseSensitive: false),
      ],
      UpdateTarget.linux: [RegExp(r'linux.*\.(\w+)$', caseSensitive: false)],
      UpdateTarget.macos: [RegExp(r'mac.*\.dmg$', caseSensitive: false), RegExp(r'\.dmg$', caseSensitive: false)],
    }[target]!;
    for (final pattern in patterns) {
      for (final asset in assets) {
        if (pattern.hasMatch(asset.name)) {
          return asset;
        }
      }
    }
    return null;
  }
}

/// The outcome of one update check: the newest release, or the failure.
final class UpdateCheckResult {
  const UpdateCheckResult({required this.current, this.entry, this.asset, this.error});

  final AppVersion current;

  /// The newest feed entry, when the feed was readable.
  final ReleaseEntry? entry;

  /// The asset for the running platform inside [entry], when one exists.
  final ReleaseAsset? asset;

  /// Why the check failed, when it did.
  final String? error;

  bool get isSuccessful => error == null && entry != null;

  /// The decision against the current build. Forced/available/none per the
  /// version comparison; a missing platform asset downgrades "available" to a
  /// notice that a newer version exists but nothing is offered for this
  /// platform.
  UpdateDecision decide() {
    if (entry == null) {
      return UpdateDecision(action: UpdateAction.none, current: current, reason: error ?? 'feed empty');
    }
    final decision = decideUpdate(current: current, latest: entry!.version);
    return UpdateDecision(
      action: decision.action,
      current: current,
      latest: entry!.version,
      reason: decision.reason ?? (asset == null ? '新版本存在,但没有本平台的安装包' : null),
    );
  }
}

/// Fetches and decodes the feed, then answers one [UpdateCheckResult].
final class UpdateChecker {
  UpdateChecker({required this.feedUrl, NetworkClient? client, this.target = UpdateTarget.android})
    : _client = client ?? NetworkClient();

  final String feedUrl;
  final UpdateTarget target;
  final NetworkClient _client;

  Future<UpdateCheckResult> check(AppVersion current) async {
    try {
      final response = await _client.get(feedUrl, headers: const <String, String>{'accept': 'application/json'});
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return UpdateCheckResult(current: current, error: 'feed status $status');
      }
      final entry = newestEntry(response.data ?? '');
      if (entry == null) {
        return UpdateCheckResult(current: current, error: 'feed carried no parsable release');
      }
      return UpdateCheckResult(current: current, entry: entry, asset: entry.assetFor(target));
    } catch (error) {
      return UpdateCheckResult(current: current, error: '$error');
    }
  }

  /// The first entry whose version parses. The feed is newest-first by
  /// convention, so the first parsable one is the newest offer.
  ReleaseEntry? newestEntry(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) {
      return null;
    }
    for (final row in decoded) {
      if (row is! Map) {
        continue;
      }
      final versionText = '${row['version'] ?? ''}';
      final AppVersion version;
      try {
        version = AppVersion.parse(versionText);
      } on FormatException {
        continue;
      }
      final files = row['files'];
      final assets = <ReleaseAsset>[
        if (files is List)
          for (final file in files)
            if (file is Map) ReleaseAsset(name: '${file['name'] ?? ''}', url: '${file['url'] ?? ''}'),
      ];
      return ReleaseEntry(
        version: version,
        title: '${row['title'] ?? versionText}',
        date: '${row['date'] ?? ''}',
        assets: assets,
        changelog: row['changelog']?.toString(),
        githubUrl: row['github']?.toString(),
      );
    }
    return null;
  }

  void dispose() => _client.close();
}
