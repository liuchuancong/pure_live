# ContentRef

```dart
class ContentRef {
  final String sourceId;   // 插件 id(ContentRef 的命名空间)
  final ContentKind kind;
  final String id;
  final String? parentId;
}
```

## URI 形态

```text
bilibili://vod/BV1xxx      douyu://live/123456
netease://song/123456      tvbox://vod/xxxx
local://video/xxxx         bilibili://episode/123
```

## 职责

- **跨域统一键**:历史/收藏/播放列表/搜索/链接全部以 ContentRef 为键(I7)。
- **寻址**:ContentRuntime 解析 ContentRef → 对应 CapabilityProvider → 详情/取流。
- **序列化**:URI 字符串形式用于分享、备份、同步。

## 规则

- `sourceId` 对应的插件被禁用/卸载 → 内容**降级显示**(标题/封面保留),数据不删;重新启用即恢复。
- `parentId` 支持层级(episode→series, song→album);历史/续播用 parentId 聚合。
- 深链接解析的终点就是 ContentRef(见 [../services/links.md](../services/links.md))。
