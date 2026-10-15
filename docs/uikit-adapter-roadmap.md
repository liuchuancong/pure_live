# live_uikit 适配器家族 · 续作路线图

> 写给接手的人(或 AI 会话):读这一篇 + 要动的那个包的 `live-uikit-*.md`,就能继续推进。
> 核心纪律只有一条:**每个包的 spec md 是契约,代码、README、md 必须同一变更内锁步移动**——
> `tool/check_architecture.ps1` 会机器校验「md §4 目录树 ↔ 磁盘」和「README 原生控件列表 ↔ capabilities」,
> 只改代码不改文档 = 架构门禁直接红。
>
> 现状快照日期:2026-10-15(分支 `v2`,实测各包代码与文档得出)。

## 0. 30 秒架构

- `live_uikit`(core)拥有 token 管线、`LanguageAdapter` 契约、**恰好十个成员**的
  `LiveUiControl`、registry/resolver/诊断,以及 `SharedLanguageAdapter` 这个令牌渲染兜底。
  core 不依赖任何第三方 UI 库(门禁强制)。
- 每个 `live_uikit_<style>` 是一个 adapter 包:`extends SharedLanguageAdapter`,
  只覆盖自家库能原生渲染的控件 + `wrap`;没覆盖的控件落到共享渲染器,resolver 发
  `controlUnsupported` 诊断——**这是有诊断、有测试的正确终态,不是欠账**。
- app 组合根(`apps/pure_live/lib/main.dart`)的 `LanguageRegistry` 注册了 7 个 adapter
  (macos/fluent/neumorphic/glass/wind/cupertino/material);**`forui` 未注册、app 也未依赖**。

## 1. 现状矩阵(实测)

十个契约控件在各 adapter 的原生覆盖(✓=原生,·=共享渲染器 + `controlUnsupported`):

| 控件 | material | fluent | neumorphic | wind | forui | cupertino | macos | glass |
|---|---|---|---|---|---|---|---|---|
| button | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| card | ✓ | ✓ | ✓ | ✓ | ✓ | · | · | ✓ |
| textField | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| switchWidget | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | · | · |
| checkbox | ✓ | ✓ | ✓ | ✓ | ✓ | · | ✓ | · |
| slider | ✓ | ✓ | ✓ | · | · | ✓ | ✓ | · |
| segmented | ✓ | · | · | · | · | · | · | · |
| progress | ✓ | ✓ | · | · | · | · | · | · |
| select | · | ✓ | · | ✓ | · | · | · | · |
| tabBar | · | · | · | · | · | · | · | · |
| **原生数 /10** | 8 | 8 | 6 | 6 | 5 | 4 | 4 | 3 |

规律一眼可见:`tabBar` 全家族共享;`segmented` 只有 material 原生;`select` 只有 fluent/wind。

各包文档完备性:

| 包 | spec md | README/CHANGELOG | 守卫 map | app 注册 |
|---|---|---|---|---|
| 其余 7 个 | ✅ | ✅ | ✅ | ✅ |
| **live_uikit_forui** | ❌ 无 | ❌ 无 | ❌ 未进 `check_architecture.ps1` | ❌ 未注册 |

## 2. 缺口只有四类

接手者先对号入座,别把「已定案的取舍」当欠账,也别把「库没提供控件」当成该自己补的洞。

### A 类:包级硬缺口 —— forui 是唯一一个

`live_uikit_forui` 代码是齐的(adapter/theme/5 个 builder/4 个测试文件都在,
import 前缀 `as forui`),但**整套文档和门禁没跟上**,这是"别人只做了代码"的典型现场:

1. 写 `packages/live_uikit_forui/live-uikit-forui.md` —— 以 fluent 那份为模板(20 节结构),
   §4 目录树**对着磁盘现状写**(16 个文件已在),§7 给出五个原生控件
   (button/card/textField/switch/checkbox)的映射表,其余五个控件记录为 shared 及原因。
2. 补 README(原生控件列表会被门禁拿去和 `foruiUiCapabilities` 对账)和 CHANGELOG。
3. `tool/check_architecture.ps1` 的 adapter→widget-library map 加一条 forui
   (库边界、`as forui` 前缀、registration-only barrel、capability/override 对账)。
