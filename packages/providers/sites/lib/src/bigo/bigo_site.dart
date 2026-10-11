// Module: lib/src/bigo/bigo_site.dart
// Purpose: The Bigo Live source: the finite homepage block, the studio status, the token-handed lease and the
// three-way access gate.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained Bigo line (origin/master
// lib/shared/platforms/bigo/bigo_site.dart). Fresh implementation against the v2 capability contracts, not a
// merge (UPSTREAM_REVIEW_POLICY.md).
//
// The second file of the site: bigo_api.dart owns the requests and the readers, this class only answers the
// capability interfaces.
//
// What this source declares is bounded by what its endpoints answer:
//   * the list is one **finite block**, so its `total` is real and paging is slicing of what was verified; the
//     caller's page size is not honoured because the endpoint does not have one;
//   * there is one stream, so there is a quality menu of one and **no line menu** - a single address is not a
//     choice, and declaring the axis would offer a picker with one item in it;
//   * the search is the site's own ladder: a pasted link or handle goes to the room command, and a word is
//     filtered against the verified block. v1's note is kept - the public web search endpoint answers null even
//     for a known live id, so an empty response from it is not "nobody on the platform matches that name".
//
// Not declared, in the open: the manifest-level `BigoHlsProtection` codec ships with this site (bigo_api.dart,
// tested round-trip), but nothing on the playback path can apply a per-segment transform yet, so a ticket from
// this source feeds the kernel protected bytes for a protected room. That is a queue item for the player layer,
// not a gap to hide by pretending the stream is plain.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'bigo_api.dart';

