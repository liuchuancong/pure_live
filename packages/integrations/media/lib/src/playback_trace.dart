// Module: lib/src/playback_trace.dart
// Purpose: One playback's evidence chain, and the redacted report a user can export from it.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/diagnostics/playback-diagnostics.md and docs/diagnostics/tracing.md. The point of the document is
// turning "cannot reproduce" into an exportable chain, so this type is the record that survives a failure:
// the stages playback went through, the tickets it was given, and the last fault.
//
// Redaction is enforced here rather than at each caller. docs/diagnostics/playback-diagnostics.md states the
// report must carry no credentials or personal data, and a rule that depends on every reporter remembering to
// scrub is not a rule - the ticket url is exactly the field that carries a site's signed token.

import 'package:pure_live_platform/pure_live_platform.dart';

/// A stage in one playback attempt. Names follow docs/diagnostics/tracing.md's playback event list.
enum PlaybackStage {
  request,
  resolve,
  ticketIssued,
  prepare,
  started,
  buffering,
  ticketRefreshed,
  lineSwitched,
  engineSwitched,
  failed,
  stopped,
}

/// Which component owns a fix, from playback-diagnostics.md's feedback loop: a resolve failure is a source
/// problem, a network failure is the transport's, a playback failure is the engine's. Guessing "the player is
/// broken" for a site that changed its protocol is what makes that loop useless.
enum PlaybackFaultOwner { source, network, media, unknown }

/// One ticket a playback was given, kept in a form that is safe to export.
final class PlaybackTicketRecord {
  const PlaybackTicketRecord({
    required this.ticketId,
    required this.issuedAt,
    required this.host,
    this.expiresAt,
    this.quality,
    this.line,
    this.protocol,
    this.refreshCount = 0,
  });

  factory PlaybackTicketRecord.from(MediaTicket ticket) {
    return PlaybackTicketRecord(
      ticketId: ticket.id,
      issuedAt: ticket.createdAt,
      // The host only: a signed path and query are the credential-bearing part of a media url.
      host: ticket.uri.host,
      expiresAt: ticket.expiresAt,
      quality: ticket.metadata.extra['platform.quality'] as String?,
      line: ticket.metadata.extra['platform.line'] as String?,
      protocol: ticket.protocol.name,
    );
  }

  final String ticketId;
  final DateTime issuedAt;
  final String host;
  final DateTime? expiresAt;
  final String? quality;
  final String? line;
  final String? protocol;
  final int refreshCount;

  Map<String, Object?> toJson() {
    final expiry = expiresAt;
    return <String, Object?>{
      'ticketId': ticketId,
      'issuedAt': _utc(issuedAt),
      'host': host,
      if (expiry != null) 'expiresAt': _utc(expiry),
      if (quality != null) 'quality': quality,
      if (line != null) 'line': line,
      if (protocol != null) 'protocol': protocol,
      if (refreshCount > 0) 'refreshCount': refreshCount,
    };
  }
}

/// One observed stage.
final class PlaybackMark {
  const PlaybackMark(this.stage, this.at, {this.detail});

  final PlaybackStage stage;
  final DateTime at;

  /// Free text for a human reader. It is scrubbed at report time, so a caller that pastes a url into it does
  /// not leak the token in it.
  final String? detail;

  Map<String, Object?> toJson() => <String, Object?>{
    'stage': stage.name,
    'at': _utc(at),
    if (detail != null) 'detail': redactText(detail!),
  };
}

/// The evidence chain for one playback attempt.
///
/// Bounded by construction: a diagnostic that can grow without limit during a long live session is how an
/// app runs out of memory while trying to explain a smaller problem.
final class PlaybackTrace {
  PlaybackTrace({required this.traceId, this.content, this.extensionId, this.sourceId, this.capacity = 128});

  final String traceId;
  final ContentRef? content;
  final String? extensionId;
  final String? sourceId;
  final int capacity;

  final List<PlaybackMark> _marks = <PlaybackMark>[];
  final List<PlaybackTicketRecord> _tickets = <PlaybackTicketRecord>[];
  final List<String> _networkSummary = <String>[];

  /// The failure this trace ended on, if it did. Kept apart from the marks because the report leads with it.
  PlatformErrorInfo? fault;

  List<PlaybackMark> get marks => List<PlaybackMark>.unmodifiable(_marks);

  List<PlaybackTicketRecord> get tickets => List<PlaybackTicketRecord>.unmodifiable(_tickets);

  bool get hasFailed => fault != null;

  /// Adds one stage, dropping the oldest when full and recording that it did.
  void mark(PlaybackStage stage, DateTime at, {String? detail}) {
    _marks.add(PlaybackMark(stage, at, detail: detail));
    while (_marks.length > capacity) {
      _marks.removeAt(0);
    }
  }

  /// Records a ticket handed to this playback, counting repeats by id as refreshes of the same content.
  void recordTicket(MediaTicket ticket) {
    final existing = _tickets.indexWhere((record) => record.ticketId == ticket.id);
    if (existing >= 0) {
      final previous = _tickets[existing];
      _tickets[existing] = PlaybackTicketRecord(
        ticketId: previous.ticketId,
        issuedAt: previous.issuedAt,
        host: previous.host,
        expiresAt: ticket.expiresAt,
        quality: previous.quality,
        line: previous.line,
        protocol: previous.protocol,
        refreshCount: previous.refreshCount + 1,
      );
      return;
    }
    _tickets.add(PlaybackTicketRecord.from(ticket));
    while (_tickets.length > capacity) {
      _tickets.removeAt(0);
    }
  }

