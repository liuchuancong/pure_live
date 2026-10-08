# MediaItem

> 可播放实体:详情与媒体管线的入口。

## 1. 结构(要点)

```dart
class MediaItem {
  final ContentRef ref;
  final String title;
  final Uri? cover;
  final List<ContentRef>? children;    // 选集/曲目
  final MediaFacts facts;              // 容器/编码/时长等已知事实(避免探测)
  final Set<CapabilityRef> abilities;  // danmaku/subtitle/chapter…
}
```

## 2. 规则

- MediaItem 是 Provider 详情解析的产出;**不包含取流地址**——取流走 `resolve() → MediaTicket`(地址有 TTL,详情常驻)。
- `facts` 尽量由 Provider 声明(容器/编码/直播还是点播),媒体管线按事实决定直连/中继/引擎,不做猜测性探测(承接 v1 取流按事实决定的经验)。
- UI 只消费 MediaItem 与 ContentRef,不感知站点字段(I4)。
