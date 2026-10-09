# Agent 任务与验证路由

> 按需读取的执行地图。默认值在 `AGENTS.md`;资源与签名规则只由 `BUILD_POLICY.md` 拥有;Bug 来源判定在
> `MAINTENANCE_POLICY.md`;入站合并评审在 `UPSTREAM_REVIEW_POLICY.md`。同一规则不要在第二处复写一遍 ——
> 复写会让下一次修改只更新其中一份。
>
> 本文件是 v2 重写版:`5a06d9d22` 那次"删除 v1 遗留文档"把它和 `ANDROID_DEVICE_TEST_ROTATION.md` 一起删了,
> 而 `AGENTS.md`、`CLAUDE.md`、`BUILD_POLICY.md`、`MAINTENANCE_POLICY.md` 仍然链接到这里。删掉被引用的文件
> 不等于删掉那条规则,所以按 v2 的实际入口重建。

## 1. 按改动选择证据

| 改动 | 先看什么 | 完成证据 |
| --- | --- | --- |
| 指令、文案、链接 | 改动的文件与被直接引用的地方 | 链接存在性核对、`git diff --check` |
| 工作流/配置/脚本 | 配置本身与调用方 | YAML/PowerShell 语法 + 相关静态策略检查;默认不做真实 dispatch |
| 契约包与模型 | 契约文档与已生成的实现 | 该包的 `dart test`;契约冲突要写进 ADR,不在代码注释里和解 |
| 解析/API 适配 | 真实或已脱敏的响应 + 调用方 | 正/负 fixture 测试;外部探针只在必要时 |
| 播放/会话/录制 | 状态与事件序列、所有权、释放 | 复现 + 相邻的暂停/退出/换源回归;范围内的原生或设备证据 |
| 上游合并 | 冻结的 fork/upstream/base 与全部入站 | `UPSTREAM_REVIEW_POLICY.md` 要求的完整语义评审,再跑受影响回归 |
| 正式发布 | 干净的源提交与已收敛的修复列车 | 全量质量门 + 平台产物/签名/发布核验 |

改动一个被报告或被扫描点名的面之前,先证明它在当前产品里**可达**:找到它的生产调用点、路由、注册或运行时
契约。一个没被引用的 vendored/框架 helper 不会因为静态模式可疑就成为当前缺陷;只有在"清理死代码"确实是本次
任务时才记录或删除它。这条可达性门禁是为了不给应用根本不会执行的代码写测试和修复。

仓库级 Analyze 在当前修复列车的计划内 Dart 修改收敛后跑**一次**。输入未变时复用已通过的检查;只有新修改、
失败、未解除风险或正式交付门禁才值得再跑。验收满足即停止扩大验证,不要为了凑时长安排 soak,也不要把文件扫描
器说成全仓语义评审。

只改了源码、原生验收要留到后面的情况:把待验场景与构建 SHA 原样记下。设备在场不是代码诊断的前提。日志与
历史审计报告是证据,不是当前指令。

## 2. 快速 Issue 通道

在开一次专门调查之前先走这条通道。目的是用每个输入各读一遍就走到第一个判定,并阻止那些改变不了当前产品的活。

1. 冻结 `HEAD`;Issue 正文/评论读一遍,把报告的版本映射到本地 tag。
2. 搜索受影响路径、`tag..HEAD` 提交、确切的测试名与已有报告。按路径取匹配的段落,不要整份载入文档编年史。
3. 把判定记进台账(见下面第 4 节的归属表):
   - `already-fixed`:引用当前提交或测试,然后停下 —— 除非当前输入不同,或被引用的契约已经变了。
   - `present`:先加最小的确定性红测试,修第一个失效状态,跑受影响分组,Dart 修改收敛后再 Analyze 一次。
   - `not-reproduced`:写清缺的是哪个判别量、什么事件会重开调查;不要循环重复等价的探针。
   - 其余分类按 `MAINTENANCE_POLICY.md`。
4. 彼此独立的只读判定合并成一次台账提交;代码修复保持可独立回退,但整批收敛后共享的受影响测试只跑一次。

`already-fixed` 的判定没变时,不再开专项报告、不再往验收叙述里加一段、不跑全量分析、不构建客户端、不重新翻
截图、不开设备会话。当前代码改动、复杂的所有权/数据迁移决策、发布产物,或台账一行装不下的证据,才配得上一次
详细审计。

## 3. 修复列车检查点

1. 维护一份简短的候选清单,先按可达性检查丢掉条目,再开 Flutter 红/绿循环。
2. 每个真实缺陷:加或复用最小的行为回归 → 跑受影响文件 → **立即**提交并推送这个可独立回退的修复。源码同步
   不等最后的候选构建。
3. 同一列车里还有计划内 Dart 修改时,把仓库级 Analyze 标成 pending,而不是每个推送后重跑一次。别把这个中间
   状态描述成"已收敛的质量门"。
4. 计划内源码清单跑完后:一次 `local_ci.ps1 -Scope Focused -Analyze`;再更新紧凑状态归属。Full 和平台候选构建
   只在交付收敛点各跑一次。
5. 之后的业务源码修改只让**输入 SHA 变了**的那部分收敛证据失效:重跑它的受影响测试,在下一个收敛点做一次
   Analyze;不重放未变的测试、构建设备会话。

