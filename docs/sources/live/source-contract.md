# Live Source Contract

> 直播源要实现**哪些真实接口**,以及一份直播源在 v2 里能保证什么。
> 本文不是接口定义稿:下面每个名字都能在 `pure_live_capability` / `pure_live_platform` 里指到实际声明。
> 通用方法名与实现名的对照表在 [../../contracts/capability-contract.md](../../contracts/capability-contract.md) §5,契约测试的范围在同文 §4。
> 测试侧的断言范围见 [../../development/testing.md](../../development/testing.md):本文只描述已被断言或明确标注为待定义的部分。

## 没有 `LiveCapability` 这个接口

`CapabilityKind.live` 是**路由名**,不是接口:注册表按 kind 筛提供者,而一个直播源实际实现的是这四个方法集 ——

```dart
abstract interface class FeedCapability {
  Future<PageResult<ContentSummary>> feed(PageRequest page);
}

abstract interface class BrowseCapability {
  Future<List<ContentCategory>> categories();
  Future<PageResult<ContentSummary>> browse(ContentQuery query);
  Future<ContentDetail> detail(ContentRef ref);
}

abstract interface class SearchCapability {
  Future<PageResult<ContentSummary>> search(SearchQuery query);
}

abstract interface class ResolveCapability {
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line});
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason);
}
```

已经按这一组建好的源:`providers/huya`(feed/browse/search/resolve)、`providers/douyu`(同集合)。
两者都不是靠一个叫 `LiveCapability` 的接口被识别的,而是靠 `is FeedCapability` 这类判定(见
[capability-contract.md](../../contracts/capability-contract.md) §5)。

## 语义要求

- **取流必须交出带 `expiresAt` 的 `MediaTicket`**(类型就叫 `MediaTicket`,历史文档里写过的
  `StreamTicket` 从未存在)。到期预取与换链在 `integrations/media` 与 `ecosystem/resolver` 那一侧,
  源实现方因此免费得到断流防护;不写 `expiresAt` 等于让宿主无法安排预取(见
  [../../media/media-ticket.md](../../media/media-ticket.md))。
- **失败要能被分类**:错误码走 `PlatformErrorCodes`(未登录/需要登录是 `auth.required` =
  `PlatformErrorCodes.authRequired`,不是某个 `AuthRequired` 异常类)。
- **多线路降级由请求方决定**:`ResolveRequest.allowFallback`(默认 true)。为 false 时首个失败原样上抛,
  不再问后面的候选 —— 播放中换源会连带换掉清晰度与线路承诺。
- **清晰度与线路的选择**用 `SelectionRef` 表达(它是"要哪一路"的名字,不是列表)。
- **弹幕/表情/画质记忆不在这一组接口里**:弹幕是独立 capability(方法集尚未定义,见下一节),
  画质记忆属于偏好(词汇表归 App,见 [../../architecture/application-portfolio.md](../../architecture/application-portfolio.md) §5)。

## 还没有定义的一块:清晰度/线路的**列表**

`CapabilityKind.quality` 与 `CapabilityKind.line` 在枚举里存在,但**没有任何接口能返回一个源有哪些清晰度、
几条线路**:`resolve` 只接受 `SelectionRef`,而调用方无从知道该填什么。
旧文档把这件事写成 `Future<List<QualityLine>> qualities(ContentRef room)` —— 这个签名和它的返回类型
`QualityLine` 在代码里都不存在,所以本文不保留它作为"契约",而是把它记成待定义项:

- 不定形状的原因:真实源给的数据差别很大(douyu 的 `multirates` 是"码率名 + 一个不透明的请求码",
  huya 的线路是 CDN 列表;`rate` 数值排序会把"源"排到低清晰度后面 —— 见 `origin/master` v1 的注释)。
  现在拍一个 `QualityLine` 出来,第一个实现它的 provider 会按自己站点的形状填,方言就固化了。
- 在此之前,源**不要**自造返回类型,也**不要**把清晰度表塞进 `ContentDetail` 的 `extra`:
  等这一步有消费者时一起定(调用点是谁、要什么形状,由那次实现给)。

## 契约测试断言到哪一步

按方法集(Feed/Browse/Search/Resolve)对现有源断言的是:注册表能按 kind 选出提供者、
取流返回的 `MediaTicket` 带 `expiresAt`、`refresh` 换的是同一内容的另一张票、
以及解析超时(见 [../../contracts/platform-contracts.md](../../contracts/platform-contracts.md) §10/§12 与
[../../development/testing.md](../../development/testing.md))。
`quality`/`line` 的列表能力**不在其中**,因为它还没有实现。
