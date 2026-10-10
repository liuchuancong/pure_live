// Module: lib/src/demo_source.dart
// Purpose: The reference provider: static rooms, no network, every capability answered the way the contract says.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/capability-contract.md section 3. This source exists so the chain
// registration -> capability registry -> feed aggregator -> home UI is exercisable end to end, and so a new
// provider has one in-repo example of each method's *obligations*: real paging rather than one page forever,
// a category list built from its own rows, a selection that is validated instead of ignored, and an unknown
// ref refused rather than answered with something invented. A fixture that fudges those teaches the fudge.
//
// Playback serves a public test HLS stream (Mux's Big Buck Bunny asset). It is a VOD file, and the ticket says
// so - the point being proven is the plumbing, never the content.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

/// The source id every row this source serves carries.
const String demoSourceId = 'demo.live';

/// One demo room.
final class DemoRoom {
  const DemoRoom({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.host = 'Demo 主播',
  });

  final String id;
  final String title;
  final String subtitle;

  /// The category the room is filed under, which `categories()` publishes and `browse` filters on.
  final String category;
  final String host;
}

/// The rooms the demo source serves.
const List<DemoRoom> demoRooms = <DemoRoom>[
  DemoRoom(id: 'room-01', title: '一起看 · 重构进行时', subtitle: '纯度 100 · 一起看', category: '一起看', host: '纯度 100'),
  DemoRoom(id: 'room-02', title: '深夜电波电台', subtitle: '阿波 · 唱见', category: '唱见', host: '阿波'),
  DemoRoom(id: 'room-03', title: '王者峡谷上分之路', subtitle: '老亚瑟 · 游戏', category: '游戏', host: '老亚瑟'),
  DemoRoom(id: 'room-04', title: '像素风独立游戏通关', subtitle: '像素君 · 游戏', category: '游戏', host: '像素君'),
  DemoRoom(id: 'room-05', title: '卧室弹唱点歌台', subtitle: '小鹿 · 唱见', category: '唱见', host: '小鹿'),
  DemoRoom(id: 'room-06', title: '硬核射击连胜挑战', subtitle: '枪法苦手 · 游戏', category: '游戏', host: '枪法苦手'),
  DemoRoom(id: 'room-07', title: '手冲咖啡研究所', subtitle: '豆子老师 · 生活', category: '生活', host: '豆子老师'),
  DemoRoom(id: 'room-08', title: '桌面相机调试间', subtitle: '快门手 · 生活', category: '生活', host: '快门手'),
  DemoRoom(id: 'room-09', title: '开源社区圆桌夜话', subtitle: '维护者 · 一起看', category: '一起看', host: '维护者'),
  DemoRoom(id: 'room-10', title: '周末马拉松备赛训练', subtitle: '配速员 · 运动', category: '运动', host: '配速员'),
  DemoRoom(id: 'room-11', title: '油画棒风景入门', subtitle: '调色盘 · 绘画', category: '绘画', host: '调色盘'),
  DemoRoom(id: 'room-12', title: '复古游戏机收藏展', subtitle: '卡带猎人 · 游戏', category: '游戏', host: '卡带猎人'),
];

/// The qualities this source offers. One stream backs them all - see the file note - but the ids are real, so
/// a selection survives a round trip and a UI can render a picker that actually picks.
const List<String> demoQualityIds = <String>['source', '720p', '480p'];

/// The lines (sources of the same stream) this source offers.
const List<String> demoLineIds = <String>['primary'];

/// The demo live source. Constructible with no dependencies: registering it costs nothing and it can answer
/// forever without a socket.
final class DemoLiveSource implements BrowseCapability, SearchCapability, FeedCapability, ResolveCapability {
  DemoLiveSource({Clock? clock, this.pageSizeLimit = 50}) : _clock = clock ?? systemClock;

  /// The stream every demo room plays. `final` not `const`: [Uri.parse] is a method call, which a const
  /// initializer cannot contain.
  static final Uri demoStreamUrl = Uri.parse('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8');

  final Clock _clock;
  final int pageSizeLimit;

  /// Rooms by id, so an unknown ref can be refused instead of answered with an invented title.
  static final Map<String, DemoRoom> _byId = <String, DemoRoom>{for (final room in demoRooms) room.id: room};

  @override
  Future<List<ContentCategory>> categories() async {
    // ContentCategory carries no count field, so this is the distinct set in sorted order: a stable order
    // matters more than a grouping order that follows the fixture's arrangement.
    final names = <String>{for (final room in demoRooms) room.category}.toList()..sort();
    return <ContentCategory>[for (final name in names) ContentCategory(id: name, name: name)];
  }

