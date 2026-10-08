# pure_live_capability

> 职责:能力契约:Live/Vod/Music/Search/Feed/Auth/Danmaku/Subtitle 等接口与其契约测试断言

| 项 | 规则 |
|---|---|
| 层 | ecosystem(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;契约与模型包是纯 Dart,禁止 Flutter 依赖。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | `lib/pure_live_capability.dart`(能力接口)与 `lib/testing.dart`(契约断言) |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src/capabilities.dart` —— `CapabilityKind` 与有方法集的 `BrowseCapability` / `SearchCapability` /
  `ResolveCapability` / `FeedCapability`、注册时上报的 `CapabilitySet`
- `lib/testing.dart` —— 契约断言(见下)

## 为什么有第二个入口

`testing.dart` 不进主 barrel:源包的测试要跑断言,而生产代码不应看到 `ContractProbe` 这类夹具类型。
它同时也不依赖 `package:test`——断言返回 `List<ContractViolation>` 而不是 `expect()`,所以单测、插件校验 CLI
和设备端自检走同一条代码路径,一次跑完拿到整份违规清单而不是第一个 throw。

## 断言与错误码

规范来自 [capability-contract.md](../../../docs/contracts/capability-contract.md) §3/§4 与
[provider-contract.md](../../../docs/contracts/provider-contract.md) §1:内置源与脚本/Python 源跑同一套。

| 套件 | 码 | 断言 |
|---|---|---|
| declaration | `contract.declaration.missing_interface` | 声明的 kind 必须有对应接口实现 |
| resolve | `contract.resolve.threw` / `uri_scheme` / `protocol_unknown` / `wrong_source_content` / `expiry_before_created` / `expiry_in_past` / `track_uri_scheme` | 取流得到可取、可归属、TTL 如实的 Ticket |
| refresh | `contract.refresh.threw` / `not_fresh` | `expiring`/`expired`/`manual` 三种原因都要能换到新票据 |
| browse | `contract.browse.threw` / `empty` / `page_mismatch` / `page_overflow` / `hasMore_without_items` / `foreign_source` / `blank_title` / `detail_threw` / `detail_ref_mismatch` | 分页回显与请求一致;只报自己的内容;详情与列表同一条 |
| search | `contract.search.threw` / `empty` / `page_mismatch` / `page_overflow` / `foreign_source` / `blank_title` | 同上 |
| feed | `contract.feed.threw` / `empty` / `page_mismatch` / `page_overflow` / `duplicate_ref` / `foreign_source` / `blank_title` | 首页不得同一条出现两次 |

`code` 是对外稳定的键,改动它等于改本入口的契约。

`expiresAt` 的读法:`capability-contract.md` 要求取流"含 expiresAt",而静态 m3u8 本就不过期,因此这里的判定是
**缺失可接受、存在必须自洽且在未来**——谎报 TTL 才是被 Watchdog 兜底的那类故障。

`CapabilityKind` 里没有方法集的 kind(danmaku、epg、auth 等)在声明检查中不产生违规,也不宣称通过;它们随
定义其调用的那一批一起补上断言。

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)
