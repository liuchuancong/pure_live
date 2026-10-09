// Module: lib/src/identity_index.dart
// Purpose: Remember which content is the same thing, so another source can be asked for it.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/content/content-identity.md - "匹配结果缓存(identity → sourceId 映射),换源播放 = 用同一
// identity 向另一 Provider resolve 新 MediaTicket", and "历史/收藏以用户首次使用的 ContentRef 为主键,
// identity 作为换源索引". So the identity of something with no authoritative number *is* the first reference
// the user used; nothing here ever rewrites a ContentRef.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';

import 'identity.dart';

/// One possible identity for a record that was not certain enough to merge.
final class IdentityCandidate {
  const IdentityCandidate({
    required this.identityId,
    required this.representative,
    required this.confidence,
    required this.reason,
  });

  final String identityId;

  /// The ref that stands for that identity - what a confirmation gets applied to.
  final ContentRef representative;
  final double confidence;
  final String reason;

  @override
  String toString() => 'IdentityCandidate($identityId ${confidence.toStringAsFixed(2)}: $reason)';
}

/// What registering one record produced.
final class IdentityRegistration {
  const IdentityRegistration({
    required this.identityId,
    required this.merged,
    this.candidates = const <IdentityCandidate>[],
  });

  final String identityId;

  /// False whenever the record started a new identity: the caller may not treat [identityId] as proof that
  /// this is that other thing unless it is true.
  final bool merged;

  /// Identities that look like this record, best first. Empty when the matcher was certain either way.
  final List<IdentityCandidate> candidates;

  bool get needsConfirmation => !merged && candidates.isNotEmpty;

  @override
  String toString() => 'IdentityRegistration($identityId merged:$merged candidates:${candidates.length})';
}

/// The stored shape: which identity each reference belongs to, what each identity holds, and the facts each
/// member was registered with.
abstract interface class IdentityStore {
  /// The opaque key one reference is filed under. Never parsed back into a ref - the ref itself is stored.
  Future<String?> identityOf(String refKey);

  Future<void> assign(String refKey, String identityId, ContentRef ref, IdentityFacts facts);

  Future<List<String>> members(String identityId);

  Future<void> replaceMembers(String identityId, List<String> refKeys);

  Future<ContentRef?> ref(String refKey);

  Future<IdentityFacts?> facts(String refKey);

  /// Every identity that currently has at least one member.
  Future<Set<String>> identities();

  /// Moves every member of [from] into [into] and drops [from].
  Future<void> mergeIdentities(String from, String into);
}

/// Identity assignment and the cross-source index.
final class IdentityIndex {
  IdentityIndex({required IdentityStore store, IdentityMatcher matcher = const IdentityMatcher()})
    : _store = store,
      _matcher = matcher;

  final IdentityStore _store;
  final IdentityMatcher _matcher;

  /// A reference's key. It is opaque by design: source ids and content ids are free-form, so splitting this
  /// string to recover a ref would be a bug waiting for the first content id with a slash in it.
  static String refKey(ContentRef ref) => '${ref.sourceId}/${ref.contentId}/${ref.kind.name}';

  /// Files one record under an identity: its own authoritative number, the best identity already known if the
  /// matcher is certain, otherwise a new identity named after this very reference.
  Future<IdentityRegistration> register(ContentRef ref, IdentityFacts facts) async {
    final key = refKey(ref);
    final authoritative = _authoritativeIdentity(facts);
    if (authoritative != null) {
      await _store.assign(key, authoritative, ref, facts);
      await _join(authoritative, key);
      return IdentityRegistration(identityId: authoritative, merged: true);
    }

    final known = await _store.identityOf(key);
    if (known != null) {
      await _join(known, key);
      return IdentityRegistration(identityId: known, merged: true);
    }

    final candidates = <IdentityCandidate>[];
    for (final identity in await _store.identities()) {
      final lead = await _representative(identity);
      if (lead == null) {
        continue;
      }
      final match = _matcher.compare(facts, lead.facts);
      if (match.isSame) {
        await _store.assign(key, identity, ref, facts);
        await _join(identity, key);
        return IdentityRegistration(identityId: identity, merged: true);
      }
      if (match.decision == IdentityDecision.candidate) {
        candidates.add(
          IdentityCandidate(
            identityId: identity,
            representative: lead.ref,
            confidence: match.confidence,
            reason: match.reason,
          ),
        );
      }
    }

    // Rule 2: not enough confidence means no merge. The record gets its own identity and the possible
    // matches go back to the caller for a one-time confirmation.
    await _store.assign(key, key, ref, facts);
    await _join(key, key);
    candidates.sort((a, b) => -a.confidence.compareTo(b.confidence));
    return IdentityRegistration(identityId: key, merged: false, candidates: candidates);
  }

