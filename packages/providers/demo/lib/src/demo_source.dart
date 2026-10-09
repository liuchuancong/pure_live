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
final class DemoLiveSource implements FeedCapability {
  const DemoLiveSource();

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
    return PageResult<ContentSummary>(items: items, page: 1, pageSize: page.pageSize, total: items.length);
  }
}
