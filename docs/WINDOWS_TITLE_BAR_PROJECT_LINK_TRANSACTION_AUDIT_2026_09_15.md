# Windows 标题栏项目链接可访问性与打开事务审计（2026-09-15）

## 范围与结论

本批复核 Windows 自定义标题栏左侧的图标、应用名和窗口尺寸区域。基线为 `44bbb17afe9193cb81525d0e68c68f858b46f3b9`，实现提交为 `a21492bf842c1d02154d5c51d69f0ee9fbe30bc3`。

旧区域直接使用无名称 `InkWell`：点击后先 `canLaunchUrl`、再以默认模式 `launchUrl`，探测与实际打开分成两次平台调用。返回 false 和异常都没有界面反馈，同一区域快速重复输入还可并发启动多个浏览器任务。固定 32 px 标题栏也没有收束超长应用名、大字号和实时尺寸文本，窄窗口下存在溢出风险。

`a21492bf` 抽出有状态 `TitleBarProjectLink`，以本地化“项目主页”同时作为链接语义与 Tooltip；Material `InkWell` 提供 Tab 焦点、Enter/Space 激活、悬停/按压反馈与可见焦点边框。打开动作只调用一次明确的 `LaunchMode.externalApplication`，执行期间禁用输入；false 和异常均显示既有双语浏览器反馈，完成后恢复重试。内容由 32 px 高的 `FittedBox.scaleDown` 收束，超长应用名、64 px 字号和尺寸文本在 120 px 宽测试夹具内保持可见命中且不溢出。

## 状态合同

1. 标题栏应用区域公开为具名链接，而不是仅由内部图片或应用名偶然生成语义。
2. Tooltip、辅助技术名称和项目主页含义共享既有 `project_page` 本地化键。
3. Tab/Shift+Tab 可聚焦，Enter 与 Space 均沿同一打开入口执行；焦点显示明确边框。
4. 项目 URI 只传给一次外部应用打开调用，消除 `canLaunchUrl` 与 `launchUrl` 间的状态窗口。
5. 等待期间点击回调为 null、语义状态为 disabled，同一区域的重复输入不并发启动浏览器。
6. 平台返回 false 与抛出异常都显示 `external_browser_not_opened`，异常同时保留诊断栈。
7. 成功、false 或异常结束后均释放等待态，下一次点击保持可重试。
8. 32 px 高度保持；长名称、大字号和尺寸读数整体按可用宽高向下缩放，不产生横向或纵向溢出。
9. 项目 URI 仍来自 `VersionUtil.projectUrl`，未改变当前分支的权威项目地址。

## 有效红灯

- `local-artifacts/build-records/20260914T233349843Z-quality-focused.json`：旧源码合同 **0 PASS / 1 FAIL**。失败稳定锁定标题栏仍是无独立语义/事务所有权的旧 `InkWell`，且缺少外部应用模式、等待期禁用和失败反馈。

## 最终验证

- 新专项 `test/windows_title_bar_project_link_test.dart`：**5/5 PASS**，覆盖源码所有权、链接语义、Tab 焦点与可见边框、Enter/Space 激活、精确 URI、重复打开串行、false/异常反馈、失败后重试，以及 120×32 / 64 px 长文本布局。
- 联合最终：`local-artifacts/build-records/20260914T234203856Z-quality-focused.json`，覆盖 8 个相关测试文件，合计 **45/45 PASS**。
- 最后一次 Dart 编辑后的全库 analyze：`No issues found`（26.0 秒）。
- Dart 格式化、构建策略静态检查、仓库完整性审计与 `git diff --check` 通过；最终仓库审计 `local-artifacts/repository-audits/20260914T234103567Z-focused.json` 为 0 error、2 warning。

## 验收边界与下一步

- 本批增加 W1-01 的标题栏链接、布局与浏览器事务证据，该组继续保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批未构建 Windows 候选、启动原生 GUI 或操作 Android 设备；Astra Light 使用 0 次。
- 后续累计候选需验证鼠标悬停/Tooltip、Tab/Shift+Tab/Enter/Space、项目主页实际在系统默认浏览器打开，以及启动失败反馈和立即重试。
- 还需在 400 px 最小窗口、不同 DPI、系统文字缩放和拖动标题栏场景验证链接命中与窗口拖动互不抢占；源码与 Widget 门禁不替代真实浏览器和窗口管理器证据。
