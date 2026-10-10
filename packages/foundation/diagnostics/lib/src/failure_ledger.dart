// Module: lib/src/failure_ledger.dart
// Purpose: Collects repeated failures once each, with a count, a first and last seen, and a stack worth reading.
// Author: liuchuancong
// Created: 2026-10-11
//
// A player that retries a dead source thirty times produces thirty log lines and one bug. Deduplicating by
// fingerprint turns that into "30x in 4 minutes", which is both the truth and small enough to attach to a
// report. The fingerprint deliberately uses the *top frame plus the message with its numbers removed*: a full
// stack would split one bug into one entry per line-number change, and the message alone would merge every
// "timeout" in the app into a single useless bucket.

import 'package:pure_live_utils/pure_live_utils.dart';

/// How many distinct failures one ledger keeps.
const int kFailureLedgerLimit = 64;

/// One distinct failure and everything known about its repeats.
final class FailureEntry {
  const FailureEntry({
    required this.fingerprint,
    required this.summary,
    required this.firstSeen,
    required this.lastSeen,
    required this.count,
    this.sampleStack,
    this.sampleCause,
  });

  /// The stable key this failure is merged under.
  final String fingerprint;

  /// Message with digits masked, so a size or a status code does not split one bug into ten entries.
  final String summary;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int count;

  /// The stack from the *first* occurrence: the frame that raised is the useful one, and the latest
  /// occurrence of a retry loop is usually inside the retry helper.
  final StackTrace? sampleStack;

  /// What the first error was carrying, kept as text so a ledger survives being exported to JSON.
  final String? sampleCause;

  Duration get window => lastSeen.difference(firstSeen);

  /// Roughly how often it repeats, for "is this a storm or a one-off".
  double get perMinute {
    final minutes = window.inSeconds / 60;
    if (minutes < 0.1) {
      return count.toDouble();
    }
    return count / minutes;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fingerprint': fingerprint,
      'summary': summary,
      'count': count,
      'firstSeen': firstSeen.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
      'perMinute': perMinute.toStringAsFixed(2),
      if (sampleCause != null) 'cause': sampleCause,
      if (sampleStack != null) 'stack': _topFrames(sampleStack!, 4),
    };
  }

  @override
  String toString() => 'FailureEntry(${count}x $summary, ${perMinute.toStringAsFixed(1)}/min)';
}

/// Counts and merges failures by fingerprint.
final class FailureLedger {
  FailureLedger({Clock? clock, this.limit = kFailureLedgerLimit}) : _clock = clock ?? systemClock;

  final Clock _clock;
  final int limit;

  final Map<String, FailureEntry> _entries = <String, FailureEntry>{};
  int _merged = 0;
  int _dropped = 0;

  /// Distinct failures recorded.
  int get distinctCount => _entries.length;

  /// Total recorded, including repeats.
  int get totalCount => _entries.values.fold(0, (sum, entry) => sum + entry.count);

  /// How many new distinct failures were refused because the ledger was full.
  int get droppedCount => _dropped;

  /// How many repeats were folded into an existing entry.
  int get mergedCount => _merged;

  bool get isTruncated => _dropped > 0;

  /// Entries, most recently seen first.
  List<FailureEntry> get entries {
    final out = _entries.values.toList(growable: false);
    out.sort((left, right) => right.lastSeen.compareTo(left.lastSeen));
    return List<FailureEntry>.unmodifiable(out);
  }

  FailureEntry? operator [](String fingerprint) => _entries[fingerprint];

  /// Records [error], returning the entry it landed in, or null when the ledger was full and this is a new
  /// fingerprint. A null return is not an error: the failure was real, the ledger just has no room for it.
  FailureEntry? record(Object error, {StackTrace? stackTrace, String? context, Object? cause}) {
    final stack = stackTrace ?? (error is Error ? error.stackTrace : null);
    final fingerprint = failureFingerprint(error, stack);
    final now = _clock();
    final existing = _entries[fingerprint];
    if (existing != null) {
      _merged++;
      final merged = FailureEntry(
        fingerprint: existing.fingerprint,
        summary: existing.summary,
        firstSeen: existing.firstSeen,
        lastSeen: now,
        count: existing.count + 1,
        sampleStack: existing.sampleStack,
        sampleCause: existing.sampleCause ?? _describe(cause),
      );
      _entries[fingerprint] = merged;
      return merged;
    }
    if (_entries.length >= limit) {
      _dropped++;
      return null;
    }
    final created = FailureEntry(
      fingerprint: fingerprint,
      summary: summarise(error, context),
      firstSeen: now,
      lastSeen: now,
      count: 1,
      sampleStack: stack,
      sampleCause: _describe(cause),
    );
    _entries[fingerprint] = created;
    return created;
  }

  /// The entries the caller should show: highest repeat rate first, which puts a storm at the top.
  List<FailureEntry> worst({int max = 8}) {
    final sorted = entries.toList()..sort((left, right) => right.perMinute.compareTo(left.perMinute));
    return List<FailureEntry>.unmodifiable(sorted.take(max));
  }

  List<Map<String, Object?>> toJson() {
    return <Map<String, Object?>>[
      for (final entry in entries) entry.toJson(),
      if (isTruncated) <String, Object?>{'truncated': _dropped},
    ];
  }

  void clear() {
    _entries.clear();
    _merged = 0;
    _dropped = 0;
  }

  static String _describe(Object? cause) {
    if (cause == null) {
      return '';
    }
    return _mask(cause.toString());
  }
}

/// The stable key for one failure: the exception type, its first line with numbers masked, and the first
/// non-platform frame that raised it.
String failureFingerprint(Object error, StackTrace? stack) {
  final head = _firstLine(error.toString());
  final frame = _firstAppFrame(stack);
  return '${error.runtimeType}|${_mask(head)}|$frame';
}

/// A one-line human summary, with numbers masked and the context appended.
String summarise(Object error, String? context) {
  final base = _mask(_firstLine(error.toString()));
  if (context == null || context.trim().isEmpty) {
    return base;
  }
  return '$base [$context]';
}

String _firstLine(String text) {
  final newline = text.indexOf('\n');
  return newline < 0 ? text : text.substring(0, newline);
}

/// Digits become `#`, so "timeout after 15ms" and "timeout after 30ms" are one entry.
String _mask(String text) => text.replaceAll(RegExp(r'\d+'), '#');

/// The first frame that is not dart: or package:test, which is where the app's own code threw.
String _firstAppFrame(StackTrace? stack) {
  if (stack == null) {
    return '';
  }
  for (final line in stack.toString().split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('dart:') || trimmed.startsWith('package:test')) {
      continue;
    }
    final space = trimmed.indexOf(' ');
    return space < 0 ? trimmed : trimmed.substring(0, space);
  }
  return '';
}

String _topFrames(StackTrace stack, int count) {
  final lines = stack.toString().split('\n').where((line) => line.trim().isNotEmpty).toList(growable: false);
  return lines.take(count).join('\n');
}
