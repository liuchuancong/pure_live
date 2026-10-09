// Module: lib/src/tvbox_repository.dart
// Purpose: Parses TVBox repository configs: single repos (sites + lives) and
// multi-repos (lists of repo urls), plus the M3U playlist format lives use.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/sources/vod/tvbox.md and docs/plugin/data-plugin.md. A data
// plugin carries no code: the parser derives its manifest from the config.
// Parsing is total and side-effect free; a repo this parser cannot understand
// is reported, never half-interpreted. Spider-backed sites (type 1 js / type 3
// python) are inventoried with the runtime they need - the framework registers
// them as pending until that runtime exists, rather than pretending they work.

import 'dart:convert';

/// One site entry of a single TVBox repo.
final class TvBoxSite {
  const TvBoxSite({
    required this.key,
    required this.name,
    required this.type,
    required this.api,
    this.ext = '',
    this.jar = '',
    this.searchable = false,
  });

  factory TvBoxSite.fromJson(Map<String, Object?> json) {
    return TvBoxSite(
      key: '${json['key'] ?? ''}',
      name: '${json['name'] ?? ''}',
      type: (json['type'] as num?)?.toInt() ?? 0,
      api: '${json['api'] ?? ''}',
      ext: json['ext'] == null
          ? ''
          : (json['ext'] is Map || json['ext'] is List ? jsonEncode(json['ext']) : '${json['ext']}'),
      jar: '${json['jar'] ?? ''}',
      searchable: json['searchable'] as bool? ?? false,
    );
  }

  final String key;
  final String name;

  /// 0 = json api, 1 = js spider, 3 = python spider. Values outside the three
  /// known kinds are kept verbatim: the inventory reports what the repo said.
  final int type;
  final String api;

  /// The site's own extension payload, passed to SpiderHandle.init verbatim.
  /// Structured ext values are serialised once here so every downstream
  /// consumer sees the same string.
  final String ext;

  /// A site-private spider jar override, when the repo names one.
  final String jar;
  final bool searchable;

  /// The runtime a site of this type needs before it can serve anything.
  /// Type 0 sites speak their own api shape per site, which is site-level
  /// protocol work, so the framework treats them like spider sites: pending
  /// until their adapter lands.
  String get requiredRuntime => switch (type) {
    1 => 'js',
    3 => 'python',
    _ => 'site-api',
  };
}

/// One live channel row: a name, the group (category) it belongs to, and one
/// or more urls (multi-source failover is a repo convention, which is why urls
/// is a list).
final class TvBoxChannel {
  const TvBoxChannel({required this.name, required this.group, required this.urls});

  final String name;
  final String group;
  final List<Uri> urls;
}

/// One lives group of a single TVBox repo.
final class TvBoxLiveGroup {
  const TvBoxLiveGroup({required this.group, required this.channels});

  final String group;
  final List<TvBoxChannel> channels;
}

/// What one config file contained.
sealed class TvBoxConfig {
  const TvBoxConfig();

  /// Sites of a single repo. Empty for a multi-repo.
  List<TvBoxSite> get sites;

  /// Live groups of a single repo. Empty for a multi-repo.
  List<TvBoxLiveGroup> get lives;
}

/// A single repo: sites and/or lives, ready to be turned into sources.
final class TvBoxSingleRepo implements TvBoxConfig {
  const TvBoxSingleRepo({required this.sites, required this.lives});

  @override
  final List<TvBoxSite> sites;
  @override
  final List<TvBoxLiveGroup> lives;
}

/// A multi-repo: urls of other repos. Resolving them is fetch work the host
/// does one repo at a time, so a failure in one repo never touches the others.
final class TvBoxMultiRepo implements TvBoxConfig {
  const TvBoxMultiRepo({required this.repoUrls});

  final List<Uri> repoUrls;

  @override
  List<TvBoxSite> get sites => const <TvBoxSite>[];

  @override
  List<TvBoxLiveGroup> get lives => const <TvBoxLiveGroup>[];
}

/// Recognises the config shape and parses it. The three documented shapes are
/// the single repo (`sites`/`lives`), the `urls` multi-repo and the
/// `storeHouse` multi-repo; anything else is a format error, not an empty
/// repository, because an empty repo and an unreadable repo fail differently.
final class TvBoxConfigParser {
  const TvBoxConfigParser();

