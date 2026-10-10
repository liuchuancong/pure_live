// Module: lib/src/demo_source.dart
// Purpose: An in-repo live source that answers the feed capability with static rooms and no network access.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/capability-contract.md section 3 (the feed method set). The demo source exists so the
// chain registration -> capability registry -> feed aggregator -> home UI is exercisable end to end before
// the first real site provider lands in W4. Its rooms are static data on purpose: the point being proven is
// the plumbing, never the content.

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

/// The source id every row this source serves carries.
const String demoSourceId = 'demo.live';

/// The rooms the demo source serves. A record list keeps the fixture readable
/// next to the code that turns it into summaries.
const List<({String id, String title, String subtitle})> demoRooms = <({String id, String title, String subtitle})>[
  (id: 'room-01', title: '一起看 · 重构进行时', subtitle: '纯度 100 · 一起看'),
  (id: 'room-02', title: '深夜电波电台', subtitle: '阿波 · 唱见'),
  (id: 'room-03', title: '王者峡谷上分之路', subtitle: '老亚瑟 · 游戏'),
  (id: 'room-04', title: '像素风独立游戏通关', subtitle: '像素君 · 游戏'),
  (id: 'room-05', title: '卧室弹唱点歌台', subtitle: '小鹿 · 唱见'),
  (id: 'room-06', title: '硬核射击连胜挑战', subtitle: '枪法苦手 · 游戏'),
  (id: 'room-07', title: '手冲咖啡研究所', subtitle: '豆子老师 · 生活'),
  (id: 'room-08', title: '桌面相机调试间', subtitle: '快门手 · 生活'),
  (id: 'room-09', title: '开源社区圆桌夜话', subtitle: '维护者 · 一起看'),
  (id: 'room-10', title: '周末马拉松备赛训练', subtitle: '配速员 · 运动'),
  (id: 'room-11', title: '油画棒风景入门', subtitle: '调色盘 · 绘画'),
  (id: 'room-12', title: '复古游戏机收藏展', subtitle: '卡带猎人 · 游戏'),
];

/// The demo live source. Const-constructible and dependency-free: registering it
/// costs nothing and it can answer forever without a socket.
///
/// Playback serves a public test HLS stream (Mux's Big Buck Bunny asset) so the
/// media chain is exercisable end to end; the resource is a VOD file and the
/// ticket says so honestly instead of pretending to be a running broadcast.
final class DemoLiveSource implements BrowseCapability, FeedCapability, ResolveCapability {
  const DemoLiveSource();

  /// The stream every demo room plays. `final` not `const`: [Uri.parse] is a
  /// method call, which a const initializer cannot contain.
  static final Uri demoStreamUrl = Uri.parse('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8');

  @override
  Future<List<ContentCategory>> categories() async => const <ContentCategory>[];

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) => feed(query.page);

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    return ContentDetail(
      summary: ContentSummary(ref: ref, title: '直播间 ${ref.contentId}', subtitle: 'Demo 直播源'),
      description: '示例源的房间详情',
    );
  }

  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    // One static page. hasMore stays false on purpose: a source that cannot serve a next page but reports
    // one keeps the consumer's list spinning forever, which the paging contract names as the worst failure.
    if (page.page > 1) {
      return PageResult<ContentSummary>(items: const <ContentSummary>[], page: page.page, pageSize: page.pageSize);
    }
    final items = <ContentSummary>[
      for (final room in demoRooms)
        ContentSummary(
          ref: ContentRef(sourceId: demoSourceId, contentId: room.id, kind: ContentKind.liveRoom),
          title: room.title,
          subtitle: room.subtitle,
        ),
    ];
    // The demo list is static and whole: declaring singleShot is the honest
    // reading, and it exercises the mode the fixed-page sources never use.
    return PageResult<ContentSummary>(
      items: items,
      page: 1,
      pageSize: page.pageSize,
      total: items.length,
      mode: PageMode.singleShot,
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    // The stream never expires, so there is no expiresAt to declare: the contract makes that the source's
    // signal that no prefetch is needed, not a field to invent a deadline for.
    return MediaTicket(
      id: '$demoSourceId/${ref.contentId}',
      uri: demoStreamUrl,
      kind: MediaKind.vod,
      protocol: MediaProtocol.hls,
      createdAt: DateTime.now().toUtc(),
      refresh: const MediaTicketRefreshInfo(supported: false),
      metadata: const MediaPlaybackMetadata(isLive: false),
    );
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    // A static url cannot go stale, so a refresh request returns the same ticket; the id is kept stable
    // so diagnostics can see the swap replaced like with like.
    return expired;
  }
}
