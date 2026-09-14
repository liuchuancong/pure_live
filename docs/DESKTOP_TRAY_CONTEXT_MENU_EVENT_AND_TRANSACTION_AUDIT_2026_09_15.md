# 桌面托盘菜单事件与事务所有权审计（2026-09-15）

## 范围与结论

本批复核桌面托盘图标的右键菜单事件、菜单刷新与弹出顺序。基线为 `ad03c965119036772ce812e5c92a420906615b3c`，实现提交为 `cd9fed8d7937377c93e752a2ca3de1f4f82b5897`。

旧 `DesktopWindowMixin` 同时在 `onTrayIconRightMouseDown` 和 `onTrayIconRightMouseUp` 打开上下文菜单：按下路径先刷新菜单再弹出，释放路径又异步聚焦窗口并再次弹出。一次物理右键因此可派发两次菜单请求，后一路 `.then` 还没有异常边界；连续右键会让菜单刷新、窗口聚焦与多次弹出并发交错。

`cd9fed8d` 将右键按下确定为唯一事件入口，右键释放保持空回调，不再额外聚焦主窗口或第二次弹出菜单。`DesktopTrayMenuCoordinator` 为“刷新菜单 → 弹出菜单”建立 single-flight 事务：等待期间的重复请求共享同一个 Future，完整结束后才释放门禁；刷新或弹出异常同样释放门禁，外围 `DesktopManager` 记录异常。托盘左键、右键和菜单项事件也都以显式 `unawaited` 标注异步所有权，业务处理方法继续保留各自异常边界。

## 状态合同

1. 一次托盘右键手势只有 `onTrayIconRightMouseDown` 是上下文菜单所有者。
2. `onTrayIconRightMouseUp` 不聚焦窗口、不刷新菜单，也不再次调用 `popUpContextMenu`。
3. 菜单始终按“刷新本地化提示与可见状态 → 弹出”顺序执行。
4. 同一事务等待期间的重复请求返回同一 Future，刷新与弹出各执行一次。
5. 刷新完成前不弹出菜单，避免显示与当前窗口可见状态不一致的半更新菜单。
6. 刷新或弹出任务失败后门禁在 `whenComplete` 中释放，下一次右键仍可重试。
7. 原生托盘异常由 `DesktopManager.handleTrayRightClick` 收口，不从 void 事件回调泄漏。
8. 托盘左键与菜单项业务语义保持：显示/聚焦、隐藏与退出仍走原有处理方法。

## 有效红灯

- `local-artifacts/build-records/20260914T234517299Z-quality-focused.json`：旧源码合同 **0 PASS / 1 FAIL**。失败稳定锁定右键按下/释放存在双事件所有者，且缺少共享事务协调器与显式异步派发。

## 最终验证

- 新专项 `test/desktop_tray_menu_transaction_test.dart`：**3/3 PASS**，覆盖唯一右键事件所有者、并发请求共享 Future、刷新后单次弹出、弹出异常传播、门禁释放及失败后重试。
- 联合最终：`local-artifacts/build-records/20260914T234731956Z-quality-focused.json`，覆盖 7 个相关测试文件，合计 **35/35 PASS**。
- 最后一次 Dart 编辑后的全库 analyze：`No issues found`（23.4 秒）。
- Dart 格式化、构建策略静态检查、仓库完整性审计与 `git diff --check` 通过；最终仓库审计 `local-artifacts/repository-audits/20260914T234639067Z-focused.json` 为 0 error、2 warning。

## 验收边界与下一步

- 本批增加 W1-01 的托盘事件与并发确定性证据，该组继续保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批未构建 Windows 候选、启动原生 GUI 或操作 Android 设备；Astra Light 使用 0 次。
- 后续累计候选需验证单次右键只显示一个菜单，快速连续右键不闪烁、不重复弹出，菜单文案与窗口显示/隐藏状态一致。
- 还需验证左键显示/聚焦、菜单隐藏/显示/退出、任务栏自动隐藏、不同 DPI/多屏托盘位置，以及原生弹出失败后的下一次重试；源码门禁不替代真实系统托盘证据。
