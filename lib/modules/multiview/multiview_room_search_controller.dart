import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/live_url_tool.dart';
import 'package:pure_live/modules/search/search_capability.dart';
import 'package:pure_live/modules/search/search_controller.dart' show liveSearchRequestTimeout;
import 'package:pure_live/modules/search/search_ranking.dart';

/// Headless room lookup for multi-view cell filling.
///
/// Deliberately separate from the route-bound `SearchController`: that one reads
/// its own `TextEditingController`, raises toasts, unfocuses the keyboard, jumps
/// its `ScrollController`, navigates, and on Windows opens a WebView2-missing
/// dialog from `onInit`. None of that belongs in a non-modal panel that must
/// leave the other cells interactive.
///
/// Only platform search and direct room lookup — no navigation, no dialogs, no
/// toasts; the panel renders [message] and the failure badge itself.
class MultiviewRoomSearchController {
  MultiviewRoomSearchController({
    List<Site>? sites,
    int Function(LiveRoom left, LiveRoom right)? audienceCompare,
  }) : sites = sites ?? List<Site>.unmodifiable(Sites().availableSites()),
       audienceCompare = audienceCompare ?? _settingsAudienceCompare;

  /// Stable platform snapshot, for the same adapter-state reason as the search page.
  final List<Site> sites;

  /// Ordering tie-breaker for equal live status. Injectable because the default
  /// reads Hive-backed settings that a widget test cannot boot.
  final int Function(LiveRoom left, LiveRoom right) audienceCompare;

  static int _settingsAudienceCompare(LiveRoom left, LiveRoom right) =>
      LiveRoom.compareAudienceRanking(
        left,
        right,
        preferRealOnline: SettingsService.to.app.preferRealOnlineCounts.v,
        platformEnabled: SettingsService.to.app.isRealOnlineEnabledFor,
      );

  final results = <LiveRoom>[].obs;
  final loading = false.obs;

  /// Display names of platforms whose request failed or timed out.
  final failedPlatforms = <String>[].obs;

  /// Localised problem text for the panel; empty means nothing to report.
  final message = ''.obs;

  final Map<String, LiveRoom> _raw = <String, LiveRoom>{};
  int _generation = 0;

  /// Platforms the panel may target. IPTV is excluded because its "search" is a
  /// local channel list rather than a keyword lookup.
  List<Site> get selectablePlatforms => sites
      .where((site) => LiveSearchCapabilities.forPlatform(site.id).supportsNativeSearch)
      .toList(growable: false);

  void clear() {
    _generation++;
    _raw.clear();
    results.clear();
    failedPlatforms.clear();
    message.value = '';
  }

  Future<void> search(String keyword, {String platformId = ''}) async {
    final term = keyword.trim();
    final generation = ++_generation;
    message.value = '';
    failedPlatforms.clear();
    _raw.clear();
    if (term.isEmpty) {
      results.clear();
      loading.value = false;
      return;
    }

    final targets = <Site>[];
    if (platformId.trim().isEmpty) {
      targets.addAll(
        sites.where((site) => LiveSearchCapabilities.forPlatform(site.id).supportsNativeSearch),
      );
    } else {
      final site = sites
          .where((element) => element.id.trim().toLowerCase() == platformId.trim().toLowerCase())
          .firstOrNull;
      if (site == null) {
        results.clear();
        loading.value = false;
        message.value = i18n('multiview_unsupported_platform');
        return;
      }
      if (!LiveSearchCapabilities.forPlatform(site.id).supportsNativeSearch) {
        // Keyword search is unavailable here; the full search page still offers
        // its web-search fallback, which this panel deliberately does not clone.
        results.clear();
        loading.value = false;
        message.value = i18n('search_web_only_platform', args: {'site': site.name});
        return;
      }
      targets.add(site);
    }

    if (targets.isEmpty) {
      results.clear();
      loading.value = false;
      return;
    }

    loading.value = true;
    final batches = await boundedAsyncMap<Site, _MultiviewSearchBatch>(
      targets,
      maxConcurrent: 3,
      shouldCancel: () => generation != _generation,
      task: (site) async {
        try {
          final rooms = await site.liveSite
              .searchRooms(term, page: 1, pageSize: 20)
              .timeout(liveSearchRequestTimeout);
          return _MultiviewSearchBatch(site: site, rooms: rooms);
        } on TimeoutException {
          return _MultiviewSearchBatch(site: site, rooms: const <LiveRoom>[], failed: true);
        } catch (error) {
          debugPrint('Native search failed for ${site.id}: $error');
          return _MultiviewSearchBatch(site: site, rooms: const <LiveRoom>[], failed: true);
        }
      },
    );

    // A superseded search (the user retyped) must not publish stale results.
    if (generation != _generation) return;

    final failures = <String>[];
    for (final batch in batches.whereType<_MultiviewSearchBatch>()) {
      if (batch.failed) failures.add(batch.site.name);
      for (final room in batch.rooms) {
        _raw.putIfAbsent(_roomKey(room), () => room);
      }
    }
    failedPlatforms.addAll(failures);
    if (failures.isNotEmpty) message.value = i18n('multiview_search_failed');
    results.assignAll(
      LiveSearchRanking.apply(
        rooms: _raw.values,
        mode: LiveSearchSortMode.smart,
        includeOffline: true,
        platformOrder: [for (final site in sites) site.id],
        audienceCompare: audienceCompare,
      ),
    );
    loading.value = false;
  }

  /// Accepts a share link / page URL, or a bare room id plus a platform.
  Future<LiveRoom?> resolveDirect(String input, {String platformId = ''}) async {
    final value = input.trim();
    if (value.isEmpty) return null;
    message.value = '';

    String roomId = value;
    String platform = platformId.trim().toLowerCase();
    if (value.contains('://') || value.contains('/')) {
      try {
        final parsed = await LiveUrlTool.parseLiveUrl(value);
        if (parsed.isEmpty) return null;
        roomId = parsed.first;
        platform = parsed.length > 1 ? parsed[1].trim().toLowerCase() : platform;
      } catch (error) {
        debugPrint('multiview direct link parse failed: $error');
        return null;
      }
    }

    if (!Sites.isSupported(platform)) {
      message.value = i18n('multiview_unsupported_platform');
      return null;
    }
    final liveSite =
        sites.where((site) => site.id.trim().toLowerCase() == platform).firstOrNull?.liveSite ??
        Sites.of(platform).liveSite;
    try {
      return await liveSite
          .getRoomDetail(platform: platform, roomId: roomId)
          .timeout(liveSearchRequestTimeout);
    } catch (error) {
      debugPrint('multiview direct room lookup failed: $error');
      message.value = i18n('get_room_info_failed_retry');
      return null;
    }
  }

  static String _roomKey(LiveRoom room) {
    final platform = room.platform?.trim().toLowerCase() ?? 'unknown';
    final roomId = room.roomId?.trim() ?? '';
    if (roomId.isNotEmpty) return '$platform:$roomId';
    return '$platform:${room.nick?.trim()}:${room.title?.trim()}';
  }
}

class _MultiviewSearchBatch {
  const _MultiviewSearchBatch({required this.site, required this.rooms, this.failed = false});

  final Site site;
  final List<LiveRoom> rooms;
  final bool failed;
}
