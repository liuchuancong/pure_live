# Flutter 公共模块审查与改进路线图

> 基于 `packages/` 实测清单整理  
> 日期：2026-10-10  
> 目标：减少悬空模块、稳定公共契约、明确多 App 边界，按模块逐个交付。

## 1. 总体结论

当前最主要的问题不是公共包数量不足，而是部分模块尚未形成“稳定契约—可靠实现—自动化测试—真实消费者”的闭环。

建议保留现有分层，不推倒重来；暂停无明确消费者的新包建设，优先修复契约、依赖方向、数据正确性和生命周期。

核心原则：

- 不要为了让消费者数量好看而强行把插件/TVBox 栈接回 `pure_live`。
- 接口与实现分离，但不为分离而分离；简单工具不必独立成包。
- App 是装配层，负责依赖注入、路由、页面和功能组合，不应承载底层协议与运行时实现。
- 零消费者不自动等于删除；先判断公共契约是否稳定、归属是否明确、未来宿主是否确定。
- 每次只推进一个边界清楚的模块：先审查，再确定最小修改范围，补测试，最后接入真实消费者。

## 2. 建议的依赖方向

| 层级 | 职责 | 示例 |
|---|---|---|
| L6 Applications | 依赖装配、路由、页面和功能组合 | `pure_live`、`pure_tvbox`、`pure_music` |
| L5 Providers & Features | 源适配与具体场景能力 | `providers/huya`、`providers/iptv`、`features/live`、`features/vod` |
| L4 Application Services | 跨页面/场景的业务服务 | `favorites`、`history`、`playlist`、`search`、`feed` |
| L3 Ecosystem Contracts | 平台统一模型、能力、权限、扩展与解析契约 | `platform`、`capability`、`resolver`、`identity`、`plugin_api` |
| L0–L0.5 Foundation & Integrations | 通用基础设施和外部 SDK 适配 | `utils`、`network`、`storage`、`files`、`cache`、`media`、`firebase` |
| 横切 UI | 设计令牌、可复用组件和自适应风格 | `ui/design`、`ui/ui_kit`、`ui/adaptive` |

> 层级编号是逻辑依赖方向，不要求为了编号重命名目录。UI 是横切层，由 App 组合使用。

## 3. 第一批必须审查的模块

### 3.1 `platform` — P0

这是全平台的契约中心，其他包的模型最终都会受到它影响。

- 去除重复模型，明确 `ContentRef`、`MediaTicket`、`ResolverDescriptor`、分页与错误模型的唯一权威定义。
- 统一稳定标识符、序列化、可空字段、取消语义和向后兼容策略。
- 公共模型避免直接暴露 Flutter、Dio、Firebase 或具体播放器类型。
- 暂时不要继续扩充模型数量，先解决跨包形状不一致。

### 3.2 `network` — P0

建议封装成熟的 Dio，但不要把网络包变成业务 API 集合，也不要再造一套与 Dio 完全重复的拦截器和请求 DSL。

- 统一 Dio 客户端、拦截器、超时、取消、响应转换与错误映射。
- 明确 Cookie、Header、代理、凭据与插件网络权限的隔离规则。
- 只对安全且允许重试的操作重试，不默认重放所有 POST。
- 覆盖上传、下载、流式响应、大响应体、并发取消和日志脱敏。
- 测试超时、DNS/连接失败、HTTP 错误、解析失败及取消后的状态。

### 3.3 `permission` / `extension` / `plugin_api` / `plugin_host` — P0

- **Permission**：权限策略、授权记录、请求检查和撤销。
- **Extension Gateway**：面向宿主提供统一的扩展调用入口。
- **Plugin Host / Runtime**：插件发现、加载、启动、停止、隔离和资源释放。
- `plugin_api` 定义插件与宿主之间的契约；`plugin_host` 负责管理插件；`js_runtime`、`python_runtime` 负责各自语言的执行环境。
- 测试未经授权的网络请求、Cookie 越权、插件间状态泄漏、超时后任务残留，以及权限变更是否及时生效。
- 如果 ADR 已经确定插件归属 `pure_tvbox` / `pure_music`，应遵守既定边界，不为消费者统计而装配回 `pure_live`。

### 3.4 `storage` / `files` / `cache` — P0

三个模块应形成清晰的职责边界：

- `storage`：结构化数据、键值存储、迁移和底层支持的事务语义。
- `files`：文件路径、命名、原子写入、替换和文件系统操作。
- `cache`：可丢弃数据的缓存策略、容量限制、过期、淘汰和清理。

