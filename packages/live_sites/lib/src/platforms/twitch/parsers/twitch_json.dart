import 'dart:convert';

import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';

const TwitchFailureKind _apiChanged = TwitchFailureKind.apiChanged;

/// JSON plumbing for Twitch's GraphQL answers, shared by the parsers: the
/// loose accessors (a wrong type reads as absent rather than throwing) and
/// the envelope rules (HTTP status, the integrity challenge, an unknown
/// persisted query).
///
/// The parsers and the transport never see a raw map they must guard:
/// [object]/[list]/[textOf] return the empty value for anything of another
/// type, and numbers-as-strings come back as text with [stringOf].
abstract final class TwitchJson {
  /// A GraphQL answer: an envelope, or a list of them for a batch. HTTP 401
  /// is [TwitchFailureKind.needsLogin] (a stale session), 429 rate-limited,
  /// 5xx network, another non-2xx status or a body that is no envelope
  /// api-changed; an integrity challenge anywhere is
  /// [TwitchFailureKind.riskControl].
  static Object decode(String body, {required int status, required String what}) {
    if (status == 401) throw TwitchFailure(TwitchFailureKind.needsLogin, '$what: HTTP 401');
    if (status == 429) throw TwitchFailure(TwitchFailureKind.rateLimited, '$what: HTTP 429');
    if (status >= 500) throw TwitchFailure(TwitchFailureKind.network, '$what: HTTP $status');
    if (status < 200 || status >= 300) {
      throw TwitchFailure(_apiChanged, '$what: HTTP $status (${snippet(body)})');
    }
    final decoded = tryDecode(body);
    if (decoded is! Map && decoded is! List) {
      throw TwitchFailure(_apiChanged, '$what: not a GraphQL answer (${snippet(body)})');
    }
    if (isIntegrityRejection(decoded)) {
      throw TwitchFailure(TwitchFailureKind.riskControl, '$what: integrity check required');
    }
    return decoded!;
  }

  /// Whether Twitch asked for a browser's integrity token: an error mentioning
  /// `failed integrity check` or `integrity token`, or an
  /// `extensions.challenge`, in any envelope.
  static bool isIntegrityRejection(Object? decoded) {
    if (decoded is List) return decoded.any(isIntegrityRejection);
    if (decoded is! Map) return false;
    final extensions = decoded['extensions'];
    if (extensions is Map && extensions['challenge'] != null) return true;
    final errors = decoded['errors'];
    return errors is List &&
        errors.any((error) {
          final message = '${error is Map ? error['message'] : ''}'.toLowerCase();
          return message.contains('failed integrity check') || message.contains('integrity token');
        });
  }

  /// The envelopes of a batch of [expected] operations, in request order.
  static List<Object?> batch(Object? decoded, {required int expected, required String what}) {
    final envelopes = decoded is List ? decoded.cast<Object?>() : [decoded];
    if (envelopes.length != expected) {
      throw TwitchFailure(_apiChanged, '$what: ${envelopes.length} answers for $expected operations');
    }
    return envelopes;
  }

  /// One envelope's `data` (null when missing) and error messages. An unknown
  /// persisted query is api-changed whatever else it holds: the web client's
  /// hash changed and every request with it fails.
  static ({Map<String, dynamic>? data, List<String> errors}) envelope(Object? decoded, String what) {
    final single = decoded is List ? (decoded.isEmpty ? null : decoded.first) : decoded;
    if (single is! Map<String, dynamic>) throw TwitchFailure(_apiChanged, '$what: no envelope');
    final errors = [
      for (final error in list(single['errors']))
        if (error is Map) '${error['message'] ?? ''}',
    ];
    if (errors.any((message) => message.contains('PersistedQueryNotFound'))) {
      throw TwitchFailure(_apiChanged, '$what: persisted query no longer known');
    }
    return (data: object(single['data']), errors: errors);
  }

  /// The `data` of one envelope ([decoded] may be a batch of one). Errors only
  /// count when they left no data (partial `service error`s are common): then
  /// the answer is api-changed.
  static Map<String, dynamic> data(Object? decoded, String what) {
    final read = envelope(decoded, what);
    if (read.data case final value?) return value;
    final messages = read.errors.isEmpty ? '' : ' (${read.errors.join('; ')})';
    throw TwitchFailure(_apiChanged, '$what: no data$messages');
  }

  /// The body decoded, null when it is not JSON.
  static Object? tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// A map, or null when [value] is not one.
  static Map<String, dynamic>? object(Object? value) => value is Map<String, dynamic> ? value : null;

  /// A map, or the empty map.
  static Map<String, dynamic> fields(Object? value) => object(value) ?? const <String, dynamic>{};

  /// A list, or the empty list.
  static List<Object?> list(Object? value) => value is List ? value.cast<Object?>() : const [];

  /// Any value as the text Twitch's own `toString()` would write; null is the
  /// empty string (a field that is absent reads as empty, never as a crash).
  static String textOf(Object? value) => value == null ? '' : '$value';

  /// A value as a string, null when there is none (an empty string is kept).
  static String? stringOf(Object? value) => value == null ? null : '$value';

  /// A value as an int (a number or a digit string), null when it is neither.
  static int? intOf(Object? value) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value.trim()),
    _ => null,
  };

  /// A Relay connection's edges and whether `pageInfo.hasNextPage` is true (a
  /// missing `pageInfo` ends the list).
  static ({List<Map<String, dynamic>> edges, bool hasNextPage}) connection(Object? value) {
    final node = object(value);
    return (
      edges: [for (final edge in list(node?['edges'])) ?object(edge)],
      hasNextPage: object(node?['pageInfo'])?['hasNextPage'] == true,
    );
  }

  /// The last edge's cursor when the connection says there is a next page,
  /// else null.
  static String? nextCursor(({List<Map<String, dynamic>> edges, bool hasNextPage}) value) =>
      value.hasNextPage && value.edges.isNotEmpty ? stringOf(value.edges.last['cursor']) : null;

  /// An ISO 8601 time (`2026-09-27T12:49:35Z`) as UTC; null when missing,
  /// unreadable or not after 1970.
  static DateTime? time(Object? value) {
    final parsed = DateTime.tryParse(stringOf(value) ?? '')?.toUtc();
    return parsed == null || parsed.millisecondsSinceEpoch <= 0 ? null : parsed;
  }

  /// The first 80 characters of a body, whitespace collapsed — enough to
  /// name a changed answer without quoting a page.
  static String snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }
}
