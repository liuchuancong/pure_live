// Module: lib/testing.dart
// Purpose: The capability contract assertions every source has to pass, whether it is built in, scripted or Python hosted.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/capability-contract.md section 4 requires one assertion set shared by built-in and
// scripted sources, and docs/contracts/provider-contract.md section 1 rule 5 makes passing it a delivery
// gate. These functions return a violation list instead of calling expect(), so package:test, the plugin
// validator and a device-side self-check all run the same code and report a whole list rather than the
// first throw.
//
// Reading the expiresAt rule: capability-contract.md says a resolve must return a ticket "含 expiresAt" and
// provider-contract.md says to give it truthfully. A static m3u8 genuinely has no expiry, so an absent
// expiresAt is accepted here while a present one must be consistent and in the future - a lying TTL is the
// failure the Watchdog would otherwise have to absorb.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'src/capabilities.dart';

/// One contract break found in a source implementation.
///
/// [code] is stable and machine-read: it is the key a plugin report groups by, so changing one is a breaking
/// change to this entrypoint even though the message text is free to move.
final class ContractViolation {
  const ContractViolation({
    required this.code,
    required this.capability,
    required this.message,
  });

  final String code;

  /// Which suite reported it, so a failure points at the capability that needs fixing.
  final String capability;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'capability': capability,
    'message': message,
  };

  @override
  String toString() => '[$code] $capability: $message';
}

/// The fixed points a contract run needs from one source.
///
/// A real source supplies these from its fixtures, so the run is deterministic offline; the probe is part
/// of the source package, not of this suite, which is why a keyword that hits nothing is reported as a
/// violation instead of being silently skipped.
abstract interface class ContractProbe {
  /// The id this source uses in every reference it hands out.
  SourceId get sourceId;

  /// A reference this source guarantees it can describe and resolve.
  ContentRef get playableRef;

  /// A browse query this source answers with at least one item.
  ContentQuery get browseQuery;

  /// A search query this source answers with at least one item.
  SearchQuery get searchQuery;
}

/// A source under test: what it claims, what it implements, and the probe to exercise it with.
abstract interface class ContractSubject {
  ContractProbe get probe;

  /// The kinds the source reports at registration.
  CapabilitySet get declaredCapabilities;

  /// The implementation object; the suites run for whichever interfaces it actually implements.
  Object get source;
}

/// Runs every applicable suite over [subject]: declarations first, then each implemented capability.
Future<List<ContractViolation>> checkCapabilityContract(
  ContractSubject subject,
) async {
  final violations = <ContractViolation>[
    ...checkCapabilityDeclarations(
      subject.declaredCapabilities,
      subject.source,
    ),
  ];
  final source = subject.source;
  if (source is ResolveCapability) {
    violations.addAll(await checkResolveContract(source, subject.probe));
  }
  if (source is BrowseCapability) {
    violations.addAll(await checkBrowseContract(source, subject.probe));
  }
  if (source is SearchCapability) {
    violations.addAll(await checkSearchContract(source, subject.probe));
  }
  if (source is FeedCapability) {
    violations.addAll(await checkFeedContract(source, subject.probe));
  }
  return violations;
}

/// Checks that a source implements the interfaces its declared capability kinds name.
///
/// Only the kinds with a method set in this package are checkable; the rest report nothing here and land
/// with the wave that defines their calls, rather than being declared satisfied by an empty check.
List<ContractViolation> checkCapabilityDeclarations(
  CapabilitySet declared,
  Object source,
) {
  final violations = <ContractViolation>[];
  for (final kind in declared.kinds) {
    final missing = _missingInterfaces(kind, source);
    if (missing.isNotEmpty) {
      violations.add(
        ContractViolation(
          code: 'contract.declaration.missing_interface',
          capability: 'declaration',
          message:
              'declares ${kind.name} but the source is not ${missing.join(', ')}',
        ),
      );
    }
  }
  return violations;
}