重点检查：

- 损坏数据是否会被静默覆盖。
- 并发写入是否会丢数据。
- 迁移中断后能否恢复。
- 缓存是否有容量上限和明确失效策略。
- 文件清理是否可能越出应用管理目录。

`files` 和 `cache` 当前零消费者，不等于它们应该被删除。先确认它们是否有独立、稳定的公共契约；如果只是几组工具函数，则不必为了形式单独维护 package。

### 3.5 `media` / `features/live` / `features/vod` — P0

先统一播放生命周期，再继续加功能。

- `media`：播放内核适配、会话、能力、媒体轨道、播放事件和恢复机制。
- `features/live`：直播业务状态、线路切换和直播场景策略。
- `features/vod`：选集导航、观看进度和点播业务状态。

明确谁拥有播放会话、谁决定换源、谁负责重试、谁记录播放历史。不要让 `features/live` 再造一套播放器状态，也不要让 `media` 直接依赖页面或直播业务。

优先补齐状态一致性、取消与释放、恢复路径测试，不要新增第二套播放控制中心。

## 4. 现有模块处理清单

| 模块 | 建议 | 具体行动 |
|---|---|---|
| `utils` | 保留 | 维持叶子依赖；只放纯工具，避免业务模型渗入 |
| `logging` | 补强 | 结构化日志、敏感字段脱敏、日志级别与输出端边界 |
| `network` | 优先重审 | 统一 Dio 请求生命周期、错误、取消、隔离与重试 |
| `storage` | 优先重审 | 审查迁移、损坏恢复、并发和数据一致性 |
| `files` | 条件保留 | 确认原子写入与路径能力是否构成稳定公共面 |
| `cache` | 条件保留 | 定义容量、过期、淘汰、失效和并发行为 |
| `events` | 缩小定位 | 只服务真正的广播事件；命令、查询和强类型业务交互优先用接口 |
| `diagnostics` | 补强 | 加入关联 ID、错误记录、脱敏和有界存储 |
| `auth` | 延后接入 | 明确凭据存储、会话状态、刷新与注销；按真实认证需求接入 |
| `backup` | 补强 | 定义版本化清单、校验、恢复预览、冲突处理和部分失败策略 |
| `sync` | 暂不扩张 | 确定消费者与后端契约后，补游标、幂等、冲突解决与断点恢复 |
| `l10n` | 补齐接入 | 明确语言资源加载与回退规则，再由 App 连接 Flutter 本地化 |
| `platform_info` | 保留 | 只提供平台能力与运行环境信息，不塞业务判断 |
| `release` | 保留 | 补充版本比较、更新源错误和下载校验测试 |
| `firebase` | 收敛边界 | 负责 Firebase 初始化和 SDK 适配，不承担整个业务服务层 |
| `platform` | 第一优先级 | 消除重复模型，稳定标识符、错误、分页和序列化 |
| `capability` | 补强 | 规范能力发现、能力声明与实际执行能力不一致的处理 |
| `permission` | 优先重审 | 收敛授权模型、检查入口、撤销与审计 |
| `task` | 优先重审 | 规范任务状态机、取消、调度、重试、幂等与持久化边界 |
| `extension` | 拆分职责 | 分离内置源装载与扩展调用网关 |
| `resolver` | 补强 | 统一解析优先级、超时、取消、候选结果和失败原因 |
| `identity` | 有消费者再深化 | 先定义跨源匹配规则、置信度和人工纠正机制 |
| `plugin_api` | 稳定契约 | 明确插件版本、能力、生命周期和宿主兼容策略 |
| `plugin_host` | 延后宿主装配 | 明确安装、升级、回滚、卸载和运行状态 |
| `js_runtime` | 条件保留 | 明确 JS 引擎、执行限制、超时与资源清理 |
| `external_tvbox` | 迁移归属 | 按既定决策归入 `pure_tvbox`，再确定是否保留共享协议包 |
| `python_runtime` | 延后 | 确认 Python 运行方式、平台覆盖、隔离及发布体积 |
| `services/favorites` | 保留 | 补数据迁移、排序、去重和并发写测试 |
| `services/history` | 补齐调用闭环 | 确定 `record`、`finish`、`flush` 的触发时机、去重和退出处理 |
| `services/playlist` | 保留 | 补顺序、批量操作、持久化与导入导出测试 |
| `services/search` | 补强 | 明确超时、失败隔离、取消、部分结果和排序规则 |
| `services/feed` | 优先修形状 | 统一跨源分页与继续加载语义，不要只靠 UI 拼接分节 |
| `ui/design` | 扩充但有边界 | 令牌化颜色、排版、间距、圆角、尺寸、动效与层级 |
| `ui/ui_kit` | 真实接入 | 从一两个稳定组件开始，不一次性重写全 App |
| `ui/adaptive` | 保留 | 明确不同风格的能力差异和降级策略 |
| `ui/lyric` | 延后 | 等 `pure_music` 的歌词模型和播放进度接口稳定 |
| `ui/player_ui` | 延后 | 等房间页和播放会话契约稳定后再装配 |

