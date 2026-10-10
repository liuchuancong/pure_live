// Module: lib/src/domain/live_recovery.dart
// Purpose: What to try after a line fails, and what to reopen when the app comes back.
// Author: liuchuancong
// Created: 2026-10-11
//
// docs/sources/live/source-contract.md gives the rule "degrade across lines on failure" and leaves the policy
// here: which line next, how many times, and what counts as exhausted. Two decisions are worth stating
// because the tempting implementation gets both wrong. The ladder never crosses to another *source* - that
// would move the user's channel to a different site's vocabulary of qualities and subtitles mid-stream, and
// it is the ResolverChain's job, not this layer's. And quality is not silently degraded by a line failure:
// a dead line says nothing about the bitrate the user chose.
//
// The resume record is versioned and tolerant for the same reason the preference rows are: the app may read a
// file an older build wrote, and a line id that no longer exists is a normal Tuesday, not a crash.

import 'dart:convert';

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

import 'live_session.dart';

/// The next thing to do, or why the ladder stopped.
enum LineDegradeOutcome { nextLine, exhausted }

/// One step of the ladder.
final class LineDegradeStep {
  const LineDegradeStep({required this.outcome, required this.candidate, required this.tried, this.reason});

  final LineDegradeOutcome outcome;

  /// The line to try now, or null when there is none.
  final StreamVariant? candidate;

  /// How many lines have already been given up on, this one included when it is a `nextLine`.
  final int tried;

  final String? reason;

  bool get shouldTry => candidate != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'outcome': outcome.name,
    if (candidate != null) 'line': candidate!.id,
    'tried': tried,
    if (reason != null) 'reason': reason,
  };

  @override
  String toString() => 'LineDegradeStep(${outcome.name}${candidate == null ? '' : ' ${candidate!.id}'} tried=$tried)';
}

/// The line ladder for one room, over the lines the source actually offered.
final class LineDegrader {
  LineDegrader({required List<StreamVariant> lines, required String initialLineId, this.maxSwitches = 4})
    : _lines = _ordered(lines),
      _tried = <String>{initialLineId} {
    if (maxSwitches < 1) {
      throw ArgumentError.value(maxSwitches, 'maxSwitches', 'must allow at least one attempt');
    }
    if (_lines.isNotEmpty && !_lines.any((line) => line.id == initialLineId)) {
      throw ArgumentError.value(initialLineId, 'initialLineId', 'is not among the offered lines');
    }
  }

  final List<StreamVariant> _lines;
  final Set<String> _tried;
  final int maxSwitches;

  /// The lines in the order the ladder walks them: the default first, then the source's own order.
  static List<StreamVariant> _ordered(List<StreamVariant> lines) {
    final onlyLines = lines.where((variant) => variant.isLine).toList(growable: false);
    final defaults = onlyLines.where((variant) => variant.isDefault).toList(growable: false);
    final rest = onlyLines.where((variant) => !variant.isDefault).toList(growable: false);
    return <StreamVariant>[...defaults, ...rest];
  }

  List<StreamVariant> get offered => List<StreamVariant>.unmodifiable(_lines);

  /// The lines given up on, in the order they failed.
  List<String> get triedLines => List<String>.unmodifiable(_tried);

  int get attemptedCount => _tried.length;

  bool get isExhausted => _nextCandidate() == null;

  /// Records that [lineId] failed, and returns the step to take now.
  LineDegradeStep fail(String lineId) {
    _tried.add(lineId);
    return _step();
  }

  /// The step without recording anything, for a UI that asks "is there another line" before it retries.
  LineDegradeStep peek() => _step(alreadyTried: true);

  LineDegradeStep _step({bool alreadyTried = false}) {
    if (_lines.length <= 1) {
      return LineDegradeStep(
        outcome: LineDegradeOutcome.exhausted,
        candidate: null,
        tried: attemptedCount,
        reason: 'this room offers ${_lines.length} line(s)',
      );
    }
    if (attemptedCount >= maxSwitches) {
      return LineDegradeStep(
        outcome: LineDegradeOutcome.exhausted,
        candidate: null,
        tried: attemptedCount,
        reason: 'the ladder allows $maxSwitches attempt(s) per room',
      );
    }
    final candidate = _nextCandidate();
    if (candidate == null) {
      return LineDegradeStep(
        outcome: LineDegradeOutcome.exhausted,
        candidate: null,
        tried: attemptedCount,
        reason: 'every offered line has been tried',
      );
    }
    return LineDegradeStep(
      outcome: LineDegradeOutcome.nextLine,
      candidate: candidate,
      tried: attemptedCount + (alreadyTried ? 0 : 1),
    );
  }