/// The Bigo source. One [NetworkClient] for the process the source lives in.
final class BigoSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        ResolveCapability,
        QualityCapability,
        LiveRoomCapability,
        LiveStatusCapability {
  BigoSource({NetworkClient? client, Clock? clock, String? cookie, String Function()? jsonpCallback})
    : _cookie = (cookie ?? '').trim(),
      _api = BigoApi(client: client, clock: clock, cookie: cookie, callbackFactory: jsonpCallback),
      _clock = clock ?? systemClock;

  final BigoApi _api;
  final Clock _clock;

  /// Kept for the ticket headers: the api sends it on its own requests, and the media needs the same one.
  final String _cookie;

  /// The one quality id this site has: the single hls lease the studio command issues.
  static const String _profile = 'hls';

  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async => _block(page);

  @override
  Future<List<ContentCategory>> categories() async => const <ContentCategory>[
    // The site publishes no label for this block in the answer; `72` is the only tab the anonymous web list
    // serves, and v1 named it the same way.
    ContentCategory(id: bigoPublicDirectoryId, name: '公开'),
  ];

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category?.trim() ?? '';
    if (category.isNotEmpty && category != bigoPublicDirectoryId) {
      // async on purpose: an unknown tab is a Future error, not a throw that escapes the caller's await.
      throw BigoFailure('bigo serves one public block; tab "$category" does not exist');
    }
    return _block(query.page);
  }

  /// One page of the finite block.
  Future<PageResult<ContentSummary>> _block(PageRequest request) async {
    if (request.page < 1) {
      throw const BigoFailure('block pages start at 1');
    }
    final cards = await _api.directory();
    final start = (request.page - 1) * bigoDirectoryServerRows;
    if (start >= cards.length) {
      return PageResult<ContentSummary>(
        items: const <ContentSummary>[],
        page: request.page,
        pageSize: 0,
        total: cards.length,
        mode: PageMode.fixedPage,
      );
    }
    final slice = cards.sublist(start, (start + bigoDirectoryServerRows).clamp(0, cards.length));
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final card in slice) card.toLiveRoom().summary],
      page: request.page,
      // The caller's page size is not echoed: the endpoint fills a block of its own and this list is sliced from
      // it, so the honest number is the slice's length and the total the block carries.
      pageSize: slice.length,
      hasMore: start + slice.length < cards.length,
      total: cards.length,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = await _api.status(ref.contentId);
    final live = room.toLiveRoom();
    return ContentDetail(
      summary: live.summary,
      description: live.notice,
      metadata: <String, Object?>{
        'state': live.state.name,
        'access': room.access.name,
        'roomStatus': room.roomStatus,
        'roomType': room.roomType,
      },
    );
  }

  @override
  Future<LiveRoom> room(ContentRef ref) async => (await _api.room(ref.contentId)).toLiveRoom();

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    // The status call answers on-air-ness without the token handshake, so a follow-list poll costs one request.
    final room = await _api.status(ref.contentId);
    return LiveRoomStatus(
      ref: ref,
      state: room.state,
      title: room.title.isEmpty ? null : room.title,
      cover: (room.snapshot?.isNotEmpty ?? false) ? room.snapshot : room.avatar,
      anchorName: room.nickname.isEmpty ? null : room.nickname,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final term = query.keyword.trim();
    if (query.page.page != 1) {
      // Every branch below answers from one block or one room; a second page would be the same rows again.
      return PageResult<ContentSummary>(
        items: const <ContentSummary>[],
        page: query.page.page,
        pageSize: 0,
        mode: PageMode.singleShot,
      );
    }
    if (term.isEmpty || term.length > 100 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(term)) {
      throw const BigoFailure('a search term must be 1-100 printable characters');
    }
    final handle = bigoHandleFromText(term);
    final uri = Uri.tryParse(term);
    final isLink = uri != null && uri.hasScheme;
    // A handle-shaped term is checked against the room command first, because that is the only authority on
    // whether the handle exists. Digits, dots and dashes are what real handles are made of; a pure word is a name.
    final looksLikeHandle = RegExp(r'[0-9_.\-]').hasMatch(term);
    if (handle != null && (isLink || looksLikeHandle)) {
      final exact = await _exact(handle);
      // A link that is a bigo page but not a room page resolves to nothing here; asking the block about
      // `www.bigo.tv/live` would match a room nobody named.
      if (exact.isNotEmpty || isLink) {
        return _found(exact, query.page.page);
      }
    }
    if (isLink && handle == null) {
      return _found(const <LiveRoom>[], 1);
    }
    final cards = await _api.directory();
    final needle = term.toLowerCase();
    final matches = <String, LiveRoom>{};
    for (final card in cards) {
      if (card.nickname.toLowerCase().contains(needle) || card.title.toLowerCase().contains(needle)) {
        matches.putIfAbsent(card.siteId.toLowerCase(), card.toLiveRoom);
      }
    }
    if (matches.isNotEmpty) {
      return _found(matches.values.toList(growable: false), query.page.page);
    }
    // Nothing in the verified block matched a word, so the handle reading still gets its chance: a streamer whose
    // name is also their handle is found by the room command and not by this block.
    if (handle != null) {
      return _found(await _exact(handle), 1);
    }
    return _found(const <LiveRoom>[], 1);
  }

  Future<List<LiveRoom>> _exact(String handle) async {
    try {
      return <LiveRoom>[(await _api.status(handle)).toLiveRoom()];
    } on BigoFailure catch (error) {
      // A 404 here is "no such room", which the search surface shows as no results; a service failure is still a
      // failure and is not allowed to look like an empty search.
      if (error.missing) {
        return const <LiveRoom>[];
      }
      rethrow;
    }
  }

  PageResult<ContentSummary> _found(List<LiveRoom> rooms, int page) => PageResult<ContentSummary>(
    items: <ContentSummary>[for (final room in rooms) room.summary],
    page: page,
    pageSize: rooms.length,
    total: rooms.length,
    mode: PageMode.singleShot,
  );

  /// One profile, unnamed. The site ships a single hls lease and gives it no label, so none is invented.
  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final room = await _api.room(ref.contentId);
    if (room.hls == null) {
      return const <StreamOption>[];
    }
    return <StreamOption>[
      StreamOption(
        id: _profile,
        kind: StreamOptionKind.quality,
        isDefault: true,
        available: true,
        requiresAuth: room.restriction != LiveRestriction.none,
      ),
    ];
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final room = await _api.room(ref.contentId);
    if (quality != null && quality.id.trim() != _profile) {
      throw StateError('Bigo serves one stream (the hls lease); quality "${quality.id}" does not exist');
    }
    if (line != null) {
      throw StateError('Bigo serves one address for that stream; line "${line.id}" does not exist');
    }
    if (room.access != BigoAccess.public) {
      // Naming which gate it is, because the viewer pressed play and the reason is the difference between "log in"
      // and "this room is paid".
      throw StateError(switch (room.access) {
        BigoAccess.loginRequired => 'Bigo room ${room.siteId} requires an account this path does not have',
        BigoAccess.restricted => 'Bigo room ${room.siteId} is a password or paid room',
        BigoAccess.public => 'Bigo room ${room.siteId} is not restricted',
      });
    }
    if (room.state == LiveRoomState.ended) {
      throw StateError('Bigo room ${room.siteId} is not broadcasting');
    }
    final hls = room.hls;
    if (hls == null) {
      // `unknown` lands here too and keeps its own wording: the site did not settle whether this is on air, which
      // is not the same claim as an ended broadcast.
      throw StateError(
        room.state == LiveRoomState.unknown
            ? 'Bigo room ${room.siteId} did not say it is broadcasting and shipped no address'
            : 'Bigo room ${room.siteId} is on air but shipped no address we are willing to open',
      );
    }
    return MediaTicket(
      id: '$bigoSourceId/${room.siteId}',
      uri: hls,
      kind: MediaKind.live,
      protocol: MediaProtocol.hls,
      createdAt: _clock().toUtc(),
      headers: <String, String>{...bigoApiHeaders, if (_cookie.isNotEmpty) 'cookie': _cookie},
      // The lease is issued alongside the token for this call; the answer states no length, so none is invented
      // and the host re-handshakes when the stream dies.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: bigoSourceId, contentId: room.siteId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        title: room.title.isEmpty ? room.nickname : room.title,
        artist: room.nickname,
        isLive: true,
        extra: <String, Object?>{
          'container': 'm3u8',
          'bigo.quality': _profile,
          'bigo.ownerId': room.ownerId,
          if (room.roomId != null) 'bigo.roomId': room.roomId,
        },
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$bigoSourceId/';
    if (!expired.id.startsWith(prefix)) {
      throw StateError('Bigo ticket ${expired.id} does not name a room');
    }
    return resolve(
      // Both halves of the lease die together: the address is issued alongside a current token, so a refresh is a
      // fresh handshake rather than a reuse of the dead url.
      ContentRef(sourceId: bigoSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
      quality: const SelectionRef(_profile),
    );
  }
}