4. **注册决策**:要么进 `apps/pure_live` 的 pubspec + `LanguageRegistry`,要么在其 md 里
   明确写下"暂不注册"的理由。别让它悬着。

### B 类:控件提升(先过资格门,再动手)

**资格门(每个包 md §9 的既有规则)**:在 resolved 版本的库里找一个能吃下
`Language*Spec` 全部语义的控件。找不到 → 留在 shared,把理由写进该包 md(照抄
material md 对 select/tabBar 的写法),**结束**。禁止手绘 overlay 冒充原生。

已被 md 定案、**不要碰**的:

- material 的 `select`/`tabBar`:fork 没有 M3 dropdown、`TabBar` 绑死 `TabController`
  生命周期(契约禁止 adapter 持有 caller 状态)——等 fork 提供控件,不是欠账。
- wind 的 `slider`/`segmented`/`progress`/`tabBar`:`fluttersdk_wind` 没有 `WSlider`/
  `WProgress`/裸 tab strip——blocked upstream。
- glass 的 7 个共享控件:库本身控件面就窄,它的价值在毛玻璃表面;提升优先级最低。

**开放候选(按性价比排序)**:

| 顺位 | 包 → 控件 | 依据 |
|---|---|---|
| 1 | cupertino → `segmented`、`checkbox` | Flutter SDK 现成 `CupertinoSlidingSegmentedControl`、`CupertinoCheckbox`;其 md 明说"其余六个留共享直到加原生等价物" |
| 2 | cupertino → `progress`、`select` | `CupertinoActivityIndicator`(仅不定态,需评估 spec 的 fraction 语义)、`CupertinoPicker`(轮式,评估交互语义) |
| 3 | macos → `switch`、`segmented`、`progress`… | 其 md Phase 3 明列六个候选,"仅当产品价值足以支撑才提升" |
| 4 | fluent → `segmented`、`tabBar`;forui → `slider`/`progress`/`select`/`segmented`/`tabBar` | 各自 md 未给不提升的理由,先验证库里有无可吃下 spec 的控件 |
| 5 | neumorphic → 四个共享 | 其 md 标 "✅ (native set)",提升纯看产品价值 |

### C 类:全家族 spec 字段 remainder(一个决策、八包受益)

- button 的 `selected`:**8 个 adapter 全部未映射**(ADR `docs/decisions/0004` 的遗留半边)。
  shared 渲染器用 primary 前景着色;各库都有自己的选中态机制,但没人做。值得立一个
  ADR(0006)统一设计后逐包落地。
- button 的 inline `style`:原生按钮全部不映射(只有 shared renderer 遵守)——各 md 已
  记录为 documented remainder,除非产品点名,不动。
- 各包零散 unmappable 字段(macos 的 `focusNode` on `PushButton`、wind 的 `WInput` 无
  TextStyle 槽等):md §9 已逐条记录,**保持记录,别造假**。

### D 类:横切项(全部包的 Phase 4/5 ◐,性质相同)

1. **app 级风格切换集成测试**:每个包 md §16 都写了"跨 adapter 切换属于应用层"
   (§3.3 禁止 adapter 互依)→ 至今没人写。放 `apps/pure_live`,一个文件遍历 7 个
   已注册 adapter 两两/环形切换,断言 caller-owned 状态(控制器文本、开关值)存活。
2. **硬件验证批次**:键盘遍历、可见焦点环、Android TV D-pad、读屏——headless 半边
   (focusNode 透传、disabled 焊死)各包已测,真机半边全开。安排一次有 Windows/macOS/
   TV 的批次,八个包一起过,顺手勾掉各包 §19 的 `[ ]` 两项。
3. **平台验证矩阵**:各包 "[ ] Platform support claims are backed by actual tests",
   随发版节奏做。
4. **等上游解锁**:glass 的效果预算(`glass_morphism_plus` 需暴露 affordance
   introspection 才能测 `unsupportedEffect`)、core §12 开放半边(adapter 库特效不读
   `canBlur`,等库给旋钮)。
