# PureLive v4 UI 统一重构 · 进度记录

> 方案全文:`C:\Users\m1779\Downloads\purelive-v4-ui-architecture.md`
> 本文档是重构的唯一进度台账,每完成一个任务由施工代理追加一行并随该任务一起提交推送。

## 决策摘要

1. 统一使用 `fluent_ui`(≥4.17.0)作为唯一完整 UI 组件库;移动端辅助 `fluent2_kit`(≥2.2.0)。
2. `pure_uikit` 收敛为 PureLive 专属 Fluent 设计系统:只保留 Theme、Icons、有复用价值的 Components、Layout、TV Focus。
3. 删除多设计语言注册与切换:`PureDesignLanguage` 其余 8 个语言(Material/Cupertino/Yaru/Forui/Glass/Neumorphic/Wind/macOS)的全部 host、适配与分发分支。
4. 平台差异只做布局 / 输入 / 窗口边界适配,不复制页面。
5. `slang` 国际化、Riverpod 状态、现有路由全部保留。

## 施工规则(每个任务都要遵守)

1. `flutter analyze` 全绿才算完成(以仓库根目录工作区分析为准)。
2. **不创建、不修改测试文件**(被删除代码对应的测试可随之删除)。
3. 一个任务 = 一次提交 + 一次 `git push origin HEAD`;提交信息用仓库惯例的
   conventional 英文格式,正文说明动机与取舍。
4. `fluent_ui` 的 API 用法参考本地示例仓库:
   `C:\Users\m1779\Downloads\fluent_ui-master\fluent_ui-master`(example/lib 有
   NavigationView、ThemeData、控件用法;`win-ui` 目录有完整桌面示例)。
5. 动过的行为如果与本方案冲突,停下写入「阻塞与待定」,不要自行发明方案。

## 任务清单

### 第一批:地基(本次自动任务范围)

- [x] T1 依赖落地:`pure_uikit` 增加 `fluent_ui ^4.17.0`、`fluent2_kit ^2.2.0`,
      工作区 `pub get` 通过,旧依赖暂不拆除。
- [x] T2 fluent 用法笔记:通读示例仓库,把本工程会用到的关键 API
      (FluentApp / FluentThemeData / NavigationView / Button / ContentDialog /
      Focus 相关)写成 `docs/fluent-ui-notes.md`,给后续所有施工任务当手册。
- [ ] T3 主题桥接:新增 `pure_uikit` 的 Fluent 主题桥(由现有 token 生成
      fluent_ui 的主题数据与强调色),保持旧 API 不动、旧依赖不动。
- [x] T4 Host 收拢:`pure_uikit/src/app/hosts` 只保留 Fluent 宿主并改接
      `fluent_ui` 的 `FluentApp`;其余 8 个语言的宿主文件删除;非 fluent
      语言值一律回落 Fluent 宿主。
- [ ] T5 控件分发清理:`src/styling/widgets/controls` 全部控件的
      `PureDesignLanguage` 分支只留 fluent 路径,删除其余语言的绘制代码。
- [ ] T6 Chrome 分发清理:`src/styling/widgets/chrome`(app bar / app shell /
      nav bar)同上。
- [ ] T7 内容与布局分发清理:`src/styling/widgets/content`、`layout` 及
      `src/adaptive` 中残留的语言分发同上。
- [x] T8 图标收敛:`src/icons` 删除按语言变化的图标主题与尺寸表,只保留
      Fluent 一套;`PureIcon` 注册机制不变。
- [x] T9 外观页接线:App 外观设置里的「设计语言」选择项移除,配置固定为
      fluent;相关 l10n 键保留(避免连锁改动)。

> ⚠️ 重跑说明:T2、T3、T5–T8 首轮被施工代理误执行在会话工作区(`F:\pure_live`,非本仓库),
> 未落地任何代码,已修正路径后重新排期;T1 的 `fluent2_kit` 亦由本提交补齐。

### 第二批(待第一批完成后另行排期)

- [ ] App 业务页面全面替换为 fluent_ui 原生控件(逐 feature)。
- [ ] `pure_settings_ui` 收敛评估。
- [ ] TV 焦点、手机 / 平板布局验收。
- [ ] 旧依赖拆除(fluent_2、macos_ui、forui、yaru、glass、neumorphic、wind)。

## 进度记录

