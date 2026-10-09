// Module: lib/src/identity.dart
// Purpose: Decide whether two sources' items are the same content, and never decide more than that.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/content/content-identity.md - matching priority is an authoritative id (ISRC for music, a
// numbered id for video) then a fuzzy title + creator + collection + duration match with a configurable
// threshold; and "置信度不足时不强并:显示候选让用户确认一次,结果记忆".
//
// Placement: dependency-rules.md section 2 lists `identity` in L1 ecosystem, while content-identity.md
// section 2 says matching is "services 层能力,Provider 不感知彼此". Both readings agree on the substance -
// the provider never sees this code - so the frozen inventory decides the directory, and the rule is held
// by the fact that nothing here imports a provider.

import 'package:pure_live_platform/pure_live_platform.dart';

/// The number schemes that settle identity outright, highest trust first.
const List<String> kAuthoritativeIdKeys = <String>['isrc', 'upc', 'ean', 'bvid', 'aid', 'imdb', 'tmdb'];

/// What a candidate is known to be, in the shape identity matching needs.
final class IdentityFacts {
  const IdentityFacts({
    required this.title,
    this.creator,
    this.collection,
    this.duration,
    this.authoritative = const <String, String>{},
  });

  /// Pulls the facts a provider declared about one item.
  ///
  /// The authoritative ids come from `metadata.extra` under the keys in [kAuthoritativeIdKeys]: a provider
  /// that does not know the ISRC simply omits it, which is a different answer from a wrong one.
  factory IdentityFacts.from(ContentSummary summary) {
    final extra = summary.metadata.extra;
    final ids = <String, String>{};
    for (final key in kAuthoritativeIdKeys) {
      final value = extra[key];
      if (value is String && value.trim().isNotEmpty) {
        ids[key] = value.trim();
      }
    }
    return IdentityFacts(
      title: summary.title,
      creator: summary.metadata.language ?? summary.description,
      collection: summary.subtitle,
      duration: summary.metadata.duration,
      authoritative: ids,
    );
  }

  final String title;
  final String? creator;

  /// Album, series or any container the two items could share.
  final String? collection;
  final Duration? duration;

  /// Scheme → value, e.g. `{'isrc': 'USMT12345678'}`.
  final Map<String, String> authoritative;

  /// The authoritative identity both sides can be compared on, or null.
  ///
  /// Only a *shared* scheme counts: an ISRC and a Bilibili aid are different kinds of statement and agreeing
  /// on neither says anything.
  String? sharedIdWith(IdentityFacts other) {
    for (final scheme in kAuthoritativeIdKeys) {
      final mine = authoritative[scheme];
      final theirs = other.authoritative[scheme];
      if (mine != null && theirs != null) {
        return '$scheme:$mine';
      }
    }
    return null;
  }

  bool declaresAuthoritativeId() => authoritative.isNotEmpty;

  /// Rebuilds stored facts. The shapes are the ones [toJson] writes, so a round trip is exact for every
  /// field this type carries.
  factory IdentityFacts.fromJson(Map<String, Object?> json) => IdentityFacts(
    title: '${json['title'] ?? ''}',
    creator: json['creator'] is String ? json['creator'] as String : null,
    collection: json['collection'] is String ? json['collection'] as String : null,
    duration: json['durationMs'] is num ? Duration(milliseconds: (json['durationMs'] as num).toInt()) : null,
    authoritative: <String, String>{
      for (final entry in (json['authoritative'] as Map? ?? const <Object?, Object?>{}).entries)
        '${entry.key}': '${entry.value}',
    },
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    if (creator != null) 'creator': creator,
    if (collection != null) 'collection': collection,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (authoritative.isNotEmpty) 'authoritative': authoritative,
  };

  @override
  String toString() => 'IdentityFacts(${IdentityMatcher.normalize(title)}${creator == null ? '' : ' / $creator'})';
}

/// How the matcher weighs agreement, and where it stops claiming to know.
///
/// The defaults are policy, not fact: a caller that has watched its own catalogue can tighten or loosen them,
/// and the reason [autoMergeConfidence] is high is the rule below it, not a number anyone measured.
final class IdentityPolicy {
  const IdentityPolicy({
    this.autoMergeConfidence = 0.9,
    this.candidateConfidence = 0.55,
    this.durationTolerance = const Duration(seconds: 3),
  });

  /// At or above this, two records are the same content without asking anyone.
  final double autoMergeConfidence;

  /// At or above this, the pair is worth showing as a candidate for confirmation.
  final double candidateConfidence;

  /// How far two stated lengths may disagree and still count as the same recording.
  final Duration durationTolerance;
}

/// The matcher's conclusion. Three states, because "not enough evidence" is a real answer and merging on it
/// is the failure this layer exists to avoid.
enum IdentityDecision { same, candidate, different }

