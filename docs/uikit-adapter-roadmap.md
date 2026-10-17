# live_uikit 适配器家族 · 续作路线图

> 写给接手的人(或 AI 会话):读这一篇 + 要动的那个包的 `live-uikit-*.md`,就能继续推进。
> 核心纪律只有一条:**每个包的 spec md 是契约,代码、README、md 必须同一变更内锁步移动**——
> `tool/check_architecture.ps1` 会机器校验「md §4 目录树 ↔ 磁盘」和「README 原生控件列表 ↔ capabilities」,
> 只改代码不改文档 = 架构门禁直接红。
>
> 现状快照日期:2026-10-17(分支 `v2`)。上一份快照(2026-10-15)写的「十个控件 + 共享 token 基座兜底」
> 已经不存在:那一版路线图里所有 `SharedLanguageAdapter` / `controlUnsupported` / 「提升前先留共享」
> 的规则,现在都换成了「每家自己画完 17 个控件 + 两个结构面」。

## 0. 30 秒架构

- `live_uikit`(core)拥有 token 管线、`LanguageAdapter` 契约、**恰好十七个成员**的 `LiveUiControl`、
  两面(`LiveUiSurface` = `appHost` / `appShell`)、registry/resolver/诊断。
  **core 不画任何一个控件**:它 ship 的只有契约、注册表、解析器、`Live*` 薄派发件和 `LiveBox`/`Style`/
  `DesignToken` 这套零件。core 不依赖任何第三方 UI 库(门禁强制)。
- 每个 `live_uikit_<style>` 是一个 adapter 包:`implements LanguageAdapter`,自己实现全部十七个控件
  + `appHost()` + `shell()` + `wrap()`。自家库有对应件就**映射**,没有就用**那家库自己的零件按那家的视觉拼**。
  没有兜底可落:`LanguageRegistry` 没有 `fallback` 槽,未注册的语言抛 `LiveUiResolutionException`,
  声明了却没覆写抛 `LiveUiCapabilityException`。
- 诊断只剩一种码 `unsupportedEffect`(配置要的效果这台设备做不到,例如毛玻璃)。派发结果不再是可上报的降级。
- app 组合根 [`apps/pure_live/lib/app/adapters/design_language_registry.dart`](../apps/pure_live/lib/app/adapters/design_language_registry.dart)
  注册了**八个** adapter(macos / fluent / forui / neumorphic / glass / wind / cupertino / material)。

## 1. 现状矩阵(实测)

十七控件 + 两面在八家都已实现。每家「映射 vs 拼」的比例如下,**逐控件的具体说法以该包 md 的 §7 表为准**:

| 包 | 映射到库控件 | 用本库零件拼 | 备注 |
|---|---|---|---|
| material | 16 | 1(toast) | 另有禁用态 slider 与本库 assert 拒绝的底栏,由本包画非交互形态 |
| forui | 14 | 3(segmented / tab bar / tab view) | 库十件俱全,拼的三处是形状不合 |
| cupertino | 12 | 5(card / select / toast / tab bar / tab view) | `cupertino_ui` 1.1.2 无 card/select/toast |
| fluent | 12 | 5(segmented / nav bar / tab bar / app bar / tab view) | tab view 用 `AnimatedSwitcher`(4.16.1 无 `Pivot`) |
| macos | 11 | 6(card / tab bar / nav bar / toast / tab view / dialog 动作区) | `macos_ui` 2.2.2 无 card/toast/裸 tab 条 |
| neumorphic | 8 | 9 | 库本体是 `NeuContainer` 主题容器 |
| wind | 6 | 11 | `fluttersdk_wind` 本质是 styling 库 |
| glass | 4 | 13 | `glass_morphism_plus` 只有 container/tile/divider |

两条已经定死的形状规则,别再动摇:

- **`GlassAppBar` 不能拿来画 `appBar`**:它内含 Material `AppBar`,没有 Material localizations 就 assert,
  松约束下占满整窗,`bottom` 只收 `PreferredSizeWidget`。所以 glass 的顶栏是拼的。
- **`macos_ui` 的 `Sidebar`/`SidebarItem` 不是 widget**(没有 `build` 的 descriptor,唯一读者是 `MacosWindow`),
  所以 macos 的 shell 自绘固定宽侧栏 + 真的 `SidebarItems` 填行。grep 到「文件里没有 `of(context)`」不等于它是 widget。

各包文档完备性:八家的 spec md / README / CHANGELOG / 守卫 map / app 注册**全部到位**,没有裸奔包。

## 2. 缺口只有三类

接手者先对号入座,别把「库没提供控件」当成该自己补的洞,也别把「已定案的取舍」当欠账。

### A 类:spec 字段的 remainder(一个决策、八家受益)

- button 的 `selected`:只有 forui 能映射到库自带的选中态(`FButton.selected`);其余各家要么用自己的
  tint 画,要么在 §9 记「本库无对应 affordance」。想统一它,得先立 ADR 定设计,再逐包落地。
- button 的 inline `style`:各家原生按钮普遍不映射(把 caller 的 `Style` 手绘叠在库件上正是红线禁止的做法),
  已逐包记录为 documented remainder;除非产品点名,不动。
- 零散 unmappable(macos `PushButton` 不吃 `focusNode`、wind `WInput` 无 TextStyle 槽、
  `LanguageProgressSpec.showLabel` 在几家无位……):各包 md §9 已逐条记录,**保持记录,别造假**。

### B 类:横切项(全部包的 Phase 4/5 ◐,性质相同)