  TvBoxConfig parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      throw FormatException('TVBox config is not JSON: ${error.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('TVBox config is not a JSON object');
    }
    final config = Map<String, Object?>.from(decoded);

    final multiUrls = <Uri>[];
    final urls = config['urls'];
    if (urls is List) {
      for (final entry in urls) {
        final text = entry is Map ? '${entry['url'] ?? entry['sourceUrl'] ?? ''}' : '$entry';
        final uri = Uri.tryParse(text.trim());
        if (uri != null && uri.host.isNotEmpty) {
          multiUrls.add(uri);
        }
      }
    }
    final storeHouse = config['storeHouse'];
    if (storeHouse is List) {
      for (final entry in storeHouse) {
        final uri = Uri.tryParse('${entry is Map ? entry['sourceUrl'] : entry}'.trim());
        if (uri != null && uri.host.isNotEmpty) {
          multiUrls.add(uri);
        }
      }
    }
    if (multiUrls.isNotEmpty && config['sites'] == null && config['lives'] == null) {
      return TvBoxMultiRepo(repoUrls: multiUrls);
    }

    final sites = <TvBoxSite>[];
    final rawSites = config['sites'];
    if (rawSites is List) {
      for (final entry in rawSites) {
        if (entry is! Map) {
          continue;
        }
        final site = TvBoxSite.fromJson(Map<String, Object?>.from(entry));
        // A site without key or api cannot be addressed by anything downstream;
        // dropping it here keeps one broken row from failing the repo.
        if (site.key.isNotEmpty && site.api.isNotEmpty) {
          sites.add(site);
        }
      }
    }

    final groups = <TvBoxLiveGroup>[];
    final rawLives = config['lives'];
    if (rawLives is List) {
      for (final entry in rawLives) {
        if (entry is! Map) {
          continue;
        }
        final groupName = '${entry['group'] ?? ''}';
        final channels = <TvBoxChannel>[];
        final rawChannels = entry['channels'];
        if (rawChannels is List) {
          for (final channel in rawChannels) {
            if (channel is! Map) {
              continue;
            }
            final urls = <Uri>[
              for (final url in (channel['urls'] as List? ?? const []))
                if (Uri.tryParse('$url') != null) Uri.parse('$url'),
            ];
            if (urls.isNotEmpty) {
              channels.add(TvBoxChannel(name: '${channel['name'] ?? ''}', group: groupName, urls: urls));
            }
          }
        }
        if (channels.isNotEmpty) {
          groups.add(TvBoxLiveGroup(group: groupName, channels: channels));
        }
      }
    }

    if (sites.isEmpty && groups.isEmpty) {
      throw const FormatException('TVBox config carries no sites and no lives');
    }
    return TvBoxSingleRepo(sites: sites, lives: groups);
  }
}

/// Parses an M3U/M3U8 playlist into channel entries. IPTV repos and many live
/// lists ship this format; group-title becomes the category the browse
/// contract filters by.
final class M3uParser {
  const M3uParser();

  List<TvBoxChannel> parse(String text, {String fallbackGroup = 'IPTV'}) {
    final entries = <TvBoxChannel>[];
    String pendingName = '';
    String pendingGroup = fallbackGroup;

    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('#EXTINF')) {
        pendingName = _attribute(line, 'tvg-name') ?? _afterComma(line);
        pendingGroup = _attribute(line, 'group-title') ?? fallbackGroup;
        continue;
      }
      if (line.startsWith('#')) {
        continue;
      }
      final uri = Uri.tryParse(line);
      if (uri == null || uri.host.isEmpty) {
        continue;
      }
      if (pendingName.isEmpty) {
        pendingName = uri.pathSegments.lastOrNull ?? uri.toString();
      }
      // The playlist convention is one url per EXTINF row; a bare url lands
      // under the last group seen.
      entries.add(TvBoxChannel(name: pendingName, group: pendingGroup, urls: <Uri>[uri]));
      pendingName = '';
    }
    return entries;
  }

  String? _attribute(String line, String name) {
    final match = RegExp('$name="([^"]*)"').firstMatch(line);
    if (match == null || match.group(1)!.isEmpty) {
      return null;
    }
    return match.group(1);
  }

  String _afterComma(String line) {
    final comma = line.lastIndexOf(',');
    return comma < 0 ? '' : line.substring(comma + 1).trim();
  }
}
