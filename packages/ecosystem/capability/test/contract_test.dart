// Module: test/contract_test.dart
// Purpose: Prove the capability contract assertions pass a conforming source and catch every documented break.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_capability/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

const String _sourceId = 'fake-source';

ContentRef _ref(String contentId, {String sourceId = _sourceId}) =>
    ContentRef(sourceId: sourceId, contentId: contentId, kind: ContentKind.liveRoom);

ContentSummary _summary(String contentId, {String sourceId = _sourceId, String title = 'Title'}) => ContentSummary(
  ref: _ref(contentId, sourceId: sourceId),
  title: title,
);

List<ContentSummary> _items(int count) =>
    List<ContentSummary>.generate(count, (index) => _summary('item-$index'), growable: false);

PageResult<ContentSummary> _page(List<ContentSummary> items, PageRequest request, {int? page, bool hasMore = false}) {
  return PageResult<ContentSummary>(
    items: items,
    page: page ?? request.page,
    pageSize: request.pageSize,
    hasMore: hasMore,
  );
}

MediaTicket _ticket(
  ContentRef ref, {
  String id = 't-1',
  String uri = 'https://example.com/a.m3u8',
  MediaProtocol protocol = MediaProtocol.hls,
  DateTime? createdAt,
  DateTime? expiresAt,
  ContentRef? attributedTo,
}) {
  final born = createdAt ?? DateTime.now().toUtc();
  return MediaTicket(
    id: id,
    uri: Uri.parse(uri),
    kind: MediaKind.live,
    protocol: protocol,
    createdAt: born,
    expiresAt: expiresAt ?? born.add(const Duration(minutes: 30)),
    source: attributedTo ?? ref,
  );
}

/// A source that satisfies every assertion. Each fake below overrides one hook, so a failure names one rule.
class _ConformingSource implements BrowseCapability, SearchCapability, ResolveCapability, FeedCapability {
  const _ConformingSource();

  /// The ticket the source hands out.
  MediaTicket ticket(ContentRef ref, {bool refreshed = false}) => _ticket(ref, id: refreshed ? 't-2' : 't-1');

  /// One listing page, shared by browse, search and feed.
  PageResult<ContentSummary> page(PageRequest request, {bool hasMore = false}) =>
      _page(_items(3), request, hasMore: hasMore);

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async => page(query.page);

  @override
  Future<ContentDetail> detail(ContentRef ref) async => ContentDetail(summary: _summary(ref.contentId));

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async => page(query.page);

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest request) async => page(request);

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async => ticket(ref);

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async =>
      ticket(expired.source ?? _ref('unknown'), refreshed: true);
}

class _SchemelessTicket extends _ConformingSource {
  const _SchemelessTicket();

  @override
  MediaTicket ticket(ContentRef ref, {bool refreshed = false}) => _ticket(ref, uri: 'plain-text-link');
}

class _UnknownProtocolTicket extends _ConformingSource {
  const _UnknownProtocolTicket();

  @override
  MediaTicket ticket(ContentRef ref, {bool refreshed = false}) => _ticket(ref, protocol: MediaProtocol.unknown);
}

class _ExpiredOnArrivalTicket extends _ConformingSource {
  const _ExpiredOnArrivalTicket();

  @override
  MediaTicket ticket(ContentRef ref, {bool refreshed = false}) {
    final now = DateTime.now().toUtc();
    return _ticket(
      ref,
      createdAt: now.subtract(const Duration(hours: 2)),
      expiresAt: now.subtract(const Duration(hours: 1)),
    );
  }
}

class _ExpiryBeforeCreated extends _ConformingSource {
  const _ExpiryBeforeCreated();

  @override
  MediaTicket ticket(ContentRef ref, {bool refreshed = false}) {
    final now = DateTime.now().toUtc();
    return _ticket(ref, createdAt: now, expiresAt: now.subtract(const Duration(minutes: 5)));
  }
}

class _TicketForOtherContent extends _ConformingSource {
  const _TicketForOtherContent();

  @override
  MediaTicket ticket(ContentRef ref, {bool refreshed = false}) => _ticket(ref, attributedTo: _ref('other-room'));
}

class _RefreshReturnsTheSameTicket extends _ConformingSource {
  const _RefreshReturnsTheSameTicket();

  @override
  MediaTicket ticket(ContentRef ref, {bool refreshed = false}) => _ticket(ref);
}

class _ResolveThrows extends _ConformingSource {
  const _ResolveThrows();

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async =>
      throw StateError('login required');
}

class _WrongPageNumber extends _ConformingSource {
  const _WrongPageNumber();

