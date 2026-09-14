# Windows 标题栏控制按钮可访问性与动作事务审计（2026-09-15）

## 范围与结论

本批复核 Windows 自定义标题栏的最小化、最大化/还原与关闭按钮。基线为 `9f40c413f8dd9dd06aa1606a21707bd1245176db`，实现提交为 `0e654db82631b02fa9222ff8dab7d707cf28f933`。

旧 `WindowControlButton` 由 `MouseRegion`、`GestureDetector` 和单个图标组成，三个系统动作没有可见提示、可访问名称、键盘焦点或焦点指示。回调类型还是同步 `VoidCallback`，调用原生窗口 Future 时既不等待也不拥有异常；同一按钮快速重复触发可并发派发原生动作，失败后没有界面反馈。

`0e654db8` 为三个动作增加中英文名称，并以 `Semantics` 和 `Tooltip` 向辅助技术、鼠标与触控板公开相同动作。按钮改由 Material `InkWell` 接管 Tab 焦点、Enter/Space 激活、悬停和按压状态，焦点使用可见边框。每个按钮用 `_runAction` 持有异步动作：执行期间语义与点击入口同步禁用，重复触发合并为一次；异常被记录并显示本地化 SnackBar，事务结束后恢复入口以支持重试。

## 状态合同

1. 最小化、最大化/还原和关闭均有本地化可访问名称，Tooltip 与语义标签共享同一文本。
2. 三个按钮进入正常桌面焦点顺序，并支持标准 Material 键盘激活。
3. 焦点、悬停和按压均有视觉状态；键盘焦点额外显示高对比边框。
4. 回调统一为 `Future<void> Function()`，按钮等待原生动作结束后才重新开放。
5. 同一按钮等待期间 `onTap` 为 null、语义状态为 disabled，快速重复输入不产生并发原生调用。
6. 原生动作异常在按钮事务内收口，显示本地化反馈且不形成框架未处理异常。
7. 成功或失败都在 finally 中释放等待态；失败后的下一次操作仍可正常执行。
8. 既有最小化、最大化/还原和关闭业务回调保持原样，改动只建立输入与异步所有权。

## 有效红灯

- `local-artifacts/build-records/20260914T153652084Z-quality-focused.json`：旧源码合同 **0 PASS / 1 FAIL**。失败稳定锁定生产控件缺少 `semanticLabel`、Tooltip、异步 `_runAction` 与等待期禁用合同。

## 最终验证

- 新专项 `test/windows_title_bar_control_test.dart`：**5/5 PASS**，覆盖生产源码/本地化消费、双语键存在、语义名称、Tab 焦点与焦点边框、Enter 激活、重复异步动作串行、等待期禁用、异常反馈及失败后重试。
- 联合最终：`local-artifacts/build-records/20260914T232918215Z-quality-focused.json`，覆盖 10 个相关测试文件，合计 **62/62 PASS**。
- 最后一次 Dart 编辑后的全库 analyze：`No issues found`（33.8 秒）。
- Dart 格式化、翻译 JSON 解析、构建策略静态检查、仓库完整性审计与 `git diff --check` 通过；最终仓库审计 `local-artifacts/repository-audits/20260914T232805476Z-focused.json` 为 0 error、2 warning。

## 验收边界与下一步

- 本批增加 W1-01 的标题栏输入与异常确定性证据，该组继续保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批未构建 Windows 候选、启动原生 GUI 或操作 Android 设备；Astra Light 使用 0 次。
- 后续累计候选需用鼠标验证悬停、按压和 Tooltip，用 Tab/Shift+Tab/Enter/Space 验证焦点顺序与激活，并验证最小化、最大化、还原及关闭确认链。
- 还需覆盖快速重复输入、原生动作失败反馈、不同 DPI 和窄窗口；源码门禁不替代真实 Windows 窗口管理器证据。