## 5. Features 与 Providers 的建议

| 模块 | 建议 | 优先补齐 |
|---|---|---|
| `features/settings` | 优先接入 | App 声明偏好键；默认值、校验、迁移、重置、导入导出和变更通知 |
| `features/live` | 优先补齐契约 | 直播会话、线路选择、播放状态同步、切源失败恢复 |
| `features/vod` | 先稳定接口 | 选集导航、进度记录、续播、进度合并规则 |
| `features/music` | 延后到 `pure_music` | 队列、播放模式、队列持久化与播放状态 |
| `features/iptv` | 先明确与 `providers/iptv` 的分工 | 频道切换、EPG 时间窗口；XMLTV 解析属于 provider |
| `features/search` | 先修数据正确性 | 缓存过期、损坏数据处理、版本兼容、原子写入 |
| `features/home` | 保持轻量 | 首页布局和聚合策略；不重复实现搜索、Feed 服务 |
| `features/account` | 等身份需求确定 | 站点账号、凭据引用、授权状态；避免明文 Cookie 进入普通偏好 |
| `features/backup` | 重新明确职责 | 业务层协调备份内容与策略；底层 `backup` 负责格式、校验、读写和恢复 |
| `features/recorder` | 先定义录制契约 | 录制任务、目标文件、进度、取消、失败恢复和平台限制 |
| `providers/huya` | 保留 | 反签名测试、接口变更容错、直播和点播能力声明 |
| `providers/bilibili` | 按需求扩展 | 当前明确只有 VOD；直播能力应独立实现和声明，不要虚报能力 |
| `providers/demo` | 保留 | 离线开发、测试数据和异常场景模拟 |
| `providers/iptv` | 补文档并装配 | 源格式、频道模型、播放 URL、XMLTV 解析、时区与节目匹配 |
| `providers/music` | 等 `pure_music` | 脚本接口、加解密、错误映射和实际源适配 |
| `providers/douyu` | 删除空壳或补真实实现 | 没有近期实现计划，不要保留空 barrel 冒充可用 provider |

### Provider 与 Feature 的边界

- `providers/iptv`：负责读取 IPTV 源、解析 M3U/XMLTV、提供频道和节目数据。
- `features/iptv`：负责频道切换、频道列表业务状态、EPG 时间窗口和场景协调。
- `services/favorites`：负责收藏数据的通用管理。
- `media`：负责真正的媒体播放。

音乐和直播也遵循相同原则。Provider 提供能力，Feature 组织业务，Service 提供跨场景业务能力，App 负责装配。

## 6. 值得补齐的能力（优先补现有模块）

### 6.1 测试支持

不一定要新增生产环境公共包，可以先统一测试工具：

- 可控时钟、假网络、假存储、假任务调度器。
- 可复用的契约测试。
- 数据损坏、超时、取消、并发冲突、恢复和部分失败场景。
- Provider、Resolver、Storage、Runtime 的一致性测试。

先放在测试目录或开发依赖中；只有多包确实需要复用时才独立成 `test_support` package。

### 6.2 配置与凭据

- 普通设置交给 `features/settings` 与 `storage`。
- 敏感数据通过受保护的凭据存储接口管理。
- 加密实现依据平台真实安全存储能力；Base64 或普通文件混淆不构成安全存储。
- 不要把明文 Cookie、令牌或私有密钥存入普通偏好设置。

### 6.3 可观测性

先统一 `logging`、`diagnostics` 和 `platform` 的诊断模型：

- 请求、任务、解析和播放操作的关联 ID。
- 结构化错误与可重试标记。
- 有界日志、脱敏、导出与清理。
- 诊断数据的访问权限控制。