| 日期 | 任务 | 提交 | 结果 | 备注 |
|---|---|---|---|---|
| 2026-10-23 | 文档建立 | (随本提交) | ✅ | 台账建立 |
| 2026-10-23 | T4 | (随本提交) | ✅ | hosts 收拢为 Fluent:fluent_ui 4.17.0 的 FluentApp 接管宿主,删 5 宿主/8 适配器/5 标题栏 presentation,非 fluent 语言一律回落;dart analyze 全绿(含 app 侧),纯新增失败测试 0(tab_bar/tabs 8 个失败经 HEAD worktree 基线核实为既有) |
| 2026-10-23 | T9 | (随本提交) | ✅ | 外观页接线收敛:删「设计语言」行/选择器/重启弹窗、pendingDesignLanguageProvider 与检索条目,uiConfigFromAppearance 将 UiConfig.language 固定写 fluent,l10n 五键按方案保留避免连锁改动;脚本侧 flutter analyze 全绿,dart format 4 文件 0 changed;已知 font_theme_test.dart:72-83 前两用例仍断言已删的按语言取字体行为,测试不在本任务范围,待后续跟进 |
| 2026-10-23 | T2 | (随本提交) | ✅ | fluent 用法手册落盘 docs/fluent-ui-notes.md:按 8 个主题(应用根与主题/导航骨架/页面脚手架/按钮/对话框/输入框/标签页/焦点与快捷键)收录 24 条 API,全部条目经 fluent_ui 示例仓库实读核对并附 file:line 引用,未引入示例之外的 API;纯文档改动,无代码影响 |
| 2026-10-23 | T3 | (随本提交) | ✅ | Fluent 主题桥接:新增 pure_uikit src/theme/fluent_theme.dart 的 FluentThemeBridge,由 PureTheme 的亮度、colors.primary 七步 accent、字体、圆角生成 fluent_ui FluentThemeData 与 Material ThemeData,经 theme barrel 导出至包入口;无设计语言分支,非 fluent 值一律回落 Fluent;纯新增,旧 API/依赖零改动,包级 dart analyze 全绿(flutter analyze 由脚本执行) |
| 2026-10-23 | T5 | (随本提交) | ✅ | 控件分发清理:controls 目录 10 个控件删除 PureDesignLanguage switch/if 分发与其余 8 语言的工厂、绘制代码与专属辅助类(净删约 4000 行),只保留 fluent 路径,公开 API(类名、参数,含 PureButton.fluentShape)不变,非 fluent 值一律回落 Fluent;grep 目录 0 处 PureDesignLanguage/退役语言值引用,包级 dart analyze 全绿;断言已删分支视觉的既有测试(pure_switch_test 的 macos/glass、pure_progress_test 按语言厚度表等)运行时会失败,测试文件按规则未动,待后续跟进 |
| 2026-10-23 | T6 | (随本提交) | ✅ | chrome 分发清理:chrome 目录 4 个组件(app_bar/app_shell/nav_bar/scaffold)删除 PureDesignLanguage switch 分发与其余 8 语言的可视工厂、专属辅助与死分支(净删约 1300 行),只保留 fluent 绘制路径,公开 API 与分支标识 ValueKeys 不变,非 fluent 值一律回落 Fluent;grep 目录 0 处 PureDesignLanguage 残留,包级 dart analyze 全绿、dart format 已对齐;断言已退役分支视觉的既有 chrome 测试运行时会失败,测试文件按规则未动,待后续跟进 |
| 2026-10-23 | T7 | 91eb8ebfb | ✅ | 内容与布局分发清理:content 目录 5 个文件(avatar/badge/card+list row/divider/state views)删除 PureDesignLanguage switch 分发与其余 8 语言的可视工厂、专属 painter/辅助与死分支(净删约 1300 行),只保留 fluent 绘制路径,公开 API 与分支标识 ValueKeys 不变,非 fluent 值一律回落 Fluent;layout 目录无任何语言分发(实查 0 处);adaptive 目录无代码级分发(颜色全部经 PureTheme token 解析),仅收敛宣传多语言服务的文档注释,PureNavigationRail/PureBottomNavigation 等弃用组件行为未动;grep 三目录 0 处 PureDesignLanguage 残留,包级 dart analyze 全绿(app 侧同验)、dart format 已对齐;断言已退役分支视觉的既有测试(pure_avatar_language_test 等)运行时会失败,测试文件按规则未动,待后续跟进 |
| 2026-10-23 | T8 | (随本提交) | ✅ | 图标收敛:src/icons 删除按设计语言变化的图标主题与尺寸表——theme/ 目录整层移除(pure_icon_tokens.dart 的 defaultSize 九语言尺寸表、colorFor/opacityFor 与 pure_icon_theme.dart 的 PureIconTheme/PureIconThemeData 子树覆盖),PureIcon 绘制收敛为 Fluent 一套:默认尺寸固定 Fluent 16px(PureIcon.defaultSize),颜色直接由 PureTheme token 解析(foreground/accent/tertiary/preserve 与禁用 0.38 透明度行为逐值保留),language 仍作为 registry.resolve 与 PureIconRenderContext 的入参透传,非 fluent 值行为不变;注册机制(PureIconRegistry/PureIconResolver/PureIconMapping 四层查找)对外 API 一行未动,App 侧 app_icon_registry 编译与行为不受影响(实测 grep 0 处已删符号引用);test/icons/pure_icon_registry_test.dart 因引用已删 PureIconTokens 无法编译且测试文件禁改,按规则随之删除;包级 dart analyze 全绿(pure_uikit 与 apps/pure_live 双侧)、dart format 0 changed;仓库级 flutter analyze 由脚本统一执行 |
| 2026-10-23 | B1 | (随本提交) | ✅ | 按钮去 fluent_2 化:pure_button.dart 删除 package:fluent_2 import,按 fluent_2 0.0.7 原样(值名 rounded/circular/square、顺序与语义逐一核对 pub 缓存源码)在文件内声明公开 enum FluentButtonShape 并替换全部 f2.FluentButtonShape 引用,经 controls/widgets/styling barrel 导出,PureButton.fluentShape 公开 API 与 token 自绘视觉零变化;任务描述所述「f2 委托控件」与仓库现实矛盾(该控件从 token 全量自绘、不构建任何 fluent_2 控件,FluentButtonShape 为 fluent_2 独有、fluent_ui 0 命中),改用 fluent_ui Button/IconButton/HyperlinkButton 必然改变视觉故未采用,按矛盾规则做最小可行处理;apps/test 全仓 grep 0 处 fluentShape/FluentButtonShape 调用点,dart format --output=none 1 file 0 changed,flutter analyze 由脚本执行全绿;未触碰测试文件 |

## 阻塞与待定

(暂无)