  /// One page of rooms, optionally narrowed to a category.
  ///
  /// This is the fixed-page shape: `hasMore` says whether page N+1 exists and `total` is the whole narrowed
  /// list, so a UI can show a count and stop pulling. `feed` deliberately answers a different mode - a static
  /// list is one shot - and a reference source that used one shape everywhere would not exercise the other.
  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final category = query.category?.trim();
    final rooms = category == null || category.isEmpty
        ? demoRooms
        : <DemoRoom>[
            for (final room in demoRooms)
              if (room.category == category) room,
          ];
    final pageSize = query.page.pageSize.clamp(1, pageSizeLimit);
    final start = (query.page.page - 1).clamp(0, rooms.length) * pageSize;
    final slice = rooms.skip(start).take(pageSize).toList(growable: false);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final room in slice) _summary(room)],
      page: query.page.page,
      pageSize: pageSize,
      hasMore: start + slice.length < rooms.length,
      total: rooms.length,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final keyword = query.keyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return PageResult<ContentSummary>.empty();
    }
    final matches = <DemoRoom>[
      for (final room in demoRooms)
        if (room.title.toLowerCase().contains(keyword) ||
            room.subtitle.toLowerCase().contains(keyword) ||
            room.category.toLowerCase().contains(keyword) ||
            room.host.toLowerCase().contains(keyword))
          room,
    ];
    final pageSize = query.page.pageSize.clamp(1, pageSizeLimit);
    final start = (query.page.page - 1).clamp(0, matches.length) * pageSize;
    final slice = matches.skip(start).take(pageSize).toList(growable: false);
    return PageResult<ContentSummary>(
      items: <ContentSummary>[for (final room in slice) _summary(room)],
      page: query.page.page,
      pageSize: pageSize,
      hasMore: start + slice.length < matches.length,
      total: matches.length,
      mode: PageMode.fixedPage,
    );
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final room = _byId[ref.contentId];
    if (room == null) {
      throw StateError('$demoSourceId has no room ${ref.contentId}');
    }
    return ContentDetail(
      summary: ContentSummary(
        ref: ContentRef(sourceId: demoSourceId, contentId: room.id, kind: ContentKind.liveRoom),
        title: room.title,
        subtitle: room.subtitle,
        description: '${room.host} 的 ${room.category} 直播间(示例数据,不指向真实站点)',
        metadata: const ContentMetadata(
          extra: <String, Object?>{'qualities': demoQualityIds, 'lines': demoLineIds, 'isLive': true},
        ),
      ),
      description: '${room.host} 的 ${room.category} 直播间(示例数据,不指向真实站点)',
      tags: <ContentTag>[ContentTag(id: room.category, name: room.category)],
    );
  }

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    // One static page, and `hasMore` stays false on purpose: a source that cannot serve a next page but
    // reports one keeps the consumer's list spinning, which the paging contract names as the worst failure.
    if (page.page > 1) {
      return PageResult<ContentSummary>(
        items: const <ContentSummary>[],
        page: page.page,
        pageSize: page.pageSize,
        total: 0,
        mode: PageMode.singleShot,
      );
    }
    final items = <ContentSummary>[for (final room in demoRooms) _summary(room)];
    return PageResult<ContentSummary>(
      items: items,
      page: 1,
      pageSize: items.length,
      total: items.length,
      mode: PageMode.singleShot,
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final room = _byId[ref.contentId];
    if (room == null) {
      // A ticket for content this source does not have is worse than an error: the player starts, the
      // diagnostics say success, and the room the user tapped is never the room on screen.
      throw StateError('$demoSourceId has no room ${ref.contentId}');
    }
    final wanted = quality?.id.trim();
    if (wanted != null && wanted.isNotEmpty && !demoQualityIds.contains(wanted)) {
      throw StateError('$demoSourceId has no quality "$wanted"; it offers ${demoQualityIds.join(', ')}');
    }
    final wantedLine = line?.id.trim();
    if (wantedLine != null && wantedLine.isNotEmpty && !demoLineIds.contains(wantedLine)) {
      throw StateError('$demoSourceId has no line "$wantedLine"; it offers ${demoLineIds.join(', ')}');
    }
    // The stream never expires, so there is no expiresAt to declare: the contract makes that the signal that
    // no prefetch is needed, not a field to invent a deadline for.
    return MediaTicket(
      id: '$demoSourceId/${room.id}',
      uri: demoStreamUrl,
      kind: MediaKind.vod,
      protocol: MediaProtocol.hls,
      createdAt: _clock().toUtc(),
      headers: const <String, String>{'user-agent': 'PureLiveDemo/1.0'},
      refresh: const MediaTicketRefreshInfo(supported: false),
      metadata: MediaPlaybackMetadata(
        title: room.title,
        isLive: false,
        extra: <String, Object?>{
          'quality': wanted ?? demoQualityIds.first,
          'line': wantedLine ?? demoLineIds.first,
          'category': room.category,
        },
      ),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    // A static url cannot go stale, so a refresh returns the same ticket with a stable id: diagnostics can see
    // the swap replaced like with like rather than silently fetching a second address.
    return expired;
  }

  static ContentSummary _summary(DemoRoom room) => ContentSummary(
    ref: ContentRef(sourceId: demoSourceId, contentId: room.id, kind: ContentKind.liveRoom),
    title: room.title,
    subtitle: room.subtitle,
    description: room.category,
    metadata: const ContentMetadata(extra: <String, Object?>{'isLive': true}),
  );
}