  /// The user's answer to a candidate list: these two contents are one thing. Remembered, so it is asked once.
  ///
  /// The first record's identity wins, which is content-identity.md rule 3 restated: history and favourites
  /// are keyed by the reference the user used first, and an identity is only the index between them.
  Future<void> confirm(ContentRef a, ContentRef b) async {
    final identityA = await _store.identityOf(refKey(a));
    final identityB = await _store.identityOf(refKey(b));
    if (identityA == null || identityB == null || identityA == identityB) {
      return;
    }
    await _store.mergeIdentities(identityB, identityA);
  }

  /// The same content as [ref], from other registrations, oldest first.
  Future<List<ContentRef>> alternatives(ContentRef ref) async {
    final identity = await _store.identityOf(refKey(ref));
    if (identity == null) {
      return const <ContentRef>[];
    }
    final key = refKey(ref);
    return _refsOf((await _store.members(identity)).where((member) => member != key));
  }

  /// Everything filed under one identity.
  Future<List<ContentRef>> membersOf(String identityId) async => _refsOf(await _store.members(identityId));

  Future<List<ContentRef>> _refsOf(Iterable<String> keys) async {
    final refs = <ContentRef>[];
    for (final key in keys) {
      final ref = await _store.ref(key);
      if (ref != null) {
        refs.add(ref);
      }
    }
    return refs;
  }

  Future<({ContentRef ref, IdentityFacts facts})?> _representative(String identityId) async {
    for (final member in await _store.members(identityId)) {
      final ref = await _store.ref(member);
      final facts = await _store.facts(member);
      if (ref != null && facts != null) {
        return (ref: ref, facts: facts);
      }
    }
    return null;
  }

  Future<void> _join(String identityId, String key) async {
    final members = await _store.members(identityId);
    if (!members.contains(key)) {
      await _store.replaceMembers(identityId, <String>[...members, key]);
    }
  }

  String? _authoritativeIdentity(IdentityFacts facts) {
    for (final scheme in kAuthoritativeIdKeys) {
      final value = facts.authoritative[scheme];
      if (value != null) {
        return '$scheme:$value';
      }
    }
    return null;
  }
}

/// An [IdentityStore] over one [KeyValueStore].
final class KeyValueIdentityStore implements IdentityStore {
  KeyValueIdentityStore(this.store, {this.namespace = 'identity'});

  final KeyValueStore store;
  final String namespace;

  String get _assignmentsKey => '$namespace.assignments';

  String get _membersKey => '$namespace.members';

  String get _refsKey => '$namespace.refs';

  String get _factsKey => '$namespace.facts';

  @override
  Future<String?> identityOf(String refKey) async {
    final value = (await _map(_assignmentsKey))[refKey];
    return value is String ? value : null;
  }

  @override
  Future<void> assign(String refKey, String identityId, ContentRef ref, IdentityFacts facts) async {
    final assignments = await _map(_assignmentsKey);
    assignments[refKey] = identityId;
    await store.write(_assignmentsKey, assignments);
    await _remember(_refsKey, refKey, ref.toJson());
    await _remember(_factsKey, refKey, facts.toJson());
  }

  @override
  Future<List<String>> members(String identityId) async {
    final value = (await _map(_membersKey))[identityId];
    if (value is! List) {
      return const <String>[];
    }
    return value.map((item) => '$item').toList();
  }

  @override
  Future<void> replaceMembers(String identityId, List<String> refKeys) async {
    final members = await _map(_membersKey);
    members[identityId] = refKeys;
    await store.write(_membersKey, members);
  }

  @override
  Future<ContentRef?> ref(String refKey) async {
    final value = (await _map(_refsKey))[refKey];
    return value is Map ? ContentRef.fromJson(Map<String, Object?>.from(value)) : null;
  }

  @override
  Future<IdentityFacts?> facts(String refKey) async {
    final value = (await _map(_factsKey))[refKey];
    return value is Map ? IdentityFacts.fromJson(Map<String, Object?>.from(value)) : null;
  }

  @override
  Future<Set<String>> identities() async => (await _map(_assignmentsKey)).values.whereType<String>().toSet();

  @override
  Future<void> mergeIdentities(String from, String into) async {
    final moved = await members(from);
    final target = await members(into);
    await replaceMembers(into, <String>{...target, ...moved}.toList());

    final document = await _map(_membersKey);
    document.remove(from);
    await store.write(_membersKey, document);

    final assignments = await _map(_assignmentsKey);
    for (final key in moved) {
      assignments[key] = into;
    }
    await store.write(_assignmentsKey, assignments);
  }

  Future<Map<String, Object?>> _map(String key) async {
    final raw = await store.read(key);
    return raw is Map ? Map<String, Object?>.from(raw) : <String, Object?>{};
  }

  Future<void> _remember(String document, String key, Object? value) async {
    final map = await _map(document);
    map[key] = value;
    await store.write(document, map);
  }
}
