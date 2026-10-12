import 'package:live_iptv/src/model/epg_programme/epg_programme.dart';
import 'package:meta/meta.dart';

/// What a guide channel is showing, and what comes next.
///
/// [at] is part of the value rather than an argument to the getters: a slot
/// is read at one instant and drawn over some seconds after, and a progress
/// bar that quietly re-asks `DateTime.now()` disagrees with the "还剩 12 分钟"
/// beside it. The caller passes the clock it showed the user.
///
/// [next] is null when the guide has nothing after [current] — which is a
/// different fact from "this channel has no programme list at all", and
/// [isEmpty] says which of the two it is.
@immutable
final class IptvProgrammeSlot {
  /// A slot as read at [at].
  const new({required this.at, this.current, this.next});

  /// The programme on air at [at], null just before the first or after the
  /// last programme of the day.
  final EpgProgramme? current;

  /// The one after it, null when the guide stops here.
  final EpgProgramme? next;

  /// The instant this was read at.
  final DateTime at;

  /// Whether the guide said nothing about this moment: no mapping, or a
  /// programme list that does not cover it.
  bool get isEmpty => current == null && next == null;

  /// What to show as the channel's subtitle: what is on, else what is next.
  String? get title => current?.title.isNotEmpty ?? false ? current!.title : next?.title;

  /// How far [current] has run, 0 to 1; null when nothing is on or its
  /// length is unknown.
  double? get progress {
    final programme = current;
    if (programme == null) {
      return null;
    }
    final total = programme.stop.difference(programme.start);
    if (total <= Duration.zero) {
      return null;
    }
    final done = at.difference(programme.start);
    return (done.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }

  /// How long [current] has left, null when nothing is on.
  Duration? get remaining => current == null ? null : _positive(current!.stop.difference(at));

  /// How long until [next] starts, null when there is none or it is under way.
  Duration? get untilNext => next == null ? null : _positive(next!.start.difference(at));

  static Duration _positive(Duration value) => value.isNegative ? Duration.zero : value;

  @override
  bool operator ==(Object other) =>
      other is IptvProgrammeSlot && other.current == current && other.next == next && other.at == at;

  @override
  int get hashCode => Object.hash(current, next, at);

  @override
  String toString() => 'IptvProgrammeSlot(${current?.title ?? '-'}, next: ${next?.title ?? '-'})';
}