等确实需要多种日志输出端、指标采集或远程诊断后，再考虑独立 `observability` 包。

### 6.4 App Composition / Bootstrap

每个 App 在自身入口组合 Provider、Resolver、Service 和 Runtime，明确初始化与关闭顺序、测试替换和资源释放。

暂不必创建共享 `composition` package；先观察多个 App 是否出现稳定重复机制。

### 6.5 UI 设计令牌

扩充 `ui/design` 的颜色、排版、字号、字重、行高、尺寸、边框、阴影、层级和动效令牌。

区分布局尺寸、屏幕适配和用户字体缩放；重点验证 TV 720p 与字体放大后的溢出情况。

## 7. 暂时不要新增的包

- 万能 `common` / `shared` / `core` 包：容易使依赖方向变成不可控的网状结构。
- 单纯重复 Dio 的 `http` 包：没有实质收益时不要再包一层。
- 独立业务 `event_bus`：先定义现有 `events` 的广播边界。
- 大而全 `repository` 包：Repository 应属于明确的业务或数据边界。
- `database` 大包：等确实需要关系数据库、事务或复杂查询后再引入。
- 第二套插件框架或播放器抽象：先稳定 `plugin_api` 与 `media`。
- 大型 `analytics` 包：先把日志和诊断做好。

## 8. 包名与目录命名决策

当前四个包名不符合“目录短名 ↔ 包名一一对应”的规则。建议先决定统一规则，再批量迁移，避免各自修补。

| 当前目录 | 当前包名 | 建议方向 |
|---|---|---|
| `features/backup` | `pure_live_backup_feature` | 目录改为 `features/webdav_backup`，包名 `pure_live_webdav_backup` |
| `features/search` | `pure_live_search_feature` | 目录改为 `features/search_history`，包名 `pure_live_search_history` |
| `features/iptv` | `pure_live_iptv_feature` | 先明确层前缀规则，避免与 `providers/iptv` 冲突 |
| `features/music` | `pure_live_music_feature` | 若归属 `pure_music`，考虑目录/包名明确体现归属，不沿用 `pure_live` 前缀 |

如果所有 Workspace 包统一使用 `pure_live_` 前缀，应把它定义为技术性前缀，而不是 App 归属标识。

重命名时同步更新 `pubspec.yaml`、导入路径、Workspace 注册、依赖白名单、代码生成配置和架构检查脚本，再运行 `dart pub get` 与严格架构检查。

## 9. `pubspec.yaml` description 修正模板

### `providers/iptv`

> Provides IPTV playlist and EPG data-source capabilities, including playlist parsing, channel metadata, XMLTV program parsing, and channel-to-program matching. Does not own UI state, playback sessions, or user preferences.

### `features/settings`

> Provides typed application preference definitions, validation, namespaced persistence, migrations, import/export, and preference change notifications. Does not own UI widgets or platform-specific settings screens.

### `ui/design`

> Provides shared design tokens for colors, typography, spacing, radii, component dimensions, elevation, and motion. Does not own application-specific pages or business logic.

### `ui/ui_kit`

> Provides reusable Flutter UI components, including notices, dialogs, loading indicators, poster cards, and status views. Does not own application routing or feature-specific state.

### `providers/music`

> Provides music-source integration contracts and script support, including source adaptation and script cryptographic utilities. Does not own the music playback queue, player lifecycle, or application-level music state.

其他模块也按这个格式写：说明包的职责、提供的能力，以及明确不负责的事情。不要仅因为实现了几百行代码，就宣称整个业务已经完整可用。

## 10. 分阶段实施顺序

### 阶段 1：稳定底层契约

`platform` → `utils` / `logging` → `network` → `storage` / `files` / `cache`

完成模型去重、错误分类、请求生命周期、存储一致性和单元测试。

### 阶段 2：稳定平台机制

`capability` → `permission` → `task` → `resolver` → `identity`

先完成接口和契约测试，再实现真实消费者。尤其是 `identity`，在跨源匹配规则尚未明确之前，不必急着扩展。

### 阶段 3：补齐业务闭环

`features/settings` → `services/favorites` / `history` / `playlist` → `services/search` / `feed` → `features/live` / `vod`

让每个模块至少有一个真实消费者，并补上状态流、异常路径和持久化测试。

### 阶段 4：恢复扩展与多 App 生态

`extension` → `plugin_api` / `plugin_host` → `js_runtime` / `python_runtime` → `external_tvbox`