  StreamVariant? _nextCandidate() {
    for (final line in _lines) {
      if (!_tried.contains(line.id)) {
        return line;
      }
    }
    return null;
  }

  @override
  String toString() => 'LineDegrader(${_lines.length} lines, tried=${_tried.length})';
}

/// The room and selection to reopen on the next launch.
final class LastWatched with ValueEquality {
  const LastWatched({required this.ref, required this.at, this.line, this.quality, this.title = ''});

  final ContentRef ref;
  final DateTime at;

  /// Variant ids as the source named them. Null means "the source's own default", not "line 1".
  final String? line;
  final String? quality;

  /// The room title, for the "continue watching" row; it is a copy, so it renders without a network.
  final String title;

  /// Older than [cutoff] means the source has likely moved on: reopen it as a fresh entry rather than
  /// promising a line id from last week.
  bool isStale(DateTime cutoff) => !at.isAfter(cutoff);

  Duration ageAt(DateTime now) => now.difference(at);

  Map<String, Object?> toJson() => <String, Object?>{
    'v': kLastWatchedVersion,
    'ref': ref.toJson(),
    'at': at.toUtc().toIso8601String(),
    if (line != null) 'line': line,
    if (quality != null) 'quality': quality,
    if (title.isNotEmpty) 'title': title,
  };

  static Map<String, Object?>? parse(Object? raw) {
    final Object? decoded;
    if (raw is String) {
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        return null;
      }
    } else if (raw is Map) {
      decoded = raw;
    } else {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    final version = decoded['v'];
    // A newer envelope is not a shape we should guess at: the fields may mean something else.
    if (version is! int || version > kLastWatchedVersion) {
      return null;
    }
    return Map<String, Object?>.from(decoded);
  }

  factory LastWatched.fromJson(Map<String, Object?> json) {
    final raw = json['ref'];
    if (raw is! Map) {
      throw const FormatException('the resume record has no content reference');
    }
    return LastWatched(
      ref: ContentRef.fromJson(Map<String, Object?>.from(raw)),
      at: (DateTime.tryParse('${json['at']}') ?? DateTime.utc(1970)).toUtc(),
      line: json['line'] is String ? json['line'] as String : null,
      quality: json['quality'] is String ? json['quality'] as String : null,
      title: json['title'] is String ? json['title'] as String : '',
    );
  }

  @override
  List<Object?> get equalityFields => <Object?>[ref, at, line, quality, title];
}

/// The envelope version of the resume record.
const int kLastWatchedVersion = 1;

/// Where the resume record lives.
final class LastWatchedStore {
  LastWatchedStore({required KeyValueStore store, this.namespace = 'live', Clock? clock})
    : _store = store,
      _clock = clock ?? systemClock;

  /// Every key this store touches is prefixed with it, so two hosts sharing a store do not read each other's
  /// resume record.
  final String namespace;

  final KeyValueStore _store;
  final Clock _clock;

  String get _key => '$namespace.lastWatched';

  /// The stored record, or null when there is none, it is unreadable, or a newer build wrote a shape this one
  /// cannot interpret. All three are "open nothing", never "open a guess".
  Future<LastWatched?> load() async {
    final json = LastWatched.parse(await _store.read(_key));
    if (json == null) {
      return null;
    }
    try {
      return LastWatched.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<LastWatched> save(ContentRef ref, {String? line, String? quality, String title = ''}) async {
    final record = LastWatched(ref: ref, at: _clock().toUtc(), line: line, quality: quality, title: title);
    await _store.write(_key, jsonEncode(record.toJson()));
    return record;
  }

  Future<void> clear() => _store.remove(_key);

  /// The selection to reopen with, filtered to what the source offers *now*.
  ///
  /// A line id that no longer exists must not resurrect a stale variant: the session starts on the source's
  /// default and the caller says so, rather than failing to resolve.
  LiveSelection selectionFor(LastWatched record, LiveSession session) {
    final lines = session.offered(StreamVariantKind.line);
    final qualities = session.offered(StreamVariantKind.quality);
    final wantedLine = record.line;
    final wantedQuality = record.quality;
    return LiveSelection(
      line: wantedLine == null || !lines.any((line) => line.id == wantedLine)
          ? session.selection.line
          : lines.firstWhere((line) => line.id == wantedLine),
      quality: wantedQuality == null || !qualities.any((quality) => quality.id == wantedQuality)
          ? session.selection.quality
          : qualities.firstWhere((quality) => quality.id == wantedQuality),
    );
  }
}
