// Module: lib/src/capabilities.dart
// Purpose: The capability interfaces a source implements, and the vocabulary naming them.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/capability-contract.md. A capability describes what a source can do; a source
// implements the subset it genuinely serves, and the platform discovers the rest. Behaviour rules that the
// contract test enforces live in package:pure_live_capability/testing.dart, not in doc comments here.

import 'package:pure_live_platform/pure_live_platform.dart';

/// Every capability name the platform recognises.
///
/// Which kinds have a method set, and which deliberately do not:
/// - `live`/`vod`/`music`/`iptv` route to [BrowseCapability] + [ResolveCapability]; the domain itself is a
///   [ContentKind], not an interface, so a "LiveCapability" would be a second name for the same two methods.
/// - `search` and `feed` are [SearchCapability] and [FeedCapability].
/// - `quality`, `line`, `danmaku`, `subtitle`, `lyric`, `comment`, `chapter`, `recommendation` and `account` are
///   the interfaces in `media_capabilities.dart`, added because a provider could not otherwise be a complete
///   package: the ceiling of four method sets is why every source so far stopped at listing and resolving.
/// - `auth` has no interface yet - a login flow needs the consent surface that owns it, not a signature guessed
///   here. `history`, `favorite` and `playlist` are L2 services, and `epg`/`repository` are package-level
///   features (`providers/iptv`, `ecosystem/extension`), so they are not source capabilities to declare.
///
/// `testing.dart`'s declaration check compares each kind that has an interface and reports nothing for the rest,
/// so declaring an unimplemented kind is caught where it is checkable, and never passes a check that does not exist.
enum CapabilityKind {
  // content capabilities
  live,
  vod,
  music,
  iptv,
  search,
  feed,
  // media extras
  danmaku,
  subtitle,
  lyric,
  comment,
  chapter,
  quality,
  line,
  // data capabilities
  history,
  favorite,
  playlist,
  metadata,
  recommendation,
  // platform capabilities
  auth,
  account,
  epg,
  repository,
}

/// A source that can list and describe content.
abstract interface class BrowseCapability {
  /// The source's own category table, in the order the source exposes it.
  /// Empty means the source has no categories: the consumer then shows only
  /// the home listing and must not invent a category UI.
  Future<List<ContentCategory>> categories();

  /// One page of a category listing. Pass an empty [ContentQuery] for the home listing.
  Future<PageResult<ContentSummary>> browse(ContentQuery query);

  /// Full detail for one item, including its children (episodes, tracks).
  Future<ContentDetail> detail(ContentRef ref);
}

/// A source that can search its own catalogue.
abstract interface class SearchCapability {
  Future<PageResult<ContentSummary>> search(SearchQuery query);
}

/// A source that can turn content into something playable.
abstract interface class ResolveCapability {
  /// Produces a ticket for [ref].
  ///
  /// The rule the contract test enforces: a ticket that will stop working must carry `expiresAt`, because
  /// that is the only signal the host has to prefetch a replacement before playback dies.
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line});

  /// Replaces [expired] with a fresh ticket for the same content.
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason);
}

/// A source that offers a personalised or default front page.
abstract interface class FeedCapability {
  Future<PageResult<ContentSummary>> feed(PageRequest page);
}

/// Which capabilities a source actually serves, as reported at registration.
final class CapabilitySet {
  const CapabilitySet(this.kinds);

  const CapabilitySet.empty() : kinds = const <CapabilityKind>{};

  final Set<CapabilityKind> kinds;

  bool supports(CapabilityKind kind) => kinds.contains(kind);

  CapabilitySet withKind(CapabilityKind kind) => CapabilitySet({...kinds, kind});

  Map<String, Object?> toJson() => <String, Object?>{'kinds': kinds.map((kind) => kind.name).toList(growable: false)};

  factory CapabilitySet.fromJson(Map<String, Object?> json) =>
      CapabilitySet((json['kinds'] as List? ?? const <Object?>[]).map(_byName).whereType<CapabilityKind>().toSet());

  static CapabilityKind? _byName(Object? item) {
    for (final kind in CapabilityKind.values) {
      if (kind.name == '$item') {
        return kind;
      }
    }
    return null;
  }

  @override
  String toString() => 'CapabilitySet(${kinds.map((kind) => kind.name).join(',')})';
}
