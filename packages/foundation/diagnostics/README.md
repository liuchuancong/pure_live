# pure_live_diagnostics

> 职责:崩溃报告、trace 与播放诊断的数据面

| 项 | 规则 |
|---|---|
| 层 | foundation(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | 仅 pub.dev 三方包;L0 各包互不依赖(utils、logging 是人人可用的叶子)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_diagnostics.dart`;内部实现放 `lib/src/` |

## 内容

- `recording.dart` —— `RingBuffer`(定容 + 丢条计数)、`runGuarded`(同步/异步/逃出 zone 的错误都落到同一个 onError)、`measure`(失败也报耗时并原样上抛)
- `metrics.dart` —— `MetricRegistry`:计数器 + 时长摘要( min / mean / p50 / p95 / max / total),**样本窗口与标签数都有上界**(`kMetricSampleLimit` / `kMetricLabelLimit`),越界折叠进 `metric.overflow`;`MetricSummary.isSampled` 明说这份 p95 是从窗口里读的,不是普查
- `failure_ledger.dart` —— `FailureLedger`:按指纹归并(`类型 | 首行数字掩成 # | 第一个非 dart:/非 test 栈帧`),记 firstSeen / lastSeen / count / 首现栈;`perMinute` 分得出"风暴"与"一次性",`record` 在新指纹且账本已满时返回 null 而不是覆盖别人的条目
- `breadcrumbs.dart` —— `BreadcrumbTrail`:用户最近做过什么(有上限 `kBreadcrumbLimit`),**进门时**就 scrub + 截断字段,而不是导出时才想起过滤 —— 带签名 url 的面包屑一旦进了环就已经在内存里了
- `redaction.dart` —— `scrub` / `redactSecrets` + `RedactionRule` 表:凭据形状的赋值(**含 `Bearer <token>` 的多词尾巴**,只遮第一个词等于把凭据留在遮罩后面)、url 的 userinfo、≥32 位的裸 token;多趟直到不再变化;`RedactionReport.appliedRules` 让报告能说清"是被遮了"而不是"本来没有"
- `report.dart` —— `DiagnosticReportBuilder`:**每节预算 + 总预算**双层;超长节保留头 + 尾、砍中间(首行点明失败、末行显示停在哪),并在输出里写出"省略 N 行 / M 字节";第一节永不被丢弃(报告丢了headline错误就不是报告),超总预算时追加一条 `truncated` 节说明丢了几节

这里只有**机制**。要离开设备的诊断词汇(`DiagnosticEvent` / `DiagnosticTrace` / `PlatformErrorInfo`)定义在 `pure_live_platform`;把它们留在 L1,这个 L0 包就不用向上指。

## 结构

- `pubspec.yaml` / `analysis_options.yaml` / `CHANGELOG.md` / `README.md` / `test/` —— 所有包必备
- `lib/src`

## 验证

- 分析:`dart analyze packages/foundation/diagnostics`(2026-10-11:0 issue)
- 测试:`dart test` —— **18 例**全绿(环形缓冲内部、guarded 执行、measure 单调)。
  本轮新增的 metrics / ledger / breadcrumbs / redaction / report **没有单测**;它们的行为是用一份仓库外的一次性脚本跑通后观测的(掩码命中、两次 `timeout after 15ms`/`30ms` 归并成 1 条 x2、面包屑把 `sign=` 遮掉、60 行长节被砍成头+尾并标 `partial=true`),脚本已删除,所以这组观测不可重放。

## 行为契约(2026-10-10 起)

- `RingBuffer` 是真环形:满时移动 head 而不是 `removeAt(0)`(后者每次 add 复制整个尾巴,而这个缓冲区
  在整个会话期内每个诊断事件都要写)。`droppedCount` 非 0 表示"这份视图是残缺的"。
- `measure` 用 `Stopwatch`(单调),不再拿两次 `DateTime.now()` 相减:墙钟会被 NTP 校正、用户改时间、
  唤醒后时区变化往回拨,那时旧实现报出**负时长** —— 面板读成"瞬时",阈值判断读成"可以忽略"。
- `runGuarded` 现在也守护 `onError` 自己:报告器抛异常(诊断文件被锁是常见一种)以前会让调用方
  永远等一个不会完成的 future。现在它照旧返回/抛出,不挂死也不吞掉 body 的原因。

## 未验证

- **唯一消费者是 `ecosystem/extension` 的内存 tracer**;新增的 metrics / ledger / breadcrumbs / redaction / report 五条面
  **一个都没有被调用过**,所以"报告的预算够不够那条上传通道"仍是按常识取的。18 个测试只覆盖机制本身(RingBuffer、
  guarded 执行、measure 单调),新增模块的行为是用一份仓库外的一次性脚本观测的,脚本已删,观测不可重放。
- `redactSecrets` 是模式表,不是解析器:URL-encode 过的 token、拼写变体的字段名、Base64 里不足 32 位的一段
  **遮不住**。加遮罩规则请连样例一起加,不要指望现有三条覆盖未来的字段名。
- `FailureLedger` 的指纹取"第一个非平台栈帧":release 混淆栈里同一个 bug 可能因帧名不同而分裂成几条,真实
  混淆栈上的归并率未测。
- `MetricRegistry` 的滑窗用 `removeAt(0)`(与 `RingBuffer` 的教训相反):`sampleLimit ≤ 256` 时可接受,调大之前
  先换成真环形。
- "诊断真正落到设备上"的路径不在本包内,也未验证。
