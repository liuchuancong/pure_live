import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show LiveAudienceCapability, LiveAudienceMetricType, LiveRoom, LiveRoomIdentity, SiteIds;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// Which figure a room card leads with, independent of what the platform
/// marked as its primary metric.
enum AudienceMetricChoice {
  /// The platform's own primary metric, then any figure.
  automatic,

  /// Concurrent viewers.
  onlineViewers,

  /// The platform's heat/popularity figure.
  popularity,

  /// Cumulative viewers.
  totalViewers,
}

/// The pref key the choice lives under.
const String kAudienceMetricPref = 'browse.audienceMetric';

/// The pref key the "real online first" preference lives under.
const String kPreferRealOnlinePref = 'browse.preferRealOnline';

/// The pref key the platforms the preference applies to live under.
const String kRealOnlinePlatformsPref = 'browse.realOnlinePlatforms';

/// The platforms the reference enables for "real online first" out of the
/// box (all of them publish a concurrent-viewer count).
const List<String> kDefaultRealOnlinePlatforms = [
  SiteIds.douyin,
  SiteIds.kuaishou,
  SiteIds.cc,
  SiteIds.twitch,
  SiteIds.soop,
  SiteIds.acfun,
  SiteIds.picarto,
  SiteIds.twitcasting,
];

/// Drops unknown, duplicate and unsupported platform ids (the reference's
/// `normalizeRealOnlinePlatforms`).
List<String> normalizeRealOnlinePlatforms(Iterable<String> platforms) {
  final normalized = <String>[];
  for (final raw in platforms) {
    final id = raw.trim().toLowerCase();
    if (id.isEmpty || normalized.contains(id)) continue;
    if (!LiveAudienceCapability.of(id).supportsConcurrentOnline) continue;
    normalized.add(id);
  }
  return normalized;
}

/// The audience preferences: whether a platform's concurrent-viewer count
/// leads, and which platforms that applies to.
final class AudiencePolicy {
  /// Creates a policy.
  const AudiencePolicy({this.preferRealOnline = false, this.platforms = const <String>{}});

  /// Whether concurrent viewers lead on the enabled platforms.
  final bool preferRealOnline;

  /// The platform ids the preference applies to.
  final Set<String> platforms;

  /// Whether the preference reaches [platform].
  bool enabledFor(String platform) => platforms.contains(platform.trim().toLowerCase());
}

/// The figure a card shows for [room] under [choice]: the chosen metric
/// first, then whatever else the source gave (a source without concurrent
/// viewers should not show a blank card because the viewer asked for them).
///
/// Under [AudienceMetricChoice.automatic] a room on a platform enabled in
/// [policy] leads with its concurrent viewers (the reference's
/// `preferRealOnlineCounts`) rather than the platform's own primary metric.
int? audienceFigureOf(LiveRoom room, AudienceMetricChoice choice, {AudiencePolicy policy = const AudiencePolicy()}) {
  final audience = room.audience;
  int? firstOf(Iterable<int?> values) {
    for (final value in values) {
      if (value != null) return value;
    }
    return null;
  }

  if (choice == AudienceMetricChoice.automatic &&
      policy.preferRealOnline &&
      policy.enabledFor(room.platform) &&
      LiveAudienceCapability.of(room.platform).supportsConcurrentOnline) {
    final online = audience.onlineViewers;
    if (online != null) return online;
  }

  return switch (choice) {
    AudienceMetricChoice.automatic => switch (audience.primaryMetric) {
      LiveAudienceMetricType.onlineViewers => firstOf([
        audience.onlineViewers,
        audience.popularity,
        audience.totalViewers,
      ]),
      LiveAudienceMetricType.totalViewers => firstOf([
        audience.totalViewers,
        audience.popularity,
        audience.onlineViewers,
      ]),
      _ => firstOf([audience.popularity, audience.onlineViewers, audience.totalViewers]),
    },
    AudienceMetricChoice.onlineViewers => firstOf([audience.onlineViewers, audience.popularity, audience.totalViewers]),
    AudienceMetricChoice.popularity => firstOf([audience.popularity, audience.onlineViewers, audience.totalViewers]),
    AudienceMetricChoice.totalViewers => firstOf([audience.totalViewers, audience.popularity, audience.onlineViewers]),
  };
}

/// The viewer's card-metric choice, persisted under
/// `browse.audienceMetric`; the cards read it live.
final class AudienceMetricController extends Notifier<AudienceMetricChoice> {
  @override
  AudienceMetricChoice build() {
    try {
      return AudienceMetricChoice.values.asNameMap()[StoragePrefs.getString(kAudienceMetricPref) ?? ''] ??
          AudienceMetricChoice.automatic;
    } on Object {
      return AudienceMetricChoice.automatic;
    }
  }

  /// Stores [choice]; automatic is the unset default.
  Future<void> select(AudienceMetricChoice choice) async {
    state = choice;
    try {
      await StoragePrefs.setString(kAudienceMetricPref, choice.name);
    } on Object {
      // The choice is a preference; a closed store loses it.
    }
  }
}

/// The card audience metric.
final audienceMetricProvider = NotifierProvider<AudienceMetricController, AudienceMetricChoice>(
  AudienceMetricController.new,
);

/// The "real online first" preference and the platforms it reaches,
/// persisted under `browse.preferRealOnline` and
/// `browse.realOnlinePlatforms`; the cards and the audience sort read them
/// live.
final class AudiencePolicyController extends Notifier<AudiencePolicy> {
  @override
  AudiencePolicy build() {
    try {
      final stored = StoragePrefs.getStringList(kRealOnlinePlatformsPref);
      return AudiencePolicy(
        preferRealOnline: StoragePrefs.getBool(kPreferRealOnlinePref) ?? false,
        platforms: {...normalizeRealOnlinePlatforms(stored ?? kDefaultRealOnlinePlatforms)},
      );
    } on Object {
      return AudiencePolicy(platforms: kDefaultRealOnlinePlatforms.toSet());
    }
  }

  /// Turns the preference on or off; the enabled platforms stay as stored.
  Future<void> setPreferRealOnline({required bool value}) async {
    state = AudiencePolicy(preferRealOnline: value, platforms: state.platforms);
    try {
      await StoragePrefs.setBool(kPreferRealOnlinePref, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Adds or removes [platform]; a platform without a concurrent-viewer
  /// count is ignored, as in the reference.
  Future<void> setPlatformEnabled(String platform, {required bool enabled}) async {
    final id = platform.trim().toLowerCase();
    if (!LiveAudienceCapability.of(id).supportsConcurrentOnline) return;
    final next = {...state.platforms};
    if (enabled) {
      next.add(id);
    } else {
      next.remove(id);
    }
    state = AudiencePolicy(preferRealOnline: state.preferRealOnline, platforms: next);
    try {
      await StoragePrefs.setStringList(kRealOnlinePlatformsPref, next.toList()..sort());
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The real-online preference and its platforms.
final audiencePolicyProvider = NotifierProvider<AudiencePolicyController, AudiencePolicy>(AudiencePolicyController.new);
