# Collection

> 内容集合:剧集 / 专辑 / 合集 / 频道分组。

```dart
class Collection {
  final ContentRef ref;              // kind: series|album|collection
  final String title;
  final List<ContentRef> children;   // 有序(episode/song)
  final Map<String, Object?> extras; // Provider 自定义(季度/版本)
}
```

## 规则

- 顺序即权威(children 顺序 = 播放顺序);Provider 返回什么顺序就呈现什么顺序。
- 追更/看至第 N 集由 history 基于 children 的 ContentRef 记录(见 [../services/history.md](../services/history.md))。
- Collection 可来源于 Provider 详情解析,也可由用户自建(收藏夹分组);两者同构。