按既定 ADR 将插件与 TVBox 能力装配到正确的 App，而不是为了满足消费者统计而装配回 `pure_live`。

### 阶段 5：完善 UI 与发布能力

`ui/design` → `ui/ui_kit` → `ui/adaptive` → `ui/player_ui` / `ui/lyric`

同步补齐 `backup`、`sync`、`release`、`diagnostics` 的集成测试与文档。

> 这些阶段不必严格串行：某模块依赖的契约稳定且测试通过后，即可独立推进。

## 11. 模块验收标准

- [ ] **边界与依赖：** 职责单一，依赖方向正确，没有未经批准的跨层引用。
- [ ] **公共 API：** barrel 只导出稳定 API，不意外泄露实现细节。
- [ ] **错误与生命周期：** 错误可分类，异步任务可取消，资源可可靠释放。
- [ ] **并发与恢复：** 明确幂等性、重试策略、部分失败和数据恢复行为。
- [ ] **自动化测试：** 覆盖正常路径、异常路径、边界、并发和回归场景。
- [ ] **真实消费者：** 有明确消费场景；未接入时有记录的归属和接入计划。
- [ ] **文档与发布：** description 准确，README、示例和兼容性说明完整。

## 12. 当前建议立即执行的六项任务

1. **审查 `platform`：** 统一模型和公共契约。
2. **重审 `network`、`storage`、`files`、`cache`：** 提高基础设施可靠性。
3. **梳理 `permission`、`extension`、`plugin_api`、`plugin_host`：** 分清权限、网关与宿主。
4. **统一 `media`、`features/live`、`features/vod` 的播放生命周期和恢复责任。**
5. **修复 `features/search` 的缓存正确性；接入 `features/settings` 与 history 记录闭环。**
6. **统一包名、description、架构护栏与测试验收规范。**

## 最终原则

你一个一个模块自己写是合理的方向。每次只推进一个边界清楚的模块，先审查现有实现，再确定最小修改范围、补测试，最后接入真实消费者。

比起一次性新增大量 package，这种方式更容易控制质量，也更不容易推翻已有成果。

## 13. 首周可执行计划（7 天）

### 首周目标

首周结束时应交付以下成果：

- 一份完整的公共包审查台账，记录每个包的状态、风险、消费者和后续动作。
- 一套可以重复运行的架构检查与格式检查命令。
- 完成 `platform` 的公共 API、重复模型和依赖方向审查。
- 完成 `network` 的 Dio 封装审查，至少覆盖核心请求、错误映射和取消行为。
- 确定下一批 `storage`、`files`、`cache` 的整改任务。
- 所有修改可通过测试、静态分析和 Git 差异审查。

**首周不追求所有包都整改完成，重点是建立可靠的模块交付方式，并完成两个关键模块的第一轮闭环。**

### Day 1：建立审查基线

**目标：掌握现状，冻结不必要的架构变动。**

执行步骤：

1. 检查 Workspace 配置和所有公共包的 `pubspec.yaml`。
2. 汇总每个包的目录、包名、依赖、导出 API、测试文件和实际消费者。
3. 检查包之间的依赖方向，找出循环依赖和未经批准的跨层引用。
4. 检查未使用的包、空壳包、重复模型、失真的 `description`。
5. 建立风险清单，不立即删除或重命名任何包。
6. 确认当前分支可以正常执行基础检查，并记录已有失败项。

建议创建以下文档：

```text
docs/architecture/
├── package-inventory.md
├── dependency-rules.md
├── package-review-log.md
└── first-week-plan.md
```

`package-inventory.md` 建议至少包含：

| 字段 | 说明 |
|---|---|
| Package | 包名及目录 |
| Layer | 所属逻辑层 |
| Responsibility | 唯一主要职责 |
| Consumers | 实际消费者 |
| Public API | 对外稳定 API |
| Dependencies | 直接依赖 |
| Tests | 现有测试覆盖 |
| Status | 当前状态 |
| Next Action | 下一项可执行任务 |

状态统一使用：

- `stable`：边界明确，测试足够。
- `needs-review`：需要审查，尚未确认问题。
- `needs-fix`：已确认缺陷。
- `blocked`：被其他契约或决策阻塞。
- `deprecated`：已决定淘汰，等待迁移。

**当天验收：** 所有公共包都有台账记录；已知问题与本次新增问题分开记录；没有为了清单好看而删除包或更改架构。

