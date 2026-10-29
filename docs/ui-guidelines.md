# UI 组件与响应式规范

依据：`desen_ui ^0.3.2` 的组件与官方 example 站（本地 `C:\Users\XA-158\Downloads\desen_ui-main\desen_ui-main\example\lib\site`，组合版式重点看 `pages/examples/dashboard_page.dart`、`settings_page.dart`、`sign_in_page.dart`）。数值常量只有一处：`apps/pure_live/lib/shared/layout/window_breakpoints.dart` 的 `LiveWindow`，页面不再写魔法数字。

原则：**先选档位，再选组件，最后写文案**。页面按自身宽度布局，不按平台；同一个窗口可以既是手机又是桌面。

## 1. 三档窗口

| 档位 | 宽度 | 页面怎么排 | 外壳 |
| --- | --- | --- | --- |
| 紧凑 compact | < 600 | 单列；左右 16；工具条拆行；次要动作图标化；表单全宽；浮层是底部 sheet | 手机壳：底部导航（< 768） |
| 中等 medium | 600 – 959 | 单列；左右 20；成对字段可并排（≥ 420）；工具条 ≥ 720 时一行 | 窄桌面窗：侧栏可收缩 |
| 宽 expanded | ≥ 960 | 多列/表格；正文限宽；工具条一行；侧栏常驻 | 桌面壳（侧栏 < 1280 自动折叠一次） |

判定规则：

- 页面用自身 `LayoutBuilder.constraints.maxWidth` 分档，不用整窗宽度猜 pane 宽度。
- 只有整窗级决定才用 `MediaQuery.sizeOf(context).width`：导航形态、feed 的按页/无限滚动（768）。
- 页面留白可按整窗粗判（窗宽 < 600 才收窄），但布局切换必须用 constraints。

## 2. 尺寸常量（LiveWindow）

| 常量 | 值 | 用途 |
| --- | --- | --- |
| `compact` | 600 | 单列/多列分界 |
| `expanded` | 960 | 工具条一行、正文限宽的起点 |
| `toolbar` | 720 | 标签条与动作并排的下限，低于则堆叠 |
| `sheet` | 640 | `DsPanel` 自带：低于为底部 sheet |
| `form` | 480 | 居中表单卡宽度 |
| `pair` | 420 | 成对字段堆叠的分界 |
| `table` | 520 | 表格改堆叠行的分界 |
| `content` | 960 | 设置类列表正文最大宽 |
| `wideContent` | 1240 | 全屏页面正文最大宽 |

间距只用 `DsSpace`：区块 12/16/20/24，行内 6/8/12，页头到内容 8/12。不要出现 10、14 这类未入档的间距。

## 3. 页面骨架

- 每页一个内容滚动区；不要在页面里再套纵向滚动。
- 工具条：
  - expanded：一行。左：平台标签/标题/计数；右：搜索（定宽 200–240）、筛选入口（`DsPopover` + `DsCount`）、主按钮（每页最多一个 `primary`）。
  - compact：两行。第一行标签或视图切换，第二行动作；次要动作（刷新、上限、清空）改成 `DsButton.icon`，必须带 `semanticLabel`/tooltip。
- 页内提示（搜索状态、链接识别、归档提醒）用 `DsAlert`；不要手拼「图标 + 文字 + 按钮」。
- 空态、加载、错误三种状态都要有，分别用 `DsEmptyState`、`DsSkeleton`/`CardGrid(isLoading:)`、`DsEmptyState(icon: cloudOff, actions: retry)`。

## 4. 组件选择

| 用途 | 组件 | 说明 |
| --- | --- | --- |
| 设置/搜索结果/平台列表 | `DsListSection` + `DsListRow` | 行高是 kit 的 listRow（40/48），不要塞封面 |
| 数据表格 | `DsTable` | 只在 expanded；< 520 用行卡片或 `DsListRow` |
| 卡片流/分区墙 | `CardGrid` + `RoomCard` / `AreaCard` | 列数与尺寸由宽度算，不写死列数 |
| 表单 | `DsField` / `DsTextFormField` / `DsSelectFormField` / `DsDateFormField` | 标签、说明、校验都走 kit |
| 选项筛选 | `DsPopover` + `DsCheckbox`/`DsChip`/`DsSwitch` | 常驻筛选行改成头部一个按钮，按钮用 `DsCount` 显示生效条件数 |
| 多字段/长内容浮层 | `DsPanel`（`showDsPanel`） | ≥ 640 侧栏，< 640 底部 sheet；页脚按钮放 `footer` |
| 确认/简短表单 | `DsDialog` / `showDsConfirm` | 破坏性动作 `destructive: true` + `DsButtonVariant.danger` |
| 状态 | `DsBadge` | 有 `icon` 时不再画 dot；深底用 `DsBadgeStyle` |
| 数量 | `DsCount` | 筛选条件数、未读数；给 `semanticLabel` |
| 可选中标签 | `DsChip` | 多选过滤；单选切 view 用 `DsSegmentedControl` |
| 反馈 | `showDsToast` / `DsAlert` / `DsProgressBar` | 动作结果用 toast，页面内说明用 alert |
| 菜单 | `DsMenuAnchor` / `DsMenuItem` | 行内“更多” |

