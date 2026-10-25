import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveAudienceMetricType, LiveRoom;
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

/// The figure a card shows for [room] under [choice]: the chosen metric
/// first, then whatever else the source gave (a source without concurrent
/// viewers should not show a blank card because the viewer asked for them).
int? audienceFigureOf(LiveRoom room, AudienceMetricChoice choice) {
  final audience = room.audience;
  int? firstOf(Iterable<int?> values) {
    for (final value in values) {
      if (value != null) return value;
    }
    return null;
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