## 4. 文档归属

只更新信息的拥有者,不要把同一批叙述抄进多个大文件。

| 信息 | 权威归属 | 更新规则 |
| --- | --- | --- |
| 公开功能、安装与使用 | 根 `README.md` | 只在用户可见行为或交付变化时 |
| 文档导航 | `docs/README.md` | 稳定的主题/台账链接,不是每份专项审计 |
| 分层规则与白名单 | `docs/architecture/dependency-rules.md` + `docs/adr/` | 契约或依赖边界变化时,护栏代码随之改 |
| 波形进度、已知欠账、环境注意 | `docs/roadmap/wN-progress.md` | 每波的事实与证据;`## 4. 已知欠账` 就是 v2 的 Issue 台账 |
| 根因/设计/发布证据 | 专项审计或阶段文档 | 台账一行装不下时才写 |

v1 的 `ACCEPTANCE_*`、`ISSUE_TRIAGE_LEDGER_3_2_0.md` 等归属文件随 v1 文档一起删除了;它们的角色由
`docs/roadmap/` 承担。**别再往回引用它们。**

## 5. 本地入口

- `tool/local_ci.ps1 -Scope Focused -TestPath <路径> [-Analyze] [-OfflinePub] [-SkipPubGet] [-RefreshLockfile]`:
  受影响代码的验证。它会在同一次运行里格式化改动的 Dart 文件,所以不要再加一次纯格式化重试。
  `-SkipPubGet` 在依赖清单有变动时会拒绝;那种情况用 `-RefreshLockfile`。
- `tool/local_ci.ps1 -Scope Full`:交付质量门。⚠ **v2 上它还不是可用的门**:`repository_preflight` 的
  `validate_build_policy.ps1` 停在 v1 内容耦合的检查(`plugins/flv_lzc/**`、`lib/modules/**`、`lib/player/**`、
  三个 v1 workflow),后面还跟着 8 个设备邻近脚本与若干 python 门(本机裸 `python` 是坏的,见
  `docs/roadmap/w2-progress.md` §4 第 10 条与其环境注意)。逐条判定属于独立清理任务;在此之前 Full 的失败
  **不作为缺陷证据**,Focused 才是当前入口。
- `dart run tool/check_architecture.dart --strict`:分层护栏;回归用例是 `tool/test_check_architecture.ps1`。
- `dart run tool/check_workflow_yaml.dart`:workflow/action 的 YAML 解析检查。
- `tool/scaffold_package.ps1`:新包唯一入口(AGENTS.md 的项目地图要求)。
- `tool/build_resource_guard.ps1`:质量/构建入口自己会取重型租约;直接手写 Flutter/Dart/Gradle 命令时才显式取,
  不要嵌套租约。
- `tool/prefetch_android_native.ps1`:原生工件必须排在 Flutter `test`/`build` 之前(顺序契约见
  `BUILD_POLICY.md` §3)。

## 6. GitHub 工作流路由

Actions 是显式的兜底/签名设施,本机构建优先。下表只用于**选择已有路径**,不构成 dispatch 许可。

| 路由 | 用途 |
| --- | --- |
| `architecture.yml` | 分层护栏与 packages 分析,每次推送的静态门 |
| `build_pure_live_release.yml` | 手工 dispatch 的全平台发布入口(`workflow_dispatch`,无 stage-tag 触发) |
| `update_releases.yml` | 手工更新发布索引 |

v1 的 `feature-build.yml` / `sign-staged-android.yml` / `publish-*.yml` 等在本分支不存在,不要引用。发布类
自由输入(文本、tag)走环境变量或文件传入,不要拼进 GitHub 表达式再进 `run` 脚本;值先校验,脚本生成发生在
shell 校验之前。

## Model and task handoff

模型与推理档位由运行时控制。Windows 客户端验收里**确实**需要 Computer Use 视觉交互的那部分才用轻量档,
它成本更低但只适合定向 GUI 测试;一批 Windows 验收只建**一个**这样的任务并复用,不要每屏每例各建一个。
这批之外都用常规配置档。Agent/构建文件里没有模型 API 请求设置,往它们里写 API 参数不会改变运行会话的配置。
这一段是唯一策略陈述:常规回复、状态更新和专项审计文档在相关时链接到这里,不复述未变的用量/成本样板。

长任务要留一个简短检查点:当前请求、改过的路径、已经通过的证据、失败与待验收项、下一步动作。用户的新范围
立即生效,之前未提交的工作另行保留。只在缺失的答案会改变结论时才提问,同时继续做不依赖它的、已授权的活。

设备状态、临时的合并冻结、运行中的命令 ID 和既往失败放在检查点或验收记录里,不要写进 AGENTS/skill 默认值。
交接之后,先核对 Git 状态和当前请求,再恢复历史"下一步"。按路径取报告片段,不要反复整份载入历史。异步工具
等返回的 task/session ID;确认上一次结果之后再起替代品。

子代理只在用户或适用规则明确要求的条件下使用。要求委派时只派边界清楚、彼此独立的工作,避免竞争写入,并把
资源/设备门禁保持串行。不搞一律最大 effort、强制委派或重复全量测试。