  @override
  PageResult<ContentSummary> page(PageRequest request, {bool hasMore = false}) =>
      _page(_items(3), request, page: request.page + 6);
}

class _PageLongerThanRequested extends _ConformingSource {
  const _PageLongerThanRequested();

  @override
  PageResult<ContentSummary> page(PageRequest request, {bool hasMore = false}) =>
      _page(_items(request.pageSize + 1), request);
}

class _EmptyPageClaimingMore extends _ConformingSource {
  const _EmptyPageClaimingMore();

  @override
  PageResult<ContentSummary> page(PageRequest request, {bool hasMore = false}) =>
      _page(const <ContentSummary>[], request, hasMore: true);
}

class _ForeignRefs extends _ConformingSource {
  const _ForeignRefs();

  @override
  PageResult<ContentSummary> page(PageRequest request, {bool hasMore = false}) =>
      _page(<ContentSummary>[_summary('item-0', sourceId: 'another-source')], request);
}

class _BlankTitle extends _ConformingSource {
  const _BlankTitle();

  @override
  PageResult<ContentSummary> page(PageRequest request, {bool hasMore = false}) =>
      _page(<ContentSummary>[_summary('item-0', title: '   ')], request);
}

class _DetailAnswersOtherContent extends _ConformingSource {
  const _DetailAnswersOtherContent();

  @override
  Future<ContentDetail> detail(ContentRef ref) async => ContentDetail(summary: _summary('other-room'));
}

class _DetailThrows extends _ConformingSource {
  const _DetailThrows();

  @override
  Future<ContentDetail> detail(ContentRef ref) async => throw StateError('no such room');
}

class _DuplicateFeedItem extends _ConformingSource {
  const _DuplicateFeedItem();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest request) async =>
      _page(<ContentSummary>[_summary('item-0'), _summary('item-0')], request);
}

class _SearchFindsNothing extends _ConformingSource {
  const _SearchFindsNothing();

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async => _page(const <ContentSummary>[], query.page);
}

class _Probe implements ContractProbe {
  const _Probe();

  @override
  SourceId get sourceId => _sourceId;

  @override
  ContentRef get playableRef => _ref('room-1');

  @override
  ContentQuery get browseQuery => const ContentQuery(category: 'rooms', page: PageRequest(page: 1, pageSize: 10));

  @override
  SearchQuery get searchQuery => const SearchQuery(keyword: 'room', page: PageRequest(page: 1, pageSize: 10));
}

class _Subject implements ContractSubject {
  _Subject(this.source, {Set<CapabilityKind> declared = const <CapabilityKind>{CapabilityKind.live}})
    : declaredCapabilities = CapabilitySet(declared);

  @override
  final Object source;

  @override
  final CapabilitySet declaredCapabilities;

  @override
  ContractProbe get probe => const _Probe();
}

List<String> _codes(List<ContractViolation> violations) =>
    violations.map((violation) => violation.code).toList(growable: false);

