# Live Source Contract

> LiveCapability 的方法级契约;契约测试 [../../development/testing.md](../../development/testing.md) 按此断言。

## 方法

```dart
abstract class LiveCapability {
  /// 分类目录(分区)
  Future<Page<ContentItem>> browse(CategoryRef? category, {Cursor? cursor});
  /// 房间详情(标题/封面/主播/开播状态/分区)
  Future<LiveDetail> detail(ContentRef room);
  /// 搜索(实现 SearchCapability 时聚合至此)
  Future<Page<SearchItem>> search(SearchRequest request);
  /// 取流:必须返回含 expiresAt 的 MediaTicket(StreamTicket)
  Future<MediaTicket> resolve(ContentRef room, {QualityRef? quality, LineRef? line});
  /// 刷新(到期/故障)
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason);
  /// 清晰度与线路
  Future<List<QualityLine>> qualities(ContentRef room);
}
```

## 语义要求

- `resolve` 可因未登录/需要登录被拒(`AuthRequired` 异常 → 上层引导登录)。
- 多线路:首选线路失败自动降级;`urls` 顺序即优先级。
- 弹幕/表情/画质记忆不在 LiveCapability 内:弹幕是独立 capability,记忆在 settings_repository。
