import 'package:live_iptv/src/model/epg_programme/epg_programme.dart';
import 'package:live_iptv/src/model/guide_channel/guide_channel.dart';
import 'package:live_iptv/src/model/parsed_guide/parsed_guide.dart';

/// A programme guide held in memory, answering the viewer's two questions:
/// what is on a channel now, and what comes next.
///
/// The parser fills it; the player reads it — [currentFor] for the banner
/// under the video, [upcomingFor] for the "next" list. Intervals are
/// half-open, as everywhere in this package: a programme is current from
/// its start instant (inclusive) to its stop instant (exclusive), and
/// upcoming the moment it has not yet begun.
///
/// The lookups scan one channel's slice of [entries] rather than an index
/// built at construction: a guide is parsed once and asked per channel, and
/// the slice is what XMLTV already delivered.
final class EpgGuide {
  /// A guide; [EpgGuide.fromParsed] is the usual way in.
  new({List<GuideChannel> channels = const [], List<EpgEntry> entries = const []})
    : channels = List.unmodifiable(channels),
      entries = List.unmodifiable(entries);

  /// Builds a guide from what a parser read.
  factory fromParsed(ParsedGuide parsed) => EpgGuide(channels: parsed.channels, entries: parsed.programmes);

  /// The guide's channels, in file order.
  final List<GuideChannel> channels;

  /// Every programme of every channel, in file order.
  final List<EpgEntry> entries;

  /// Whether the guide said nothing at all: an empty download, or one no
  /// parser could read a single row of.
  bool get isEmpty => channels.isEmpty && entries.isEmpty;

  /// The programme on air on [channelId] at [now], or null.
  ///
  /// [now] is passed rather than read from the clock, so a screen built
  /// once shows times that agree with each other. When a guide's rows
  /// overlap, the one that started last wins — it is the one the viewer is
  /// actually watching.
  EpgEntry? currentFor(String channelId, DateTime now) {
    EpgEntry? current;
    for (final entry in entries) {
      if (entry.channelId != channelId) {
        continue;
      }
      final begun = !now.isBefore(entry.start);
      final notOver = now.isBefore(entry.stop);
      if (begun && notOver && (current == null || entry.start.isAfter(current.start))) {
        current = entry;
      }
    }
    return current;
  }

  /// The programmes of [channelId] that have not started at [now], soonest
  /// first, at most [limit] of them when given.
  ///
  /// A fresh list every call: the guide itself never changes, but the answer
  /// is ordered for the screen and screens re-render.
  List<EpgEntry> upcomingFor(String channelId, DateTime now, {int? limit}) {
    final upcoming = [
      for (final entry in entries)
        if (entry.channelId == channelId && now.isBefore(entry.start)) entry,
    ]..sort((a, b) => a.start.compareTo(b.start));
    if (limit != null && limit >= 0 && limit < upcoming.length) {
      return upcoming.sublist(0, limit);
    }
    return upcoming;
  }
}
