import 'package:meta/meta.dart';

/// What the last time this address was probed said about it.
///
/// Keyed by URL rather than by channel, because one address is shared by
/// the channels of a re-sold list and is reached by the alternatives of
/// another; a per-channel verdict would have to be re-earned line by line.
/// [failures] counts consecutive failures, so a source that answers again
/// after three bad rounds is not still quarantined behind them.
/// The record is written by `mergeIptvLineHealth` and read by
/// `rankIptvLines`; nothing rewrites it in place.
///
/// Hand-written rather than Freezed, unlike the records beside it: it is
/// stored as a plain map with a `Duration` split into milliseconds, and the
/// tolerance that needs — an absent latency, a negative failure count, a
/// timestamp that does not parse — is the kind generated code argues with.
// ignore_for_file: unnecessary_type_name_in_constructor -- this SDK has no
// `new.named` shorthand: a named constructor must repeat its type name.
@immutable
class IptvLineHealth {
  /// A probe verdict.
  const new({
    required this.url,
    required this.ok,
    required this.checkedAt,
    this.latency,
    this.failures = 0,
    this.message,
  });

  /// A successful verdict.
  const IptvLineHealth.probe({
    required String url,
    required DateTime checkedAt,
    required Duration latency,
    String? message,
  }) : this(url: url, ok: true, checkedAt: checkedAt, latency: latency, failures: 0, message: message);

  /// A failed verdict one probe worse than [previous].
  factory IptvLineHealth.failed({
    required String url,
    required DateTime checkedAt,
    String? message,
    IptvLineHealth? previous,
  }) => IptvLineHealth(
    url: url,
    ok: false,
    checkedAt: checkedAt,
    latency: previous?.latency,
    failures: (previous?.failures ?? 0) + 1,
    message: message,
  );

  /// The address this describes.
  final String url;

  /// Whether the last probe could read from it.
  final bool ok;

  /// How long the last probe took to get its first bytes, when it got any.
  final Duration? latency;

  /// When the verdict was made; an old one says less than a fresh one.
  final DateTime checkedAt;

  /// How many probes in a row failed; zero after a successful one.
  final int failures;

  /// Why it failed, for the screen and the log.
  final String? message;

  /// This record as the JSON the keyed store holds.
  Map<String, Object?> toJson() => {
    'url': url,
    'ok': ok,
    'checkedAt': checkedAt.toIso8601String(),
    'latencyMs': latency?.inMilliseconds,
    'failures': failures,
    'message': message,
  };

  /// Restores a record, dropping an entry whose address is missing.
  static IptvLineHealth? fromJson(Map<String, Object?> json) {
    final url = json['url'];
    final ok = json['ok'];
    final checkedAt = json['checkedAt'];
    if (url is! String || url.isEmpty || ok is! bool || checkedAt is! String) {
      return null;
    }
    final moment = DateTime.tryParse(checkedAt);
    if (moment == null) {
      return null;
    }
    final latencyMs = json['latencyMs'];
    final failures = json['failures'];
    final message = json['message'];
    return IptvLineHealth(
      url: url,
      ok: ok,
      checkedAt: moment,
      latency: latencyMs is int ? Duration(milliseconds: latencyMs) : null,
      failures: failures is int && failures > 0 ? failures : 0,
      message: message is String ? message : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IptvLineHealth &&
      other.url == url &&
      other.ok == ok &&
      other.checkedAt == checkedAt &&
      other.latency == latency &&
      other.failures == failures &&
      other.message == message;

  @override
  int get hashCode => Object.hash(url, ok, checkedAt, latency, failures, message);

  @override
  String toString() => 'IptvLineHealth($url, ${ok ? 'ok' : 'down'}, failures: $failures)';
}