void main() {
  const probe = _Probe();

  test('test_checkCapabilityContract_conformingSource_reportsNothing', () async {
    expect(await checkCapabilityContract(_Subject(const _ConformingSource())), isEmpty);
  });

  test('test_checkResolveContract_schemelessUri_reportsUriScheme', () async {
    final violations = await checkResolveContract(const _SchemelessTicket(), probe);
    expect(_codes(violations), contains('contract.resolve.uri_scheme'));
  });

  test('test_checkResolveContract_unknownProtocol_reportsProtocolUnknown', () async {
    final violations = await checkResolveContract(const _UnknownProtocolTicket(), probe);
    expect(_codes(violations), contains('contract.resolve.protocol_unknown'));
  });

  test('test_checkResolveContract_expiredOnArrival_reportsExpiryInPast', () async {
    final violations = await checkResolveContract(const _ExpiredOnArrivalTicket(), probe);
    expect(_codes(violations), contains('contract.resolve.expiry_in_past'));
  });

  test('test_checkResolveContract_expiryBeforeCreated_reportsExpiryBeforeCreated', () async {
    final violations = await checkResolveContract(const _ExpiryBeforeCreated(), probe);
    expect(_codes(violations), contains('contract.resolve.expiry_before_created'));
  });

  test('test_checkResolveTicket_sourceAttributedElsewhere_reportsWrongSourceContent', () async {
    final violations = await checkResolveContract(const _TicketForOtherContent(), probe);
    expect(_codes(violations), contains('contract.resolve.wrong_source_content'));
  });

  test('test_checkResolveContract_refreshReturnsSameTicket_reportsNotFresh', () async {
    final violations = await checkResolveContract(const _RefreshReturnsTheSameTicket(), probe);
    expect(_codes(violations).where((code) => code == 'contract.refresh.not_fresh').length, 3);
  });

  test('test_checkResolveContract_resolveThrows_reportsOnlyThrew', () async {
    final violations = await checkResolveContract(const _ResolveThrows(), probe);
    expect(_codes(violations), <String>['contract.resolve.threw']);
  });

  test('test_checkBrowseContract_wrongPageNumber_echoesPageMismatch', () async {
    final violations = await checkBrowseContract(const _WrongPageNumber(), probe);
    expect(_codes(violations), contains('contract.browse.page_mismatch'));
  });

  test('test_checkBrowseContract_pageLongerThanRequested_echoesPageOverflow', () async {
    final violations = await checkBrowseContract(const _PageLongerThanRequested(), probe);
    expect(_codes(violations), contains('contract.browse.page_overflow'));
  });

  test('test_checkBrowseContract_emptyPageClaimingMore_echoesBothCodes', () async {
    final codes = _codes(await checkBrowseContract(const _EmptyPageClaimingMore(), probe));
    expect(codes, containsAll(<String>['contract.browse.empty', 'contract.browse.hasMore_without_items']));
  });

  test('test_checkBrowseContract_refFromAnotherSource_echoesForeignSource', () async {
    final codes = <String>{
      ..._codes(await checkBrowseContract(const _ForeignRefs(), probe)),
      ..._codes(await checkSearchContract(const _ForeignRefs(), probe)),
    };
    expect(codes, containsAll(<String>['contract.browse.foreign_source', 'contract.search.foreign_source']));
  });

  test('test_checkSearchContract_blankTitle_echoesBlankTitle', () async {
    final violations = await checkSearchContract(const _BlankTitle(), probe);
    expect(_codes(violations), contains('contract.search.blank_title'));
  });

  test('test_checkBrowseContract_detailAnswersOtherContent_echoesRefMismatch', () async {
    final violations = await checkBrowseContract(const _DetailAnswersOtherContent(), probe);
    expect(_codes(violations), contains('contract.browse.detail_ref_mismatch'));
  });

  test('test_checkBrowseContract_detailThrows_echoesDetailThrew', () async {
    final violations = await checkBrowseContract(const _DetailThrows(), probe);
    expect(_codes(violations), contains('contract.browse.detail_threw'));
  });

  test('test_checkFeedContract_duplicateItem_echoesDuplicateRef', () async {
    final violations = await checkFeedContract(const _DuplicateFeedItem(), probe);
    expect(_codes(violations), contains('contract.feed.duplicate_ref'));
  });

  test('test_checkSearchContract_probeKeywordMatchesNothing_echoesEmpty', () async {
    final violations = await checkSearchContract(const _SearchFindsNothing(), probe);
    expect(_codes(violations), contains('contract.search.empty'));
  });

  test('test_checkCapabilityDeclarations_declaredKindWithoutInterfaces_echoesMissingInterface', () {
    final violations = checkCapabilityDeclarations(
      const CapabilitySet(<CapabilityKind>{CapabilityKind.live}),
      Object(),
    );

    expect(_codes(violations), <String>['contract.declaration.missing_interface']);
    expect(violations.single.message, contains('BrowseCapability'));
    expect(violations.single.message, contains('ResolveCapability'));
  });

  test('test_checkCapabilityDeclarations_kindsWithoutInterfacesReportNothing', () {
    // danmaku and epg have no method set in this package yet; a declaration of one is not a contract break.
    expect(
      checkCapabilityDeclarations(
        const CapabilitySet(<CapabilityKind>{CapabilityKind.danmaku, CapabilityKind.epg}),
        Object(),
      ),
      isEmpty,
    );
  });

  test('test_checkCapabilityContract_collectsEverySuiteIntoOneReport', () async {
    final violations = await checkCapabilityContract(
      _Subject(const _BlankTitle(), declared: <CapabilityKind>{CapabilityKind.live, CapabilityKind.feed}),
    );

    expect(
      _codes(violations).toSet(),
      containsAll(<String>['contract.browse.blank_title', 'contract.search.blank_title', 'contract.feed.blank_title']),
    );
  });

  test('test_contractViolation_toJson_exposesCodeAndCapability', () {
    const violation = ContractViolation(
      code: 'contract.browse.empty',
      capability: 'browse',
      message: 'nothing came back',
    );

    expect(violation.toJson(), <String, Object?>{
      'code': 'contract.browse.empty',
      'capability': 'browse',
      'message': 'nothing came back',
    });
    expect('$violation', contains('contract.browse.empty'));
  });
}