5. **ADR 0005 悬而未决**:两个 `LiveBackground` 的命名归属(core 的样式表面 vs
   `live_uikit_background` 的媒体管线),目前只有 demo 页同时渲染过两者。找个时间定案。

## 3. 续作配方

### 配方一:提升一个控件(锁步清单,一个提交内全做)

1. 资格门(见 B 类):库里有合适控件才继续。
2. 新建 `lib/src/widgets/<lib>_<control>_builder.dart`;复用共享 seam
   (`interactive()` / `buttonLabel()` / `labelled()`);caller-owned 的
   controller/focusNode/回调绝不接管。
3. adapter 加 override;`<lib>UiCapabilities` 同一变更加该控件。
4. 契约测试(`test/adapter/*_contract_test.dart`)的 `native`/`fallback` 两个集合同步移动。
5. `test/widgets/` 用真实 `LiveConfigProvider` + `LiveUiResolver` 走 dispatch 路径断言
   (不是孤立 builder 测试);每个 spec 字段"到屏、或在测试里声明 unmappable"。
6. README 的原生控件列表同步(门禁对账)。
7. 该包 md:§4 树、§7 映射表、Phase 3 小节、§19 checklist 同步(门禁查树↔磁盘)。
8. Definition of Done:

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_<x>
flutter analyze packages/live_uikit_<x>
flutter test packages/live_uikit_<x>
pwsh tool/check_architecture.ps1
```

### 配方二:给没文档的包补 spec(以 forui 为例)

照 fluent md 的 20 节骨架写;§4 树抄磁盘真实现状(含"不要为凑树建空文件"的声明);
§9 给每个原生控件写映射规则 + unmappable 记录;§16 描述已有四个测试目录各自覆盖什么;
§18 Phase 标注真实进度(对 forui:1-3 可标 ✅,4/5 照抄别包的 ◐);§19 checklist
如实勾。写完立刻做 A 类第 3、4 步(守卫 + 注册决策),否则文档立即漂移。

### 配方三:在任意包里找剩余工作

每个包的未完成项都活在 md 的固定标记里,不用猜:

```bash
grep -nE "^- \[ \]|◐|Open:" packages/live_uikit_*/live-uikit-*.md packages/live_uikit/live-uikit.md
```

`✅` = 已完成;`◐` = 半程,跟着小节里的"Open:"走;`[ ]` = 验收未勾。

## 4. 建议顺序

1. **forui 补文档 + 守卫 + 注册决策**(A 类;最便宜,解锁该包一切后续,消灭唯一裸奔包)。
2. **app 级风格切换集成测试**(D-1;7 个 adapter 已全注册,一个文件锁住全家族切换契约)。
3. **cupertino 两连提**(B 类顺位 1;SDK 现成控件,风险最低的原生覆盖增量)。
4. **button `selected` ADR**(C 类;一处设计,八个包的同一缺口一起关)。
5. **macos / fluent / forui 的候选控件按配方一逐个评估提升**。
6. **硬件批次**(D-2)与**平台矩阵**(D-3)随设备/发版节奏。
7. **等上游**:wind 控件、glass affordance、`canBlur` 旋钮、ADR 0005 定案。

## 5. 红线

- 不为凑 §4 树建空文件;模块在功能实现时才建(每份 md 原话)。
- 库没有合适控件 → shared + `controlUnsupported` 是**正确终态**,不是欠账;别手绘 overlay。
- core 不引 UI 库;adapter 互不依赖;业务包不 import 具体风格库;adapter 内 import 一律
  `as <prefix>`(material `mu`、cupertino `cu`、fluent `fluent`、wind `wind`、forui `forui`)。
- `LiveUiControl` 恰好十个成员;加第十一个控件是 core 层变更,不是某个 adapter 的事。
- spec 字段映射不了就记录为 unmappable,不造假、不吞错。
- 每次变更:代码 + capabilities + README + 包 md **一个提交内锁步**;提交前 `git status`
  过一眼,绝不把并行 WIP 混进提交。