/// Resolves the probe reference and re-resolves it for each refresh reason the host can raise.
Future<List<ContractViolation>> checkResolveContract(
  ResolveCapability capability,
  ContractProbe probe,
) async {
  final at = DateTime.now().toUtc();
  final violations = <ContractViolation>[];

  final MediaTicket ticket;
  try {
    ticket = await capability.resolve(probe.playableRef);
  } catch (error) {
    return [
      ContractViolation(
        code: 'contract.resolve.threw',
        capability: 'resolve',
        message: 'resolve(${probe.playableRef.contentId}) failed: $error',
      ),
    ];
  }
  violations.addAll(
    _ticketViolations(ticket, probe.playableRef, at, 'resolve'),
  );

  for (final reason in const <RefreshReason>[
    RefreshReason.expiring,
    RefreshReason.expired,
    RefreshReason.manual,
  ]) {
    final MediaTicket refreshed;
    try {
      refreshed = await capability.refresh(ticket, reason);
    } catch (error) {
      violations.add(
        ContractViolation(
          code: 'contract.refresh.threw',
          capability: 'resolve',
          message: 'refresh($reason) failed: $error',
        ),
      );
      continue;
    }
    violations.addAll(
      _ticketViolations(refreshed, probe.playableRef, at, 'refresh'),
    );
    if (refreshed.id == ticket.id && refreshed.uri == ticket.uri) {
      violations.add(
        ContractViolation(
          code: 'contract.refresh.not_fresh',
          capability: 'resolve',
          message:
              'refresh($reason) returned the same ticket it was given, so the link never changed',
        ),
      );
    }
  }
  return violations;
}

/// Browses one page and opens the detail of the first item it returned.
Future<List<ContractViolation>> checkBrowseContract(
  BrowseCapability capability,
  ContractProbe probe,
) async {
  final violations = <ContractViolation>[];

  final PageResult<ContentSummary> page;
  try {
    page = await capability.browse(probe.browseQuery);
  } catch (error) {
    return [
      ContractViolation(
        code: 'contract.browse.threw',
        capability: 'browse',
        message: 'browse failed: $error',
      ),
    ];
  }

  violations.addAll([
    ..._pageViolations(page, probe.browseQuery.page, 'browse'),
    ..._summaryViolations(page.items, probe, 'browse'),
  ]);
  if (page.items.isEmpty) {
    violations.add(
      ContractViolation(
        code: 'contract.browse.empty',
        capability: 'browse',
        message:
            'the probe query ${probe.browseQuery.category ?? probe.browseQuery.keyword} returned nothing, '
            'so this run cannot prove the listing',
      ),
    );
  }
  if (page.hasMore && page.items.isEmpty) {
    violations.add(
      ContractViolation(
        code: 'contract.browse.hasMore_without_items',
        capability: 'browse',
        message: 'hasMore is true on an empty page; a list driven by this keeps requesting pages forever',
      ),
    );
  }

  if (page.items.isNotEmpty) {
    final ref = page.items.first.ref;
    final ContentDetail detail;
    try {
      detail = await capability.detail(ref);
    } catch (error) {
      violations.add(
        ContractViolation(
          code: 'contract.browse.detail_threw',
          capability: 'browse',
          message: 'detail(${ref.contentId}) failed: $error',
        ),
      );
      return violations;
    }
    if (detail.ref != ref) {
      violations.add(
        ContractViolation(
          code: 'contract.browse.detail_ref_mismatch',
          capability: 'browse',
          message:
              'detail asked for ${ref.contentId} and answered ${detail.ref.contentId}',
        ),
      );
    }
    violations.addAll(_summaryViolations([detail.summary], probe, 'browse'));
  }
  return violations;
}

/// Searches the probe keyword.
Future<List<ContractViolation>> checkSearchContract(
  SearchCapability capability,
  ContractProbe probe,
) async {
  final PageResult<ContentSummary> page;
  try {
    page = await capability.search(probe.searchQuery);
  } catch (error) {
    return [
      ContractViolation(
        code: 'contract.search.threw',
        capability: 'search',
        message: 'search(${probe.searchQuery.keyword}) failed: $error',
      ),
    ];
  }

  final violations = <ContractViolation>[
    ..._pageViolations(page, probe.searchQuery.page, 'search'),
    ..._summaryViolations(page.items, probe, 'search'),
  ];
  if (page.items.isEmpty) {
    violations.add(
      ContractViolation(
        code: 'contract.search.empty',
        capability: 'search',
        message:
            'the probe keyword ${probe.searchQuery.keyword} matched nothing, so this run cannot prove search',
      ),
    );
  }
  return violations;
}

/// Reads the front page.
Future<List<ContractViolation>> checkFeedContract(
  FeedCapability capability,
  ContractProbe probe,
) async {
  final PageResult<ContentSummary> page;
  try {
    page = await capability.feed(PageRequest.first);
  } catch (error) {
    return [
      ContractViolation(
        code: 'contract.feed.threw',
        capability: 'feed',
        message: 'feed failed: $error',
      ),
    ];
  }

  final seen = <ContentRef>{};
  final violations = <ContractViolation>[
    ..._pageViolations(page, PageRequest.first, 'feed'),
    ..._summaryViolations(page.items, probe, 'feed'),
  ];
  for (final item in page.items) {
    if (!seen.add(item.ref)) {
      violations.add(
        ContractViolation(
          code: 'contract.feed.duplicate_ref',
          capability: 'feed',
          message: '${item.ref.contentId} appears twice on one page',
        ),
      );
    }
  }
  if (page.items.isEmpty) {
    violations.add(
      ContractViolation(
        code: 'contract.feed.empty',
        capability: 'feed',
        message:
            'the front page returned nothing while declaring FeedCapability',
      ),
    );
  }
  return violations;
}

