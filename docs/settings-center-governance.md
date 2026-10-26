# 设置中心治理（当前规则与验收口径）

本文件是规范 `docs/settings-center-refactor-spec.md` 的**执行侧摘要**：后续编码任务读这一页就够了，
需要判据出处再看规范原文，需要历史与逐条裁定看 `docs/settings-center-restructure.md`。

规范只约束分析方法、决策方式与验收方式，不预设分类；本文件同理——它记录的是**判据**，不是某一天的
页面清单。分类本身可以随功能演进继续调整，调整时按第 4 节的流程走。

## 1. 当前结构事实（随自动任务变动，以门禁输出为准）

- 单一注册表 `SettingsSection`（`features/settings/settings_sections.dart`）+ 模块自有导航
  （`kModuleNavigation`）+ pane 分派 switch（`features/settings/settings_page.dart`）+ 搜索目录
  （`features/settings/settings_search.dart`）。同一结构事实写在四处，`tool/check_settings_ia.ps1`
  负责证明这四处一致。
- 侧栏只列**非可点的分组标题**与**可点的真实页**；没有 index-only 页。子页经 `SettingsChildEntry`
  从父页打开，桌面就地切换、触屏走独立路由。
- 深链兼容用 `aliasTarget`：旧分类/概览页的名字仍可解析，但不再有自己的 pane 与侧栏行。
- 路径只出现在外壳顶部面包屑（设置 › 分组 › 子页），pane 内是标题 + 说明，不再重复大面包屑。
- 设置搜索固定在 pane 顶部，命中分类、子页与**行级**条目。

## 2. 新增一项设置的完成定义

缺任何一项都不算完成（前几轮就是靠这条把「UI-only」和「prefs-only」的假完成挑出来的）：

1. 一个稳定语义的键；同一配置**只有一份**定义与存储值（多页快捷入口允许，见规范 §7）。
2. 真实消费方：改了它，运行期行为必须变。没有消费方就是死开关，不允许进设置面。
3. 归属正确：放进**拥有该业务的那一页**的 pane；确实需要二级对象时才用 `SettingsChildEntry` 开子页。
4. 文案走 slang 中英两份，控件按输入方式自适应（桌面下拉 / 触屏整行单选对话框）。
5. 平台可见性由能力决定（`live_device` 一类），不是由「哪个平台编译得过」决定。
6. 进 `kBackedUpPrefs` 与 `kSettingsProviders`：前者漏了备份会丢值、恢复回不来，后者漏了恢复或跨窗口
   写入后该控制器还抱着旧值。`tool/check_prefs_manifest.ps1` 会直接把这两种漏法判失败。
7. 搜索补一条命中，且必须指向真正承载该行的页。
8. 验收：`dart analyze lib` + 两扇门（第 5 节）。

## 3. 分类与拆并判据（不落固定数量）

- 拆：一页里出现多个互不相干的用户任务；高级参数挡住常用操作；两组配置需要不同的交互或校验；
  生命周期/维护边界不同（规范 §4.2）。
- 合：多页其实在服务同一个用户任务；页面小到没有独立价值；用户必须跨页来回调同一组选项；
  拆分仅仅是旧文件边界造成的（规范 §4.1）。
- 禁止：按条数机械分页、按 Dart 文件复制、一个开关一页、因为 provider 不同就开分类、杂项页、
  用技术名词当分类名、为空功能预留页（规范 §4.3）。
- 归属不清时：查主要用户任务、实际影响范围与依赖；仍有多个合理答案就列利弊选一个，
  **不改语义、不删行为**，把待确认项记进 `docs/settings-center-restructure.md`（规范 §4.4）。

## 4. 改动结构时的流程

1. 只读审计：注册表、菜单、pane、搜索、键的读写点与消费方（规范 §8-A）。
2. 方案 + 每条结构调整的理由，写进 `docs/settings-center-restructure.md`（规范 §8-B）。
3. 一致性自查（规范 §8-C 的清单）。
4. 迁移按风险从低到高：先身份与归属，再拆并页面，再状态与交互，再导航与搜索，再平台可见性，
   最后清理确认无用的旧实现（规范 §8-D）。
5. 复跑第 5 节验收并如实报数。

页面移动**不得**改变键名、默认值、有效范围或既有用户数据；键身份变化属于新的独立决策，要单独评估
兼容与回滚。

## 5. 验收命令（本轮 §10.10 口径：不写测试、不 build、不运行）

```
dart analyze lib                                             # apps/pure_live
powershell -NoProfile -ExecutionPolicy Bypass -File tool/check_prefs_manifest.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tool/check_settings_ia.ps1
```

