import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show EpgEntry, EpgGuide, EpgParser, IptvChannel, iptvBytesFetcherFor;
import 'package:pure_live/app/app_providers.dart';

/// How long a channel or guide name may travel before name matching gives
/// up — the matcher's own normalisation, so both sides of a comparison are
/// reduced the same way.
final RegExp _nonWord = RegExp('[^a-zA-Z0-9\u4e00-\u9fa5]');

String _normalize(String value) => value.toLowerCase().replaceAll(_nonWord, '');

/// One downloaded guide with the two indexes its lookups need.
final class _LoadedGuide {
  new(EpgGuide guide)
    : guide = guide,
      ids = {for (final channel in guide.channels) channel.id.trim().toLowerCase()},
      _idsByName = _indexNames(guide);

  final EpgGuide guide;

  /// Every channel id of the guide, lowercased — the test a `tvg-id` has to
  /// pass before it is believed.
  final Set<String> ids;
  final Map<String, String> _idsByName;

  /// The guide channel id a playlist channel named [name] should read, or
  /// null: an exact normalized name first, then a containment that names
  /// exactly one guide channel — the matcher's own rule, so a name that
  /// would have matched two channels matches none.
  String? idByName(String name) {
    final normalized = _normalize(name);
    if (normalized.isEmpty) {
      return null;
    }
    final exact = _idsByName[normalized];
    if (exact != null) {
      return exact;
    }
    String? found;
    for (final entry in _idsByName.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        if (found != null) {
          return null;
        }
        found = entry.value;
      }
    }
    return found;
  }

  static Map<String, String> _indexNames(EpgGuide guide) {
    final index = <String, String>{};
    for (final channel in guide.channels) {
      final id = channel.id.trim();
      if (id.isEmpty) {
        continue;
      }
      for (final name in channel.displayNames) {
        final normalized = _normalize(name);
        if (normalized.isNotEmpty) {
          index.putIfAbsent(normalized, () => id);
        }
      }
    }
    return index;
  }
}

/// The programme guides of the session, in memory only: fetched once per
/// address, asked by the play page for the current and upcoming programmes
/// of whichever channel is on screen, and re-read only on an explicit
/// refresh.
///
/// An address that failed is remembered as failed until a refresh, so a
/// dead guide URL costs one download per session rather than one per
/// rebuild. Nothing here is persisted — a guide is a day's programme list,
/// and the next session can ask the server again.
final class IptvGuideCache {
  /// A cache reading remote guides through the parser it is constructed with.
  new(this._parser);

  final EpgParser _parser;
  final Map<String, _LoadedGuide> _guides = {};
  final Set<String> _failed = {};
  final Map<String, Future<void>> _inFlight = {};

  /// Whether no guide is available at all — the play page's sign that no
  /// EPG strip should exist, whether for want of an address or because
  /// every fetch failed.
  bool get isEmpty => _guides.isEmpty;

  /// Fetches every address of [urls] the cache does not hold yet; failures
  /// are swallowed (and remembered) because an absent guide is an absence,
  /// not an error the viewer can act on here. Safe to call repeatedly.
  Future<void> ensureLoaded(Iterable<String> urls) async {
    final wanted = urls.where((url) => url.trim().isNotEmpty && !_guides.containsKey(url) && !_failed.contains(url));
    if (wanted.isEmpty) {
      return;
    }
    await Future.wait([for (final url in wanted) _fetch(url)]);
  }

  /// Forgets what the cache holds for [urls] — successes and failures
  /// alike — and reads them again.
  Future<void> refresh(Iterable<String> urls) async {
    final wanted = urls.where((url) => url.trim().isNotEmpty).toSet();
    for (final url in wanted) {
      _guides.remove(url);
      _failed.remove(url);
    }
    await Future.wait([for (final url in wanted) _fetch(url)]);
  }

  Future<void> _fetch(String url) {
    return _inFlight.putIfAbsent(url, () async {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.hasScheme) {
        _failed.add(url);
        return;
      }
      try {
        _guides[url] = _LoadedGuide(await _parser.fetchGuide(uri));
      } on Object {
        _failed.add(url);
      } finally {
        unawaited(_inFlight.remove(url));
      }
    });
  }

  /// The programme on air on [channel] at [now], or null when no loaded
  /// guide names it.
  EpgEntry? currentFor(IptvChannel channel, DateTime now) {
    for (final loaded in _guides.values) {
      final id = _resolveId(loaded, channel);
      if (id == null) {
        continue;
      }
      final current = loaded.guide.currentFor(id, now);
      if (current != null) {
        return current;
      }
      // The guide knows the channel but is silent right now (a schedule
      // gap): the same guide's upcoming list is the honest answer, and the
      // next guide has no better claim.
      return null;
    }
    return null;
  }

  /// The programmes of [channel] that have not begun at [now], soonest
  /// first, from the first guide that names the channel.
  List<EpgEntry> upcomingFor(IptvChannel channel, DateTime now, {int? limit}) {
    for (final loaded in _guides.values) {
      final id = _resolveId(loaded, channel);
      if (id != null) {
        return loaded.guide.upcomingFor(id, now, limit: limit);
      }
    }
    return const [];
  }

  /// The guide channel id [channel] reads as in [loaded]: its `tvg-id` when
  /// the guide carries it, else the channel's own name matched the way the
  /// matcher matches — never a guess between two candidates.
  String? _resolveId(_LoadedGuide loaded, IptvChannel channel) {
    final tvgId = channel.entry.tvgId?.trim() ?? '';
    if (tvgId.isNotEmpty && loaded.ids.contains(tvgId.toLowerCase())) {
      return tvgId;
    }
    return loaded.idByName(channel.entry.name);
  }
}

/// The session's guide cache, reading over the app's shared HTTP client —
/// gzipped and plain guides alike, as the bytes fetcher decides.
final iptvEpgProvider = Provider<IptvGuideCache>(
  (ref) => IptvGuideCache(EpgParser(fetchBytes: iptvBytesFetcherFor(ref.watch(httpProvider)))),
);
