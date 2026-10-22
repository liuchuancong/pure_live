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

- [ ] T1 依赖落地:`pure_uikit` 增加 `fluent_ui ^4.17.0`、`fluent2_kit ^2.2.0`,
      工作区 `pub get` 通过,旧依赖暂不拆除。
- [ ] T2 fluent 用法笔记:通读示例仓库,把本工程会用到的关键 API
      (FluentApp / FluentThemeData / NavigationView / Button / ContentDialog /
      Focus 相关)写成 `docs/fluent-ui-notes.md`,给后续所有施工任务当手册。
- [ ] T3 主题桥接:新增 `pure_uikit` 的 Fluent 主题桥(由现有 token 生成
      fluent_ui 的主题数据与强调色),保持旧 API 不动、旧依赖不动。
- [ ] T4 Host 收拢:`pure_uikit/src/app/hosts` 只保留 Fluent 宿主并改接
      `fluent_ui` 的 `FluentApp`;其余 8 个语言的宿主文件删除;非 fluent
      语言值一律回落 Fluent 宿主。
- [ ] T5 控件分发清理:`src/styling/widgets/controls` 全部控件的
      `PureDesignLanguage` 分支只留 fluent 路径,删除其余语言的绘制代码。
- [ ] T6 Chrome 分发清理:`src/styling/widgets/chrome`(app bar / app shell /
      nav bar)同上。
- [ ] T7 内容与布局分发清理:`src/styling/widgets/content`、`layout` 及
      `src/adaptive` 中残留的语言分发同上。
- [ ] T8 图标收敛:`src/icons` 删除按语言变化的图标主题与尺寸表,只保留
      Fluent 一套;`PureIcon` 注册机制不变。
- [ ] T9 外观页接线:App 外观设置里的「设计语言」选择项移除,配置固定为
      fluent;相关 l10n 键保留(避免连锁改动)。

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

## 阻塞与待定

(暂无)