### Day 2：审查 `platform`

**目标：确认跨包公共模型只有一个权威定义。**

执行步骤：

1. 逐个检查 `platform` 导出的模型和类型。
2. 搜索其他包中同义、近似或重复的模型。
3. 对照真实消费者，确定每个公共类型的唯一所有者。
4. 审查 `ContentRef`、`MediaTicket`、`ResolverDescriptor`、分页、错误和标识符模型。
5. 检查序列化、空值处理、字段默认值和向后兼容性。
6. 确认公共模型没有不必要地依赖 Flutter、Dio、Firebase 或具体播放器实现。
7. 为关键模型补充正常数据、异常数据和兼容性测试。

建议的审查记录：

```text
Model:
Current Owner:
Duplicate Definitions:
Consumers:
Serialization:
Compatibility:
Required Changes:
Tests:
```

执行原则：

- 不要先批量重命名。
- 不要一次性改变所有调用方。
- 如果需要破坏性修改，先确定迁移方案和兼容策略。
- 不确定某个模型是否重复时，先记录为待确认，不直接删除。

**当天验收：** 形成公共模型清单、重复模型清单和迁移顺序；关键契约具有对应测试。

### Day 3：建立架构护栏并收敛 `platform`

**目标：让架构规则可检查，而不只存在于文档中。**

执行步骤：

1. 明确允许的依赖方向。
2. 确定哪些底层包禁止依赖 Flutter UI、具体 App 和上层业务包。
3. 确定公共 API 导出规范和包命名规范。
4. 将稳定的规则写入现有架构检查脚本。
5. 对 `platform` 的整改逐项执行测试和静态分析。
6. 审查全部差异，确认没有顺手重构无关模块。

建议至少检查：

- 底层包不能依赖 App。
- `platform` 不依赖具体 Provider、Feature 或播放器。
- 禁止循环依赖。
- 新增公共模型必须有明确所有者。
- 公共导出不得无意暴露内部实现。

具体脚本应优先复用仓库现有工具；只有现有工具无法覆盖时才增加新脚本。

**当天验收：** `platform` 第一轮整改合并或提交；架构规则可以重复执行；已知基线问题不会被误认为本次回归。

### Day 4：审查 `network` 的设计与调用边界

**目标：明确所有网络调用应该如何创建、执行、取消和处理错误。**

执行步骤：

1. 找出项目中的 Dio 实例和直接 `Dio()` 创建点。
2. 统计拦截器、超时、Header、Cookie、代理和凭据的配置方式。
3. 检查是否存在重复的请求封装或绕过统一客户端的调用。
4. 定义网络层公共错误模型和异常转换规则。
5. 明确取消令牌的所有权与请求生命周期。
6. 检查日志是否可能输出 Cookie、Token、认证 Header 或敏感查询参数。
7. 记录重试策略，明确哪些请求允许重试。

建议形成一张请求策略表：

| 场景 | 必须明确的行为 |
|---|---|
| 连接超时 | 错误类型与是否允许重试 |
| 响应超时 | 错误映射与调用方处理 |
| 主动取消 | 不误报为普通网络故障 |
| HTTP 4xx | 业务错误与鉴权错误的区分 |
| HTTP 5xx | 是否重试及重试上限 |
| JSON 解析失败 | 明确解析错误，不静默吞掉 |
| 上传/下载 | 进度、取消、临时文件清理 |
| 流式响应 | 连接释放与异常终止 |
| Cookie/Token | 隔离、传递规则与日志脱敏 |

**当天验收：** 完成网络调用清单、统一客户端方案和错误分类表；没有未经审查就全局替换请求调用。

### Day 5：补齐 `network` 核心测试

**目标：让网络封装具有可验证的行为契约。**

至少完成以下测试：

- [ ] 请求成功和 JSON 解析。
- [ ] HTTP 错误映射。
- [ ] 连接或响应超时。
- [ ] 主动取消请求。
- [ ] Header 和 Cookie 隔离。
- [ ] 敏感信息脱敏。
- [ ] 安全重试策略。
- [ ] 上传或下载的取消与清理（若该能力已实现）。
- [ ] 流式响应异常结束与资源释放（若该能力已实现）。

执行步骤：

1. 优先使用现有 Dio 测试适配器或仓库已有测试设施。
2. 对每个失败场景检查错误类型是否稳定。
3. 确认取消后没有继续更新已经失效的业务状态。
4. 检查测试是否依赖真实网络；基础契约测试应尽可能离线运行。
5. 修复本次确认的问题，不顺带重构所有 Provider。