按钮层级：`primary`（每页/每个表单一个）→ `secondary`（普通并列动作）→ `tinted`（有状态，如筛选生效）→ `ghost`（行内、次要）→ `dangerSoft`（列表里的破坏性）→ `danger`（只给确认框主按钮）。

## 5. 表单

- 居中卡片：`LiveWindow.form`（480），`DsCard(padding: s20)`，卡内 `spacing: s20`。
- 字段成对时 ≥ `LiveWindow.pair`（420）并排，否则堆叠。
- 主按钮：登录/工具类全宽，设置类居左；提交中 `loading`，取消用 `ghost`。
- 校验：首次提交前不报错，首次提交后 `AutovalidateMode.onUserInteraction`。
- 表单里不再套面板；长表单直接是页面正文。

## 6. 设置页

- 两级：分类页只放分区行（`DsListRow` + chevron），分区页放设置行；没有页头大标题和说明段。
- 同一项只出现一个入口；开与关是两个状态，不是一个新入口。
- 长内容拆独立页；预览页就是设置本体（预览 + 控件同页）。
- 浮层：桌面弹窗/侧栏，移动端底部 sheet（kit 已按 640 切换）；`formFactor == tv` 单独判断。
- 正文列宽 `LiveWindow.content`（960）；行内控件宽 148–220，超出改为下一行。

## 7. 桌面与移动的差异

| 元素 | 桌面（expanded） | 紧凑（compact） |
| --- | --- | --- |
| 导航 | 常驻侧栏，可折叠 | 底部栏 / 抽屉面板 |
| 工具条 | 一行：标签 + 搜索 + 筛选 + 主按钮 | 两行：标签行、动作行 |
| 筛选 | 头部按钮 → popover | 同左，按钮收成图标 + 计数角标 |
| 排序等次要选择 | 定宽下拉常驻 | 移到标签行下一行或收进图标 |
| 表格 | 完整列，可排序 | 行卡片（标题 + 元信息两行） |
| 卡片网格 | 按宽度算 4–6 列 | 2 列起，随宽度增 |
| 表单 | 可双列，卡居中 | 单列，全宽按钮 |
| 浮层 | 侧栏/弹窗 | 底部 sheet |
| 交互 | hover、focus 环、右键菜单 | 单击、长按菜单；点击目标 ≥ 40 |

## 8. 文案、数字、图标

- 字体只用 `theme.typography`：标题 `title`/`heading`，正文 `body`，辅助 `small`/`caption`，标签 `overline`/`fieldLabel`，数字 `numeric`。
- 长文本 `maxLines + TextOverflow.ellipsis`；数字右对齐时不换行。
- 图标按钮一律 `semanticLabel`；纯装饰图标不给语义。
- 所有可见文案进 slang（`lib/l10n/messages`），不在 widget 里写死中文或英文。

## 9. 可访问性

- 页面标题 `Semantics(header: true)`；动态提示 `announce: true`。
- 浮层打开后焦点进入、关闭后回到触发点（kit 自带）；Escape/系统返回关闭浮层（kit 自带）。
- 颜色只用主题语义色（`colors.text*`、`colors.accent*`、`danger/success.fill`），不写死 RGB。

## 10. 自查清单

- [ ] 360 / 600 / 720 / 960 / 1280 五个宽度各看一遍。
- [ ] 没有溢出：`Row` 里的长内容都有 `Expanded`/`Flexible`，多动作行能换行。
- [ ] 紧凑档：工具条堆叠、次要动作图标化、按钮全宽。
- [ ] 面板在 < 640 是底部 sheet，≥ 640 是侧栏。
- [ ] 空/加载/错误三态齐全，错误能重试。
- [ ] 一页只有一个 `primary`，破坏性动作有确认。
- [ ] 键盘 Tab 顺序、Esc 关闭、焦点返回正常。
- [ ] 文案全部走 l10n，中英都不截断。

## 11. 迁移

- 现存散落断点 560 / 760 / 860 / 900 / 1000 逐步收敛到 600 / 720 / 960；改到某页时顺手替换。
- 页面里的 `MediaQuery.sizeOf(...).width >= 768` 属于整窗决定（feed 分页），可以保留并注明原因。
- 新页面不新增断点数值；确需新数值时先加到 `LiveWindow` 并在此文档登记。

## 12. 落地范围

- 已按本规范统一（断点、留白、通知条）：直播的搜索 / 历史 / 分区 / 工具箱 / 关注 / 录播，VOD 的列表页与播放页，IPTV 的主页 / 导视 / 近期 / 源管理，设置页的分类、分区、搜索结果、字体管理、版本与下载、壁纸预览与设置预览。
- 设置行的控件插槽在 `LiveWindow.sheet` 以下收进下一行；预览类页面的宽窄版式在 `LiveWindow.expanded` 切换。
- 有意的例外：分区 / 热门页的 768（整窗 feed 分页）、直播间播放器内部 560 / 420 的控件排布、重排直播菜单。
- 其他车道正在改的模块（hongguo、music、multiview）不在此轮范围内。