1. **app 级跨语言切换集成测试**:每个包 md §16 都写了「跨 adapter 切换属于应用层」(§3.3 禁止 adapter 互依),
   `apps/pure_live/test` 目前只有 `platforms/`,**这份测试还没人写**。一个文件遍历八个已注册 adapter
   环形切换,断言 caller-owned 状态(控制器文本、开关值、select 值)存活,并断言切换后
   `host=appHost / shell=appShell` 且诊断 0 条。这是现在最值钱的一个提交。
2. **硬件验证批次**:键盘遍历、可见焦点环、Android TV D-pad、读屏。headless 半边(focusNode 透传、
   disabled 焊死)各家已测,真机半边全开。安排一次有 Windows / macOS / TV 的批次,八家一起过,
   顺手勾掉各包 §19 的两项。
3. **平台验证矩阵**:各包 `[ ] Platform support claims are backed by actual tests`,随发版节奏做。
4. **等上游解锁**:`glass_morphism_plus` 需要暴露 affordance introspection 才能测它的 `unsupportedEffect`;
   core §12 的开放半边(adapter 库特效不读 `canBlur`)同样等库给旋钮。
5. **ADR 0005 悬而未决**:两个 `LiveBackground` 的命名归属(core 的样式表面 vs `live_uikit_background`
   的媒体管线),目前只有 demo 页同时渲染过两者。找个时间定案。

### C 类:契约本身的下一次扩张

- 契约里**没有 `divider`、没有 `menu`、没有 `avatar`/`badge` 的适配器路径**(core 的 `LiveMenu`/`LiveAvatar`/
  `LiveBadge` 是自己渲染的,不走 adapter)。app 侧 `markdown_text` 那类站点想要一条会随语言变的分隔线,
  就得先加第 18 个控件 —— 这是 core 层变更,配方见 §3 配方二。

## 3. 续作配方

### 配方一:改一个已实现的控件(锁步清单,一个提交内全做)

1. 新建/修改 `lib/src/widgets/<lib>_<control>_builder.dart`;caller-owned 的
   controller/focusNode/回调绝不接管。标签行、图标-only、loading 这些约定**每包自己实现**
   (共享 seam 已随地板一起删掉),改一家时顺手对照另几家的同名 builder 看约定有没有漂。
2. adapter 的 override 与 `<lib>Capabilities` / `<lib>Surfaces` 同一变更加减名。
3. 契约测试(`test/adapter/*_contract_test.dart`)断言「声明集合 == `LiveUiControl.values` == 覆写集合」。
4. `test/widgets/` 用真实 `LiveConfigProvider` + `LiveUiResolver` 走 dispatch 路径断言(不是孤立 builder 测试);
   每个 spec 字段「到屏、或在测试里声明 unmappable」。
5. README 的 `Build native …` 清单同步(门禁按词表逐字对账),该包 md 的 §4 树、§7 表、§9、Phase、checklist 同步。
6. Definition of Done:

```powershell
dart format --output=none --set-exit-if-changed packages/live_uikit_<x>
flutter analyze packages/live_uikit_<x>
flutter test packages/live_uikit_<x>
pwsh tool/check_architecture.ps1
```

### 配方二:加一个控件(改契约,八家 + core + 门禁一起动)

1. core:`LiveUiControl` 加成员 + `Language<Control>Spec` + `LanguageAdapter.<control>()`,
   barrel/诊断随之;`UiConfig`/派发件里加对应的 `Live*` 薄派发件。
2. 门禁 `$controlNamesByProse` 加散文词 → 枚举成员的映射(例:`"tab view"="tabView"`),否则 README 全红。
3. 八家各补一个 builder,一家不许漏 —— 漏了就是 `LiveUiCapabilityException`,不是「落到某处」。
4. 八家 README 清单 + §4 树 + §7 表 + 契约测试集合,同一批提交内锁步。

### 配方三:在任意包里找剩余工作

每个包的未完成项都活在 md 的固定标记里,不用猜:

```bash
grep -nE "^- \[ \]|◐|Open:" packages/live_uikit_*/live-uikit-*.md packages/live_uikit/live-uikit.md
```

`✅` = 已完成;`◐` = 半程,跟着小节里的「Open:」走;`[ ]` = 验收未勾。

## 4. 建议顺序

1. **app 级跨语言切换集成测试**(B-1;八家已全注册,一个文件锁住全家族切换契约)。
2. **硬件批次**(B-2)与**平台矩阵**(B-3)随设备/发版节奏。
3. **button `selected` 的 ADR**(A 类;一处设计,七家的同一缺口一起关)。
4. **C 类**要不要加 `divider`/`menu` 进契约,先看产品有没有真需求,别为凑数加成员。
5. **等上游**:wind 控件面、glass affordance、`canBlur` 旋钮、ADR 0005 定案。

## 5. 红线

- 不为凑 §4 树建空文件;模块在功能实现时才建(每份 md 原话)。
- 库没有合适控件 → **用那家库自己的零件按那家的视觉拼**;绝不手绘另一家的形状,
  也不手绘 overlay 冒充原生。「另一种语言的观感」不是可接受的兜底。
- core 不引 UI 库;adapter 互不依赖;业务包不 import 具体风格库;adapter 内 import 一律
  `as <prefix>`(material `mu`、cupertino `cu`、fluent `fluent`、wind `wind`、forui `forui`)。
- `LiveUiControl` 恰好十七个成员,`LiveUiSurface` 恰好两个;再加成员是 core 层变更(配方二),
  不是某个 adapter 的事。
- spec 字段映射不了就记录为 unmappable,不造假、不吞错。
- 每次变更:代码 + capabilities/surfaces + README + 包 md **一个提交内锁步**;提交前 `git status`
  过一眼,绝不把并行 WIP 混进提交。用 `git commit -- <路径>` 时记得**新文件必须先 `git add`**——
  pathspec 提交不会带上未跟踪文件,这个坑已经踩过一次。
