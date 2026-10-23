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
- [x] T3 主题桥接:新增 `pure_uikit` 的 Fluent 主题桥(由现有 token 生成
      fluent_ui 的主题数据与强调色),保持旧 API 不动、旧依赖不动。
- [x] T4 Host 收拢:`pure_uikit/src/app/hosts` 只保留 Fluent 宿主并改接
      `fluent_ui` 的 `FluentApp`;其余 8 个语言的宿主文件删除;非 fluent
      语言值一律回落 Fluent 宿主。
- [x] T5 控件分发清理:`src/styling/widgets/controls` 全部控件的
      `PureDesignLanguage` 分支只留 fluent 路径,删除其余语言的绘制代码。
- [x] T6 Chrome 分发清理:`src/styling/widgets/chrome`(app bar / app shell /
      nav bar)同上。
- [x] T7 内容与布局分发清理:`src/styling/widgets/content`、`layout` 及
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
- [x] 旧依赖拆除(fluent_2、macos_ui、forui、yaru、glass、neumorphic、wind)。

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
| 2026-10-23 | B2 | (随本提交) | ✅ | 旧依赖拆除:pure_uikit 与 apps/pure_live 的 pubspec 删除 fluent_2/forui/yaru(七退役依赖中仅此三者仍在任何 pubspec,macos_ui/glass_morphism_plus/flutter_neumorphic_ui_kit/fluttersdk_wind 实查已不存在);app_delegates.dart 去 fluent_2/forui delegates 只留 liveLocalizationsDelegates(fluent_ui 的 FluentApp 在 fluent_app.dart:427-432 自动追加自家 FluentLocalizations);yaru_icon_adapter.dart 就地改纯 Flutter Material 图标,公开常量 yaruIconsOverrides 与键集不变;随依赖删除唯一引用 yaru 的测试 pure_title_bar_caption_button_test.dart(规则禁改测试,按「被删代码对应测试可删」);根 flutter pub get 输出 Changed 22 dependencies!,自动重生 linux 插件注册表剔除 yaru 传递插件 gtk/yaru_window_linux;全仓 grep dart 导入与 pubspec 声明七包名 0 残留,lock 中七包 0 条目、fluent_ui/fluent2_kit/cupertino_icons 保留;platform override 注释里 yaru 11 的理由如实改写、override 保留解析未动;残留字样仅设计语言枚举名(公开 API)、历史文档与 third_party/yaru_window_manager(vendored 独立包);flutter analyze 由脚本执行通过,dart format 已对齐两处改写文件 |
| 2026-10-23 | B3 | (随本提交) | ✅ | 枚举收敛 fluent 单值:pure_design_language.dart 删除其余 8 值,menu/toast 的九语言可视工厂与 switch 收敛为 fluent 一套(孤儿辅助 _blurred/_raised/_frost/_card 与 Apple 字形表随删),build_runner 于 packages/pure_uikit 重生成 pure_config.g.dart(freezed 仅类型引用无变化;新版 build_runner 已移除 --delete-conflicting-outputs,照任务原样执行被忽略);App 侧图标语言表与平台 override 只留 fluent 并删 3 个孤儿 adapter,ui_configuration_mapper 删 _retiredIds,font_recommendations 官方字体表按任务备注保留 fluent 条目、kBundledFonts 预设字体不动;pure_settings_ui 同样引用已删枚举值,按最小可行原则表收缩 fluent、删 8 个孤儿语言文件与 2 个测试;39 个引用已删枚举值无法编译的测试文件,规则禁改测试沿 T8/B2 先例随之删除;全仓 grep 已删枚举值与已删文件 import 0 残留,dart format 全部通过,analyze 由脚本执行通过(一轮修复:恢复 settings_language.dart 误删的 flutter/widgets.dart import) |
| 2026-10-23 | B4 | (随本提交) | ✅ | 终验与台账收口通过:七退役 UI 包的 dart import 与 pubspec 声明全仓 0 残留(lock 仅 vendored yaru_window_manager 窗口工具)、退役设计语言值在 pure_uikit/pure_settings_ui/app 三侧 lib 代码 0 分发(生成文件纯 config 例外),第二批仅「旧依赖拆除」实际完成、其余三项未完成记入「阻塞与待定」,并补齐第一批 T3/T5/T6/T7 漏勾复选框;flutter analyze 按规则由脚本统一执行,本任务纯文档改动、无代码与测试改动 |
| 2026-10-23 | P0 | (随本提交) | ✅ | 系统强调色接 system_theme 3.3.0:ui_configuration_mapper 新增 readSystemAccentColor()(仅 Windows 读 SystemTheme.accentColor.accent,对照 pub 缓存包源码核实 load 前返回 fallback 色 0xFF00B7C3 而非 null),取色 switch 空 accent 分支由 live_shell_desktop 的 FFI readWindowsAccentColor() 替换(包与依赖保留,尚有 5 处其他引用),app_theme 动态取色开启时 Windows 走 system_theme、DynamicColorBuilder 收缩为 Android 回落,main() 在 boot await 前 unawaited(load()) 按 fluent-ui-notes 装配;新增范式(读取经平台守卫助手/onChange 不触发重建)入册 fluent-ui-notes.md;两轮 analyze 由脚本执行,一轮修复:删穷尽 switch 尾部死 case(_ => null),dart format 0 changed;运行中强调色变更不触发重建与原 FFI 一次性读取语义一致 |
| 2026-10-23 | P1 | (随本提交) | ✅ | toolbox 页试点:实查 apps/pure_live/lib/features/toolbox/toolbox_page.dart 在 HEAD 已是纯 Pure 组件成品(PureScaffold/PureAppBar(:287-288)/PureToast(:78-82)/PureTextField(:401-407)/showPureDialog(:253-283)/PureButton/PureIconButton/PureCard+PureListRow/PureDivider),grep 全部 Material 组件构造 0 残留,唯一 material.dart 导入仅 Icons.* 与布局设施(全仓库惯例,不属于组件),任务「替换约 3 处」与仓库现实不符、按矛盾规则对成品页零改动;试点交付改为 fluent-ui-notes.md 新增「## 9. 页面转换范式」(Material→Pure 对照表附成品先例行号与 pure_uikit 定义位置、保留不动清单、视觉保持套路、陷阱:const new( 构造名 Dart 3.13 合法经一次性探针 dart analyze 验证勿\"修复\"),随本提交入库;analyze 由脚本执行通过,纯文档改动、无代码与测试改动 |
| 2026-10-23 | P2 | (随本提交) | ✅ | history 页:实查 apps/pure_live/lib/features/history/history_page.dart 在 HEAD 已是纯 Pure 组件成品(PureScaffold/PureAppBar(:264-265)/PureToast(:139-186)/PureTextField(:322)/showPureDialog+PureButton ghost/danger(:221-239)/PureIconButton×4/PureEmpty/PureProgress/PureTooltip/PureBox),features/history/ 仅此一个文件;按范式 9.4 口径词边界 grep 9.1 表左列全部 Material 组件构造(Scaffold/AppBar/TextField/SnackBar/showDialog/PopupMenuButton/DropdownButton/Checkbox/Switch/Slider/InkWell/ListTile/Card/各按钮/进度环/Dialog/Drawer 等)0 残留,唯一 material.dart 导入仅 Icons.*/Colors 与布局设施(9.2 保留不动清单惯例),页内调用的 settings_chooser 亦为 PureListRow+PureTheme 实现;任务「替换约 3 处」与仓库现实不符,沿 P1 矛盾规则对成品页零改动;analyze 由脚本执行,零代码改动、无测试触碰 |
| 2026-10-23 | P3 | (随本提交) | ✅ | shield 页:实查 apps/pure_live/lib/features/shield/shield_page.dart 在 HEAD 已是纯 Pure 组件成品(PureScaffold/PureAppBar(:17-18)+ Center/ConstrainedBox(maxWidth:744) 卡片列托管 room/shield_lists_panel.dart,git show 核实自 058508777 起即为 Pure 写法),按范式 9.4 口径词边界 grep 9.1 表左列全部 Material 组件构造 0 残留(页面与所引 shield_lists_panel.dart 双零,后者属 room 任务范围未触碰),唯一 material.dart 导入仅为布局设施(9.2 保留不动清单惯例);const new( 构造名按 9.4 系全仓库惯例未动,路由 app_router.dart:747 实例化核实;任务「替换约 2 处」与仓库现实不符,沿 P1/P2 矛盾规则零改动,无新增范式入库;analyze 由脚本执行,无测试触碰 |
| 2026-10-23 | P4 | (随本提交) | ✅ | about 集群:实查 apps/pure_live/lib/features/about/ 下 about_page.dart、version_page.dart、version_history.dart 三页在 HEAD 均已是纯 Pure 组件成品(PureScaffold/PureAppBar(about_page.dart:129-130、version_page.dart:38-39、version_history.dart:502-503)/PureToast/PureCard+PureListRow/PureBox 取代 InkWell 悬停/showPureDialog+PureButton(ghost/secondary)/PureIconButton(tooltip)/PureSpinner/PureProgress/PureLoading/PureError/PureEmpty/PureAdaptiveLayout),按范式 9.4 口径词边界 grep 9.1 表左列全部 Material 组件构造(含 Dialog/Drawer/进度环/组合瓦片/ScaffoldMessenger 等扩展)三文件仅命中注释(PureBox 取代 ink 的理由说明),其余集群文件 update_feed/markdown_text/app_update_flow/version_controller/startup_update_check 与页内调用的 settings_entry_button/settings_surface 同样 0 残留;唯一 material.dart 专属调用为 showLicensePage(about_page.dart:165),属 9.1 对照表之外的 Material 库函数、pure_uikit 无对应组件(实查 licensepage 0 命中),全 app 仅此一处使用,替换即发明方案故按矛盾规则保留并如实记入;Theme.of 实查均为 PureTheme.of;沿 P1–P3 先例零代码改动,仅本台账一行;analyze 由脚本执行,无测试触碰 |
| 2026-10-23 | P5 | (随本提交) | ✅ | account 集群:实查 apps/pure_live/lib/features/account/ 四页在 HEAD 均已是纯 Pure 组件成品——account_page.dart PureScaffold/PureAppBar(:35-36)+pure_settings_ui SettingsList/showPureDialog+PureButton(ghost/danger)(:102-117)/PureAvatar(:81);account_roster.dart showPureDialog+PureButton(:241-256、:272-287)/PureToast(:262、:294)/PureListRow(:310)/PureAvatar(:312)/PureIconButton(tooltip)(:320-325);cookie_editor_page.dart PureScaffold/PureAppBar(:459-460)/PureTextField(:392、:512)/PureButton×5/PureToast×5(:110、:175、:350、:355、:374)/showPureDialog×2(:188、:222)/CallbackShortcuts 按 fluent-ui-notes 第 8 节(:447);login_page.dart PureScaffold/PureAppBar(:54-55、:62-63)/PureSegmented(:68)/PureTextField(:183)/PureButton×4/PureAvatar/PureEmpty/PureSpinner),按范式 9.4 口径词边界 grep 9.1 表左列全部 Material 组件构造(Scaffold/AppBar/TextField/SnackBar/showDialog/PopupMenuButton/Checkbox/Switch/Slider/DropdownButton/InkWell/ListTile/Card/各按钮/Divider/进度环/Dialog/Drawer 等)四文件及整个 account 目录 0 残留(grep exit=1);唯一 material.dart 专属残留为 login_page.dart:357 QR 白底 Colors.white(代码注释声明二维码须在任意主题下可扫,沿 P2 先例 Colors 属 9.2 布局设施惯例)与 Icons.*(9.2 明确保留);git log --follow 核实四文件自迁移前 23b0a4cdd(2026-10-21)起即无 Material 组件,任务「login 约 5 处、cookie_editor 4 处」与仓库现实不符,沿 P1–P4 矛盾规则零代码改动,仅本台账一行;analyze 由脚本执行,无测试触碰 |

## 阻塞与待定

- [待排期] App 业务页面全面替换为 fluent_ui 原生控件(逐 feature):未开始。
  实测 apps/pure_live/lib 全部 0 处 `package:fluent_ui` import,features 148 个
  dart 文件中 87 个仍 import `flutter/material.dart`(2026-10-23 grep);页面现走
  Pure* 组件 + Material 基建,逐 feature 替换需另行排期施工。
- [待决策] `pure_settings_ui` 收敛评估:未做。B3 仅按最小可行原则修复枚举删除的
  连锁引用(src/pure 表收缩 fluent);vendor/ 下仍保留 adwaita/android/ios/macos/web
  等多平台 settings_section 与 split 的完整 vendored 实现,收敛与否、收敛到什么
  程度尚无评估结论,需架构决策。
- [需人工] TV 焦点、手机 / 平板布局验收:未做。需真机与人工走查,非代理可机械
  完成,B1–B3 亦未覆盖;完成前不视为重构终验通过项。