final class IdentityMatch {
  const IdentityMatch({required this.decision, required this.confidence, required this.reason});

  final IdentityDecision decision;
  final double confidence;
  final String reason;

  bool get isSame => decision == IdentityDecision.same;

  @override
  String toString() => 'IdentityMatch(${decision.name}, ${confidence.toStringAsFixed(2)}: $reason)';
}

/// Compares two records' facts. Pure and synchronous: nothing here reads a store, so the same inputs always
/// give the same answer and the policy is the only variable.
final class IdentityMatcher {
  const IdentityMatcher([this.policy = const IdentityPolicy()]);

  final IdentityPolicy policy;

  IdentityMatch compare(IdentityFacts a, IdentityFacts b) {
    final idA = a.authoritative, idB = b.authoritative;
    for (final scheme in kAuthoritativeIdKeys) {
      final mine = idA[scheme];
      final theirs = idB[scheme];
      if (mine == null || theirs == null) {
        continue;
      }
      if (mine == theirs) {
        return const IdentityMatch(decision: IdentityDecision.same, confidence: 1, reason: 'authoritative id');
      }
      // A shared scheme with different values outranks the fuzzy match: two records of the same ISRC-free
      // title are maybe the same song, but two different ISRCs are two different recordings.
      return IdentityMatch(
        decision: IdentityDecision.different,
        confidence: 0,
        reason: '$scheme differs ($mine vs $theirs)',
      );
    }

    final titleA = normalize(a.title);
    final titleB = normalize(b.title);
    if (titleA.isEmpty || titleB.isEmpty || titleA != titleB) {
      return IdentityMatch(
        decision: IdentityDecision.different,
        confidence: titleA == titleB ? 0.5 : 0,
        reason: 'titles differ',
      );
    }

    // Confidence is the share of the *comparable* evidence that agrees. A field one side does not know is
    // left out of the denominator entirely: its absence is neither agreement nor contradiction, and counting
    // a missing artist as a penalty would punish the sparsest source for being sparse.
    const weights = <String, double>{'title': 0.5, 'creator': 0.25, 'collection': 0.15, 'duration': 0.10};
    var comparable = 0.0;
    var agreed = 0.0;
    final notes = <String>[];
    var durationDisagrees = false;

    var fieldsCompared = 0;
    comparable += weights['title']!;
    agreed += weights['title']!;
    fieldsCompared++;
    notes.add('title matches');

    if (a.creator != null && b.creator != null) {
      comparable += weights['creator']!;
      fieldsCompared++;
      if (normalize(a.creator!) == normalize(b.creator!)) {
        agreed += weights['creator']!;
        notes.add('creator matches');
      } else {
        notes.add('creator differs');
      }
    }
    if (a.collection != null && b.collection != null) {
      comparable += weights['collection']!;
      fieldsCompared++;
      if (normalize(a.collection!) == normalize(b.collection!)) {
        agreed += weights['collection']!;
        notes.add('collection matches');
      } else {
        notes.add('collection differs');
      }
    }
    final durA = a.duration, durB = b.duration;
    if (durA != null && durB != null) {
      comparable += weights['duration']!;
      fieldsCompared++;
      if ((durA - durB).abs() <= policy.durationTolerance) {
        agreed += weights['duration']!;
        notes.add('duration agrees');
      } else {
        durationDisagrees = true;
        notes.add('duration disagrees by ${(durA - durB).abs().inSeconds}s');
      }
    }

    final confidence = comparable == 0 ? 0.0 : agreed / comparable;
    // Two evidence gates, applied to the decision rather than baked into the number: confidence stays "the
    // share of comparable evidence that agrees", and these say when that number may not be acted on.
    var capped = durationDisagrees;
    if (fieldsCompared < 2) {
      // A title is not an identity - that is the entire reason this layer exists.
      capped = true;
      notes.add('only one field was comparable');
    }
    if (durationDisagrees) {
      notes.add('length decides against an automatic merge');
    }
    final score = confidence.clamp(0.0, 1.0);

    final decision = capped
        ? (score >= policy.candidateConfidence ? IdentityDecision.candidate : IdentityDecision.different)
        : score >= policy.autoMergeConfidence
        ? IdentityDecision.same
        : score >= policy.candidateConfidence
        ? IdentityDecision.candidate
        : IdentityDecision.different;
    return IdentityMatch(decision: decision, confidence: score, reason: notes.join(', '));
  }

  /// Case, punctuation and repeated spaces carry no identity information across sources: one writes
  /// `歌手 - 歌名 (Live)`, another writes the same thing in lower case with the brackets missing.
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final code in raw.toLowerCase().runes) {
      final char = String.fromCharCode(code);
      if (RegExp(r'[a-z0-9\u3400-\u9fff\u3040-\u30ff\uac00-\ud7af]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
