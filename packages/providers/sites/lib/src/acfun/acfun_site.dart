// Module: lib/src/acfun/acfun_site.dart
// Purpose: The AcFun live source: cursor directory, categories, anchor search, room status, qualities and the
// visitor-signed play ticket.
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge follows the v1-maintained AcFun line (origin/master
// lib/shared/platforms/acfun/acfun_site.dart). Fresh implementation against the v2 capability contracts, not a
// merge (UPSTREAM_REVIEW_POLICY.md). Anonymous surface only: no account qualities, no danmaku socket yet, no
// super-chat.
//
// The second file of the site: acfun_api.dart owns the requests and the readers, and this class only answers the
// capability interfaces from them. It reads no JSON field itself.
//
// AcFun addresses a room by its **author id**, not by a room id. That is not a naming preference: the directory
// row, the info envelope and the play request all key on the author, while the liveId is per-broadcast. A ref
// built from a liveId would point at one evening's stream instead of the channel, and stop resolving the moment
// the anchor goes off air.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import '../common/site_json.dart';
import 'acfun_api.dart';

/// The metadata key holding the liveId the ticket was minted for, so a refresh can name the broadcast it replaced.
const String acfunLiveIdKey = 'acfun.liveId';

/// The metadata key recording a quality the viewer asked for that the answer no longer carries.
const String acfunRequestedQualityKey = 'acfun.requestedQuality';

/// The metadata key recording the quality a ticket was opened at.
const String acfunQualityKey = 'acfun.quality';

/// The metadata key recording the 1-based url position a ticket was opened from.
const String acfunLineKey = 'acfun.line';

/// The AcFun source. One [NetworkClient] for the process the source lives in.
final class AcfunSource
    implements
        FeedCapability,
        BrowseCapability,
        SearchCapability,
        AnchorSearchCapability,
        ResolveCapability,
        QualityCapability,
        LineCapability,
        LiveStatusCapability {
  AcfunSource({NetworkClient? client, Clock? clock})
    : _api = AcfunApi(client: client, clock: clock),
      _clock = clock ?? systemClock;

  final AcfunApi _api;
  final Clock _clock;

  /// Releases the transport the api built. A client handed in from the composition root belongs to the root, and
  /// is left open for its other consumers.
  void dispose() => _api.dispose();

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) => _directory(page, null);

  @override
  Future<List<ContentCategory>> categories() async {
    // count:1 is the cheapest answer that still carries the filter table; the 30-room default would be paying for
    // rows we throw away to read a menu.
    final data = await _api.directory(count: 1);
    return <ContentCategory>[
      for (final category in data.categories)
        ContentCategory(
          id: AcfunCategory.encode(category.type, category.id),
          name: category.name,
          icon: category.cover,
        ),
    ];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) {
    final category = query.category;
    if (category == null || category.isEmpty) {
      return _directory(query.page, null);
    }
    return _directory(query.page, category);
  }

  Future<PageResult<ContentSummary>> _directory(PageRequest page, String? filters) async {
    // A page number is meaningless here: the endpoint's continuation is `pcursor`, and only the previous answer
    // can supply it. Asking for page 4 without the cursor would be answered as page 1, which is worse than
    // refusing - the list would silently restart and read as a duplicate-row bug downstream.
    if (page.cursor == null && page.page > 1) {
      throw AcfunApiFailure(
        'AcFun pages continue by cursor; page ${page.page} was asked without the nextCursor that produces it',
      );
    }
    final data = await _api.directory(cursor: page.cursor ?? '', count: page.pageSize, filters: filters);
    final seen = <String>{};
    final items = <ContentSummary>[
      for (final row in data.rooms)
        if (_summaryFromRow(row) case final ContentSummary summary when seen.add(summary.ref.contentId)) summary,
    ];
    return PageResult<ContentSummary>(
      items: items,
      page: page.page,
      pageSize: page.pageSize,
      // The cursor is the only end signal the directory gives; there is no total to consult.
      hasMore: data.cursor != null,
      mode: PageMode.cursor,
      nextCursor: data.cursor,
    );
  }

  ContentSummary? _summaryFromRow(Map<String, Object?> row) {
    final authorId = '${row['authorId'] ?? ''}'.trim();
    if (authorId.isEmpty) {
      return null;
    }
    final user = jsonMap(row['user']) ?? const <String, Object?>{};
    final nick = '${user['name'] ?? ''}'.trim();
    final area = '${(jsonMap(row['type']) ?? const <String, Object?>{})['name'] ?? ''}'.trim();
    final title = '${row['title'] ?? ''}'.trim();
    final covers = jsonList(row['coverUrls']);
    return ContentSummary(
      ref: ContentRef(sourceId: acfunSourceId, contentId: authorId, kind: ContentKind.liveRoom),
      title: title.isEmpty ? nick : title,
      subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
      cover: covers.isEmpty ? null : '${covers.first}',
      metadata: ContentMetadata(
        popularity: jsonInt(row['onlineCount']),
        extra: <String, Object?>{if (nick.isNotEmpty) 'anchorName': nick},
      ),
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final authorId = AcfunApi.normalizeAuthorId(ref.contentId);
    final data = await _api.roomInfo(authorId);
    final live = AcfunApi.liveInRoomEnvelope(data, authorId);
    final summary = _summaryFromEnvelope(authorId, data);
    return ContentDetail(
      summary: summary,
      description: summary.description,
      // The envelope is the only answer that states whether the anchor is on air right now, and a room page needs
      // it: the directory row it came from said only that they were live when that page was built.
      metadata: <String, Object?>{'isLive': live},
    );
  }

  ContentSummary _summaryFromEnvelope(String authorId, Map<String, Object?> data) {
    final user = jsonMap(data['user']) ?? const <String, Object?>{};
    final nick = '${user['name'] ?? ''}'.trim();
    final area = '${(jsonMap(data['type']) ?? const <String, Object?>{})['name'] ?? ''}'.trim();
    final covers = jsonList(data['coverUrls']);
    final title = '${data['title'] ?? ''}'.trim();
    final introduction = '${data['introduction'] ?? ''}'.trim();
    final avatar = '${user['headUrl'] ?? ''}'.trim();
    final startedAt = _startTime(data['createTime']);
    return ContentSummary(
      ref: ContentRef(sourceId: acfunSourceId, contentId: authorId, kind: ContentKind.liveRoom),
      title: title.isEmpty ? nick : title,
      subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
      cover: covers.isEmpty ? null : '${covers.first}',
      description: introduction.isEmpty ? null : introduction,
      metadata: ContentMetadata(
        popularity: jsonInt(data['onlineCount']),
        extra: <String, Object?>{
          if (nick.isNotEmpty) 'anchorName': nick,
          if (avatar.isNotEmpty) 'avatar': avatar,
          if (startedAt != null) 'startedAt': startedAt.toIso8601String(),
        },
      ),
    );
  }

  /// `createTime` is a millisecond stamp; a value outside the plausible range is a field that meant something
  /// else, and reading it as a 1970 start would put "已直播 56 年" on a live room page.
  static DateTime? _startTime(Object? raw) {
    final value = jsonInt(raw);
    if (value == null || value < 1000000000000 || value >= 10000000000000) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  @override
  Future<LiveRoomStatus> liveStatus(ContentRef ref) async {
    final authorId = AcfunApi.normalizeAuthorId(ref.contentId);
    final data = await _api.roomInfo(authorId);
    final live = AcfunApi.liveInRoomEnvelope(data, authorId);
    final user = jsonMap(data['user']) ?? const <String, Object?>{};
    final nick = '${user['name'] ?? ''}'.trim();
    final covers = jsonList(data['coverUrls']);
    return LiveRoomStatus(
      ref: ref,
      state: live ? LiveRoomState.live : LiveRoomState.ended,
      viewers: jsonInt(data['onlineCount']),
      title: '${data['title'] ?? ''}'.trim().isEmpty ? null : '${data['title']}'.trim(),
      cover: covers.isEmpty ? null : '${covers.first}',
      anchorName: nick.isEmpty ? null : nick,
      startedAt: live ? _startTime(data['createTime']) : null,
    );
  }

  /// The quality menu as `startPlay` described it.
  ///
  /// These are real choices rather than an invented ladder: the manifest lists what this room is encoded at, and
  /// the labels are the site's own ("蓝光", "超清"). `rank` carries the site's level so a menu orders the way the
  /// player would, not the way a bitrate number would.
  @override
  Future<List<StreamOption>> qualities(ContentRef ref) async {
    final playback = await _api.playback(AcfunApi.normalizeAuthorId(ref.contentId));
    final preferred = playback.preferred;
    return <StreamOption>[
      for (final quality in playback.qualities)
        StreamOption(
          id: quality.id,
          kind: StreamOptionKind.quality,
          label: quality.label,
          isDefault: identical(quality, preferred),
          rank: quality.rank,
          available: quality.urls.isNotEmpty,
        ),
    ];
  }

  /// The delivery paths of the quality the source itself would pick, numbered.
  ///
  /// AcFun ships several cdn urls per quality and names none of them, so a line is an ordinal - the rule huya's
  /// CDN rows follow too. It is scoped to the default quality on purpose: urls belong to the manifest row they
  /// came from, and mixing two qualities' urls onto one axis would let a viewer choose a combination that never
  /// existed.
  @override
  Future<List<StreamOption>> lines(ContentRef ref) async {
    final playback = await _api.playback(AcfunApi.normalizeAuthorId(ref.contentId));
    final preferred = playback.preferred;
    if (preferred == null) {
      return const <StreamOption>[];
    }
    return <StreamOption>[
      for (var index = 0; index < preferred.urls.length; index++)
        StreamOption(id: '${index + 1}', kind: StreamOptionKind.line, isDefault: index == 0),
    ];
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final page = await _api.search(query.keyword, page: query.page.page);
    final items = <ContentSummary>[
      for (final card in page.cards)
        ContentSummary(
          ref: ContentRef(sourceId: acfunSourceId, contentId: card.authorId, kind: ContentKind.liveRoom),
          title: card.name,
          subtitle: card.introduction,
          cover: card.avatar,
          metadata: ContentMetadata(
            extra: <String, Object?>{
              // A card that does not say is not a card that said "offline"; the surface has to tell those apart,
              // and this is the field that does it.
              if (card.isLive != null) 'isLive': card.isLive,
              if (card.followerLabel != null) 'followers': card.followerLabel,
            },
          ),
        ),
    ];
    return _paged(page, items, query.page.pageSize);
  }

  @override
  Future<PageResult<AnchorSummary>> searchAnchors(SearchQuery query) async {
    // The search endpoint *is* the anchor endpoint here - `type=user` is the only thing it can search - so this is
    // the same page read as people instead of as rooms. Declaring it separately is what lets a surface offer
    // "搜主播" honestly on this site and leave it absent on the sites that cannot answer it.
    final page = await _api.search(query.keyword, page: query.page.page);
    final anchors = <AnchorSummary>[
      for (final card in page.cards)
        AnchorSummary(
          ref: ContentRef(sourceId: acfunSourceId, contentId: card.authorId, kind: ContentKind.anchor),
          name: card.name,
          avatar: card.avatar,
          description: card.introduction,
          currentRoom: card.isLive == true
              ? ContentRef(sourceId: acfunSourceId, contentId: card.authorId, kind: ContentKind.liveRoom)
              : null,
          extra: <String, Object?>{if (card.followerLabel != null) 'followers': card.followerLabel},
        ),
    ];
    return _paged(page, anchors, query.page.pageSize);
  }

  PageResult<T> _paged<T>(AcfunSearchPage page, List<T> items, int requestedSize) {
    final total = page.total;
    return PageResult<T>(
      items: items,
      page: page.page,
      // The endpoint serves its own page size and ignores a requested one; reporting the requested number here
      // would make a 10-row page look like a truncated 20-row page.
      pageSize: acfunSearchServerPageSize,
      // The page states a total, so continuation is arithmetic rather than a guess from a full page.
      hasMore: total == null ? items.isNotEmpty : page.page * acfunSearchServerPageSize < total,
      total: total,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final authorId = AcfunApi.normalizeAuthorId(ref.contentId);
    final playback = await _api.playback(authorId);
    if (playback.preferred == null) {
      throw StateError('AcFun room $authorId describes no playable quality');
    }
    final wanted = _quality(playback, quality);
    final index = _lineIndex(line, wanted.urls.length);
    final uri = Uri.parse(wanted.urls[index]);
    return MediaTicket(
      id: '$acfunSourceId/$authorId',
      uri: uri,
      kind: MediaKind.live,
      // The manifest urls are FLV over https on this site. FLV is a container and https is the transport, so the
      // container goes to the metadata while the enum records the transport - the split douyu's answer follows.
      protocol: _protocolOf(uri),
      createdAt: _clock().toUtc(),
      headers: Map<String, String>.from(acfunWebHeaders),
      // The play answer states no expiry of its own, so no deadline is invented here: the contract makes
      // expiresAt the prefetch trigger, and a guessed one either cuts a working stream short or lets a dead one
      // run past its life.
      refresh: const MediaTicketRefreshInfo(supported: true),
      source: ContentRef(sourceId: acfunSourceId, contentId: authorId, kind: ContentKind.liveRoom),
      metadata: MediaPlaybackMetadata(
        isLive: true,
        extra: <String, Object?>{
          'container': _containerOf(uri),
          acfunLiveIdKey: playback.liveId,
          acfunQualityKey: wanted.id,
          acfunLineKey: index + 1,
          // Echoed so a surface can show what was asked against what was given: silently falling back is how
          // "I chose 蓝光" becomes "it played 高清" with nothing on screen explaining it.
          if (quality != null && quality.id.trim() != wanted.id) acfunRequestedQualityKey: quality.id,
        },
      ),
    );
  }

  /// The quality to open. An id the fresh answer no longer carries is not a reason to fail the open - the
  /// manifest changes between the menu read and the play read - but it is a reason to record what was asked.
  AcfunQuality _quality(AcfunPlayback playback, SelectionRef? quality) {
    final id = quality?.id.trim() ?? '';
    if (id.isEmpty) {
      return playback.preferred!;
    }
    final wanted = playback.qualityById(id);
    if (wanted != null && wanted.urls.isNotEmpty) {
      return wanted;
    }
    return playback.preferred!;
  }

  int _lineIndex(SelectionRef? line, int available) {
    if (line == null) {
      return 0;
    }
    final wanted = int.tryParse(line.id.trim());
    if (wanted == null || wanted < 1 || wanted > available) {
      throw StateError(
        'AcFun offers $available url(s) for this quality; line "${line.id}" is not one of them '
        '(they are named by position, not by a label the source never gave)',
      );
    }
    return wanted - 1;
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final prefix = '$acfunSourceId/';
    if (!expired.id.startsWith(prefix)) {
      // async on purpose: a Future-typed method that throws synchronously escapes the caller's await and the
      // recovery ladder sitting behind it.
      throw StateError('AcFun ticket ${expired.id} does not name a room');
    }
    final extra = expired.metadata.extra;
    final quality = extra[acfunQualityKey];
    final line = extra[acfunLineKey];
    return resolve(
      ContentRef(sourceId: acfunSourceId, contentId: expired.id.substring(prefix.length), kind: ContentKind.liveRoom),
      // The quality and the cdn position travel in the ticket, so a refresh on 蓝光 line 2 does not move the
      // viewer to the default of a different manifest row.
      quality: quality is String && quality.isNotEmpty ? SelectionRef(quality) : null,
      line: line == null ? null : SelectionRef('$line'),
    );
  }

  static MediaProtocol _protocolOf(Uri uri) {
    if (uri.scheme == 'rtmp' || uri.scheme == 'rtsp') {
      return uri.scheme == 'rtmp' ? MediaProtocol.rtmp : MediaProtocol.rtsp;
    }
    if (uri.path.toLowerCase().endsWith('.m3u8')) {
      return MediaProtocol.hls;
    }
    return uri.scheme == 'http' ? MediaProtocol.http : MediaProtocol.https;
  }

  static String _containerOf(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8')) {
      return 'm3u8';
    }
    if (path.endsWith('.flv')) {
      return 'flv';
    }
    return 'unknown';
  }
}