- `check_prefs_manifest.ps1` = 配置身份：键 / 备份种类 / 失效登记 / 包级归属。豁免必须带一句理由，
  当前唯一豁免是 `recorder.saveDir`（旧 `recorder.dir` 升级而来，机器相关路径不随备份走，
  见 `features/backup/backup_settings.dart` 的注释）。
- `check_settings_ia.ps1` = 四处结构事实一致：分区（每个值是真实行 / 子页 / 别名之一）、别名目标、
  `parentSection` ↔ `settingsChildrenOf` 互逆、页面层级、每页有 pane 分支、别名渲染 canonical 页、
  子页确实由父页的 pane 打开、每页至少一条搜索命中。注意搜索命中的归属用的是「pane 所在文件 + 它 import
  的文件，三层深」的可达集，这正是它检不出「命中被改挂到另一个真实页」的原因（可达集覆盖几乎全部文案键）。
- `tool/audit_settings_disposition.ps1 -Markdown` 生成 `docs/settings-key-disposition.md`：键侧清单
  （类型 / 是否进备份 / 是否在评审清单点名 / 持键文件 / 两侧引用 / 计算键）。它是**证据**，不是门。
- 裸 `-File` 会被未签名脚本策略挡住，必须带 `-ExecutionPolicy Bypass`。
- 编译通过不等于重构成功（规范 §8-E）；按 §10.10 不做运行期核对的部分，交付里必须写明「未验证」。

## 6. 目前无法自动验收的两件事

1. **行级绑定**：哪个控件读写哪个键，在 pane 仍挤在 `settings_page.dart`（本轮实测 3310 行）时查不准。
   按文件归属是恒真的，按「类边界 + 成员名」归属会撞 UI 词汇同名（实测把 `playback.background`
   算进导航页，而那页根本没有静音相关字样）。所以 D2（每页一文件）是 §5「一个配置一个规范定义」与
   §10.3 能被自动检查的**前置条件**，不是整洁性问题；它也修掉了 IA 门「命中改挂到另一个真实页检不出来」
   的无牙案例。实验全过程记在 `docs/settings-center-restructure.md`。
2. **运行期效果**：§10.10 取消 build/run 后，「设置改动真的生效」「备份往返」「既有数据兼容」只能靠代码
   链路审读与门禁覆盖，凡未运行期证实的都按未验证处理。

门禁自身还有一个已知盲区：`check_prefs_manifest.ps1` 只管「读 StoragePrefs 的 provider 必须进
`kSettingsProviders`」。**组件把值直接读进 `State` 字段**没有 provider，恢复与跨窗口重建都检不到它
（实例：`features/iptv/iptv_sources_view.dart` 的 `iptv.sources.order`，低危自愈，见裁定文档）。
新设置若必须由组件直接读盘，要在评审记录里说明它为什么不需要重建信号。

## 7. 仍待确认的产品决策（保留原行为，等裁定）

- **未知设置段名的处置**：`app/routing/app_router.dart:244` 用 `SettingsSection.of(section) ?? SettingsSection.theme`，
  写错的深链会静默显示主题页（本意只是让 13 个别名不 404）。三种候选处置见
  `docs/settings-center-restructure.md` 的「§10.5 移动端兼容审计」；未选其一是因为规范 §9 不允许无依据改行为。
- 全局「恢复默认」的范围：现在只有分作用域的 `resetToDefaults()`（竖屏、竖屏全屏），没有跨模块的全量重置。
- 计算键的边界：每窗口 PiP 几何（`app/providers/pip_geometry.dart`）与 VOD 进度
  `vod.progress.<bvid>`（无上界）是否进备份/清理策略。
- 代理项文案与语义（规范 §2.1 记录的原条）仍以代码现状为准，未擅自改动。

移动端（§10.5 后半句）已按五条可判据审过并全绿：子页触屏走路由、每页可寻址、三处外壳可滚、
44 处选择行都守自适应约定、无 hover-only 入口。注意两条经验：对话框写死的 `DsDialogStyle(width:)`
是**首选宽度**且会自行收窄，不是溢出缺陷；真机像素级表现按 §10.10 不验证，审计只证代码路径。

## 8. 并发与提交纪律（本项目特有，踩过）

- 设置面由 10 分钟自动任务持续逐项同步，`settings_page.dart`、`settings-review-checklist.md`、
  `sync-progress.md` 每轮都可能被改写。要做结构性改动必须先要到「无人写」窗口，不要抢写。
- 门禁/分析报红时先分辨归属：可能是别的路次会话的**在途**改动（2026-10-26 11:12 的 6 个未备份键 +
  9 条 room 报错即是，11:51 复跑已全绿）。不替别人补完、不回滚别人的文件。
- 整轮重构至今未提交（工作区 150+ 未提交文件）。在 §10.10 取消 build 兜底之后，提交是唯一的回滚网。