List<String> _missingInterfaces(CapabilityKind kind, Object source) =>
    switch (kind) {
      CapabilityKind.live ||
      CapabilityKind.vod ||
      CapabilityKind.music ||
      CapabilityKind.iptv => <String>[
        if (source is! BrowseCapability) 'BrowseCapability',
        if (source is! ResolveCapability) 'ResolveCapability',
      ],
      CapabilityKind.search =>
        source is! SearchCapability
            ? const <String>['SearchCapability']
            : const <String>[],
      CapabilityKind.feed =>
        source is! FeedCapability
            ? const <String>['FeedCapability']
            : const <String>[],
      _ => const <String>[],
    };

List<ContractViolation> _pageViolations<T>(
  PageResult<T> page,
  PageRequest requested,
  String capability,
) {
  return <ContractViolation>[
    if (page.page != requested.page)
      ContractViolation(
        code: 'contract.$capability.page_mismatch',
        capability: capability,
        message:
            'asked for page ${requested.page} and answered page ${page.page}; '
            'a list cannot tell where it is if the answer does not say',
      ),
    if (page.items.length > requested.pageSize)
      ContractViolation(
        code: 'contract.$capability.page_overflow',
        capability: capability,
        message:
            'asked for ${requested.pageSize} items and got ${page.items.length}; '
            'paging maths breaks once a page can be longer than requested',
      ),
  ];
}

List<ContractViolation> _summaryViolations(
  List<ContentSummary> items,
  ContractProbe probe,
  String capability,
) {
  final violations = <ContractViolation>[];
  for (final item in items) {
    if (item.ref.sourceId != probe.sourceId) {
      violations.add(
        ContractViolation(
          code: 'contract.$capability.foreign_source',
          capability: capability,
          message:
              'handed out a ref for source ${item.ref.sourceId}; a source may only name its own content',
        ),
      );
    }
    if (item.title.trim().isEmpty) {
      violations.add(
        ContractViolation(
          code: 'contract.$capability.blank_title',
          capability: capability,
          message: 'item ${item.ref.contentId} has no title to show',
        ),
      );
    }
  }
  return violations;
}

List<ContractViolation> _ticketViolations(
  MediaTicket ticket,
  ContentRef requested,
  DateTime now,
  String capability,
) {
  final violations = <ContractViolation>[];
  if (ticket.uri.scheme.isEmpty) {
    violations.add(
      ContractViolation(
        code: 'contract.$capability.uri_scheme',
        capability: capability,
        message:
            'ticket ${ticket.id} has a uri with no scheme, so nothing can fetch it',
      ),
    );
  }
  if (ticket.protocol == MediaProtocol.unknown) {
    violations.add(
      ContractViolation(
        code: 'contract.$capability.protocol_unknown',
        capability: capability,
        message:
            'ticket ${ticket.id} does not say how it is transported, so no plan can be built for it',
      ),
    );
  }
  if (ticket.source != null && ticket.source != requested) {
    violations.add(
      ContractViolation(
        code: 'contract.$capability.wrong_source_content',
        capability: capability,
        message:
            'asked for ${requested.contentId} and got a ticket attributed to ${ticket.source!.contentId}',
      ),
    );
  }
  final expiry = ticket.expiresAt;
  if (expiry != null) {
    if (expiry.isBefore(ticket.createdAt)) {
      violations.add(
        ContractViolation(
          code: 'contract.$capability.expiry_before_created',
          capability: capability,
          message: 'ticket ${ticket.id} expires before it was created',
        ),
      );
    } else if (ticket.isExpiredAt(now)) {
      violations.add(
        ContractViolation(
          code: 'contract.$capability.expiry_in_past',
          capability: capability,
          message:
              'ticket ${ticket.id} was already expired when it was handed over',
        ),
      );
    }
  }
  for (final track in ticket.tracks) {
    if (track.uri.scheme.isEmpty) {
      violations.add(
        ContractViolation(
          code: 'contract.$capability.track_uri_scheme',
          capability: capability,
          message:
              'ticket ${ticket.id} carries a ${track.kind.name} track with a schemeless uri',
        ),
      );
    }
  }
  return violations;
}
