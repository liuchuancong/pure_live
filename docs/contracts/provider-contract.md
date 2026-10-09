# Provider 契约

> Provider 是 Plugin 内 capability 的具体实现载体;内容链上最接近站点协议的一层。

## 1. 规则

1. Provider 只产出 `ContentRef / ContentItem / MediaTicket`,不触碰播放器(I1)、不持有 UI(I4)、不直接写业务存储(历史/收藏由 services 经 ContentRef 完成)。
2. Provider 的网络必须经统一 network 底座(风控头/UA/日志/代理一致);JS Provider 只能走 PluginNetwork。
3. Provider 必须实现 `resolve() / refresh()`,并如实给出 `expiresAt`——谎报 TTL 会被 Watchdog 的 403/中断检测兜底,但体验差。
4. Provider 之间禁止互相依赖;同站多 capability(live+vod)共享底层实现但不得交叉 import 内部。
5. Provider 必须通过对应 Capability 的契约测试 + 提供 fixtures(真实响应录制)。

## 2. 生命周期

```text
load → init(context: HostBridge) → [resolve/refresh/browse/search/…] → dispose
```

`HostBridge` 提供的能力:PluginNetwork、kv 存储(命名空间隔离)、cookie 访问(需权限)、事件发布。Provider 不得越过 HostBridge 访问宿主。

## 3. 注册与发现

Provider 由 PluginRegistry 装载、CapabilityRegistry 按 capability 索引;查询方(搜索/Feed/首页)永远通过 CapabilityRegistry 发现 Provider 列表,不硬编码源(见 [../services/search.md](../services/search.md)、[../services/feed.md](../services/feed.md))。

> 实现落点:`packages/ecosystem/capability/lib/src/capability_registry.dart`(注册/覆盖/按扩展注销)。
> 声明面走 `providersFor(kind)`,要发调用的一方用 `implementations<T>()` —— 两个视图的分工与理由见
> [包 README](../../packages/ecosystem/capability/README.md) 与 [../roadmap/w4-progress.md](../roadmap/w4-progress.md) §1。

## 4. 参考

第一个参考 Provider:Bilibili(同时覆盖 Live/VOD/Search/Feed/Danmaku/Auth/Subtitle,最大程度验证契约,见 [../roadmap/v2-roadmap.md](../roadmap/v2-roadmap.md) W4;协议词典:pure_live_TV `lib/modules/vod`)。