**当天验收：** 核心网络测试可以重复运行；失败能定位到具体契约；取消、超时和敏感信息处理具有明确预期。

### Day 6：预审 `storage`、`files`、`cache`

**目标：准备第二周工作，不在一天内强行完成三包重构。**

分别检查：

#### `storage`

- 数据模型和持久化格式是否有版本。
- 迁移失败是否保留可恢复数据。
- 并发更新是否存在丢失写入。
- 损坏数据是否会被静默重置。
- 清理、重置和注销操作是否有明确语义。

#### `files`

- 路径拼接是否可能越出允许目录。
- 原子写入与替换是否可靠。
- 临时文件是否在失败后清理。
- 文件重命名和覆盖的行为是否明确。
- 不同平台的路径和权限差异是否经过验证。

#### `cache`

- 是否有最大容量和过期规则。
- 淘汰策略是否确定。
- 缓存失效和主动清理是否可靠。
- 并发写入是否可能覆盖新数据。
- 缓存损坏时是否能安全重建。

为每个模块记录：

```text
Confirmed Issues:
Potential Risks:
Consumers:
Existing Tests:
Required Contract:
Minimal Fix:
Acceptance Criteria:
```

**当天验收：** 形成三个模块各自的 P0/P1 问题清单，并确定下一周的执行顺序。

### Day 7：集成验证与首周复盘

**目标：确认本周的修改形成闭环。**

执行步骤：

1. 对本周修改过的包运行格式检查、静态分析和测试。
2. 运行 Workspace 级依赖检查与架构检查。
3. 检查所有公共 API 变更是否同步更新调用方和文档。
4. 查看 Git 差异，移除无关格式化、无关重命名和临时调试代码。
5. 将未解决问题标记为 `blocked` 或 `needs-fix`，明确阻塞原因。
6. 输出下一周任务清单，避免下一周重新盘点同一批问题。

建议的最终检查：

```bash
dart format --output=none --set-exit-if-changed .
dart analyze
```

以上命令需在仓库根目录并结合实际 Workspace 配置使用。如果项目使用 Melos 或自定义脚本，应优先运行仓库现有的全包检查命令，避免仅检查根包而遗漏 Workspace 成员。

**当天验收：**

- [ ] `platform` 完成第一轮审查与整改。
- [ ] `network` 完成边界审查和核心测试。
- [ ] 架构规则已文档化并尽可能自动化。
- [ ] `storage`、`files`、`cache` 已有明确整改清单。
- [ ] 本周改动通过适用的格式、静态分析和测试检查。
- [ ] 未完成事项有责任模块、阻塞原因和下一步动作。

---

## 14. 首周任务优先级与时间分配

| 优先级 | 任务 | 预计投入 | 完成标准 |
|---|---|---:|---|
| P0 | 建立包台账与依赖基线 | 0.5–1 天 | 每个包有明确状态与下一步 |
| P0 | `platform` 模型和 API 审查 | 1–1.5 天 | 模型所有权与重复项明确 |
| P0 | 架构护栏 | 0.5 天 | 关键依赖规则可以重复检查 |
| P0 | `network` 边界审查 | 1 天 | 客户端、错误、取消和凭据策略明确 |
| P0 | `network` 核心测试 | 1 天 | 核心错误路径与取消有测试 |
| P1 | `storage` / `files` / `cache` 预审 | 0.5–1 天 | 下一轮任务可以直接开始 |
| P1 | 集成验证和复盘 | 0.5 天 | 有测试结果与第二周计划 |

时间只是建议，不应为赶进度跳过数据迁移、兼容性或安全性检查。

## 15. 第二周的预定方向

首周结束后，根据实际审查结果调整，不预先承诺大规模重构。

建议顺序：

1. 完成 `storage`、`files`、`cache` 的高风险修复。
2. 审查 `capability`、`permission`、`task` 的状态与权限契约。
3. 审查 `resolver` 的候选、失败、超时和取消语义。
4. 接入 `features/settings`，明确偏好设置的存储和迁移。
5. 修复 `features/search` 缓存，并打通 `services/history` 的记录闭环。
6. 再决定插件栈和 UI 包的后续推进顺序。

**首周的成功标准不是完成了多少个包，而是后续每个包都能用相同的方式审查、修改、验证和交付。**