# Windows 小窗进出事务与生命周期审计（2026-09-14）

## 范围与结论

本批复核 Windows 播放器从控制栏进入小窗、在小窗内恢复主窗口，以及房间关闭/播放器销毁时的窗口所有权。基线为 `cb054eb0f63859da5e99b187d9f2ac8632c261bd`，实现提交为 `c069dcf290fff312e16d441d396e9d52a822c577`。

旧控制栏以未等待的 `void` 回调直接调用 `enablePip()`，原生异常没有用户反馈。Android 分支已有转换门禁，Windows 分支却会让重复点击并发进入；重复双击或关闭也会并发恢复主窗口。逻辑状态在原生调用结束前没有明确等待态，房间关闭后迟到的进入结果仍可能把原生窗口留在小窗模式，关闭或销毁一个已进入的小窗会话也没有沿 Windows 路径恢复主窗口。

`c069dcf2` 为 Windows 进出小窗增加独立的可注入宿主 seam，并复用播放器的转换修订号、会话 ID 和播放器身份建立单一所有权。进入/退出等待期间统一发布 `isPipPreparing` 并禁用相应入口；只有仍持有当前事务的原生成功结果才提交 `isInPip`。原生失败保留旧状态并显示双语反馈。关闭期间迟到完成的进入会执行一次主窗口清理；关闭或销毁已激活小窗时也会恢复主窗口。关闭意图同步阻止新的 PiP 进入，销毁则在等待宿主恢复前先建立终止栅栏。

## 状态合同

1. Windows 进入与退出共用单一转换门禁；等待期间的重复操作不再派发第二个宿主请求。
2. 进入成功前保持普通窗口逻辑状态；退出成功前保持小窗逻辑状态。
3. 进入或退出原生异常后释放等待态、保留旧逻辑状态，并允许用户重试。
4. 控制栏进入按钮、PiP 双击恢复和关闭按钮在转换期间禁用；UI 回调显式等待 Future 并捕获错误。
5. 转换结果必须同时匹配修订号、会话 ID 与当前播放器身份，旧会话结果不再提交。
6. 房间关闭期间完成的迟到进入会尽力恢复主窗口；已激活小窗的 `close()` / `dispose()` 各恢复一次。
7. 房间关闭意图同步阻止新的 PiP 进入；播放器销毁在首个异步恢复前先封闭后续工作。
8. Android 与 Windows 测试 override 互斥，宿主 seam 不会让 Android PiP 测试误入 Windows 原生路径。

## 有效红灯

- `local-artifacts/build-records/20260914T100944924Z-quality-focused.json`：既有 **42 PASS**，新增 Windows 转换合同 **1 FAIL**。连续进入派发了两个原生请求，且没有进入等待态。
- `local-artifacts/build-records/20260914T143208772Z-quality-focused.json`：既有 **43 PASS**，新增生命周期合同 **1 FAIL**。房间关闭后迟到完成的原生进入没有触发主窗口清理。

## 最终验证

- 播放器专项：`local-artifacts/build-records/20260914T144145207Z-quality-focused.json`，**46/46 PASS**，覆盖 Windows 进出 single-flight、进入/退出失败、重试、关闭期间迟到完成、已激活会话关闭/销毁恢复及关闭后禁止重入。
- 联合最终：`local-artifacts/build-records/20260914T144301219Z-quality-focused.json`，覆盖播放器音频/生命周期、播放页导航、Windows 小窗呈现/几何、视频设置与翻译合同，合计 **81/81 PASS**。
- 最后一次 Dart 编辑后的全库 analyze：`No issues found`（29.3 秒）。
- Dart 格式化、双语 JSON 解析、构建策略静态检查、仓库完整性审计与 `git diff --check` 通过；最终仓库审计 `local-artifacts/repository-audits/20260914T144153049Z-focused.json` 为 0 error。

## 验收边界与下一步

- 本批增加 W2-01 的源码/Widget 证据，该组继续保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批没有构建 Windows 候选、启动原生 GUI 或操作 Android 设备；Astra Light 使用 0 次，符合“仅在 Windows Computer Use GUI 验收开始时创建并复用一个任务”的规则。
- 后续 Windows 累计候选需验证快速重复进入、原生进入/退出失败反馈、PiP 双击/关闭单次恢复、进入过程中关闭房间、进程退出、宽屏/全屏快照恢复和多显示器几何。
- `WindowHelper` 内部模式提交、宿主串行与分步失败回滚已由 [`57ea9a85` 专项审计](WINDOWS_PIP_HOST_TRANSACTION_AND_ROLLBACK_AUDIT_2026_09_14.md)补齐；真实原生窗口验收仍按 W2-01 执行。
