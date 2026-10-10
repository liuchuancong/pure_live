# pure_live_demo

> 职责:In-repo demo live source proving the capability-to-UI chain without any network access

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 + L1 plugin_api(经 host 注入的沙箱桥);同层禁互依;不得触碰 PlayerAdapter(I1/I5)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_demo.dart`;内部实现放 `lib/src/` |

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md`
- `lib/src/demo_source.dart` —— 静态房间数据 + `FeedCapability` 实现

## 验证

- 分析:`dart analyze`(纯 Dart)或 `flutter analyze`(带 `-Flutter`)
- 测试:`dart test`(纯 Dart)或 `flutter test`(带 `-Flutter`)

## 内容(参考实现承担的义务)

- `BrowseCapability` —— `categories()` 由自己那 12 间房算出(去重 + 排序);`browse` 是**真 fixedPage**:
  `pageSize` 夹在 `[1, pageSizeLimit]`、按类别过滤、`hasMore` 说的是"下一页存在吗"、`total` 是过滤后的全数。
- `SearchCapability` —— 标题/副标题/类别/主播名的子串匹配,同样分页;空关键词一个结果都不给(不回全量清单)。
- `FeedCapability` —— 同一批数据以 **singleShot** 出现,且第 2 页明确给空:两种分页形状在同一个源里各留一份样板。
- `ResolveCapability` —— 未知 `ref` / 未知 `quality` / 未知 `line` 一律 `StateError`;选中的档位写进
  `metadata.extra`,票据不声明 `expiresAt`(静态流不会过期,契约里那是"不需要预取"的信号而不是补一个期限)。
  `createdAt` 取注入的 `Clock`。
- `detail` —— 按房间真查(标题/主播/类别进 summary 与 description,类别另作 tag),未知 id 抛而不是编一个"直播间 room-99"。

## 为什么"未知 ref 必须抛"

以前 `resolve` 对任意 `ref.contentId` 都回同一条流,`detail` 给任意 id 编一个标题。fixture 这样写特别有害:
播放器起、诊断说成功、用户点的那间房从来没出现在屏幕上,而**新写 provider 的人抄的就是这个形状**。

## 验证

- 分析:`dart analyze packages/providers/demo`(2026-10-11:0 issue)
- 测试:**无**。行为用仓库外一次性脚本实测:6 个类别、`pageSize=5` 时 p1=5/hasMore=true/total=12、
  p2 首条确实是第 6 间房、"游戏"过滤后 4 条且 hasMore=false、`feed(page=2)` 空且 singleShot、
  票据带上 `quality: 480p` 且 `createdAt` 来自注入时钟、未知房间/未知档位/未知详情三处都抛。脚本已删除。