  /// Adds one line of the network summary (status and host, never headers).
  void noteNetwork(String observation) {
    _networkSummary.add(redactText(observation));
    while (_networkSummary.length > capacity) {
      _networkSummary.removeAt(0);
    }
  }

  /// Ends the trace on [error]. [at] is injectable because the caller usually knows the timestamp the
  /// failure carries and `now` is a second guess on top of it.
  void fail(PlatformErrorInfo error, {DateTime? at}) {
    fault = error;
    mark(PlaybackStage.failed, at ?? DateTime.now().toUtc(), detail: error.code);
  }

  /// Which component owns the fix for this trace's failure.
  PlaybackFaultOwner classifyFault() {
    final error = fault;
    if (error == null) {
      return PlaybackFaultOwner.unknown;
    }
    return classifyFaultOwner(error);
  }

  /// The exportable report: environment, stages, tickets, network summary, leading fault - all scrubbed.
  Map<String, Object?> report({Map<String, Object?> environment = const <String, Object?>{}}) {
    final error = fault;
    return <String, Object?>{
      'traceId': traceId,
      if (extensionId != null) 'extensionId': extensionId,
      if (sourceId != null) 'sourceId': sourceId,
      if (content != null)
        'content': <String, Object?>{
          'sourceId': content!.sourceId,
          'contentId': content!.contentId,
          'kind': content!.kind.name,
        },
      'stages': _marks.map((mark) => mark.toJson()).toList(growable: false),
      'tickets': _tickets.map((ticket) => ticket.toJson()).toList(growable: false),
      'network': List<String>.unmodifiable(_networkSummary),
      if (error != null)
        'fault': <String, Object?>{
          'code': error.code,
          'message': redactText(error.message),
          'category': error.category?.name,
          'retryable': error.retryable,
          'owner': classifyFault().name,
        },
      // Free-form environment (app version, platform, engine, network type) still goes through the same
      // scrub: an "environment" map is where a careless caller would otherwise drop an account id.
      'environment': environment.map((key, value) => MapEntry<String, Object?>(key, _scrub(value))),
    };
  }

  static Object? _scrub(Object? value) {
    if (value is String) {
      return redactText(value);
    }
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry<String, Object?>('$key', _scrub(item)));
    }
    if (value is List) {
      return value.map(_scrub).toList(growable: false);
    }
    return value;
  }
}

/// Maps a platform error onto the component that has to fix it.
PlaybackFaultOwner classifyFaultOwner(PlatformErrorInfo error) {
  if (error.code.startsWith('resolver.') ||
      error.code.startsWith('source.') ||
      error.code.startsWith('repository.') ||
      error.code.startsWith('provider.')) {
    return PlaybackFaultOwner.source;
  }
  if (error.code.startsWith('network.') || error.category == PlatformErrorCategory.network) {
    return PlaybackFaultOwner.network;
  }
  if (error.code.startsWith('media.') || error.category == PlatformErrorCategory.media) {
    return PlaybackFaultOwner.media;
  }
  return switch (error.category) {
    PlatformErrorCategory.permission || PlatformErrorCategory.auth => PlaybackFaultOwner.source,
    PlatformErrorCategory.timeout => PlaybackFaultOwner.network,
    _ => PlaybackFaultOwner.unknown,
  };
}

/// Scrubs credential-bearing shapes out of free text a caller wrote into a diagnostic field.
///
/// Two shapes matter in practice: a query token on a media url, and a header-looking value pasted from a
/// request. Both are reduced to a marker, keeping enough shape to debug from.
String redactText(String value) {
  // Every query parameter is dropped, not just the first: a media url routinely carries two tokens, and
  // redacting one of them leaves the same leak with a shorter tail.
  final withoutQuery = value.replaceAllMapped(RegExp(r'''[?&][^"'\s]*'''), (match) => '${match.group(0)![0]}***');
  return _sensitiveKeyPattern
      .allMatches(withoutQuery)
      .fold<String>(withoutQuery, (current, match) => current.replaceFirst(match.group(0)!, '${match.group(1)}: ***'));
}

/// ISO-8601 in UTC, which is what every persisted timestamp in this repository uses.
String _utc(DateTime value) => value.toUtc().toIso8601String();

/// Header- or credential-shaped `key: value` pairs inside free text. Dart's RegExp is ECMAScript-based, which
/// rejects an inline `(?i)`, so case-insensitivity is a constructor option.
final RegExp _sensitiveKeyPattern = RegExp(
  r'\b(' +
      [
        'authorization',
        'cookie',
        'set-cookie',
        'x-api-key',
        'x-auth-token',
        'token',
        'password',
        'secret',
      ].map(RegExp.escape).join('|') +
      // A header value runs to the end of its segment, not to the next space: `Authorization: Bearer xyz`
      // leaking "xyz" is exactly the bug a value class of [^ ] would ship.
      r')\s*[:=]\s*[^,;\r\n"]+',
  caseSensitive: false,
);
