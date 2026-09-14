# Windows 小窗呈现事务与回滚审计（2026-09-14）

## 范围与结论

本批继续复核 Windows 小窗跨越播放器呈现层与原生宿主层的完整事务。基线为 `d31c9cd3664c8147e24ce80efad39cc3c8c146ef`，实现提交为 `b08a33f3bef4fbcf799c0bffe9405b6baaf2a5a7`。

旧 `WindowService` 会先保存全屏/宽屏快照并退出全屏，再调用宿主进入 PiP；宿主进入异常后不会恢复原呈现，重试还可能用已经改变的状态覆盖原始快照。退出则先恢复宿主窗口并提前清除快照；后续全屏/宽屏恢复异常时，原生窗口已经退出 PiP，但 `PlayerManager` 仍报告 PiP，重试也丢失了最初呈现。直接重复调用还会重叠执行并覆盖状态。呈现恢复器另会过早清除全局 `isPipMode`，形成多个逻辑状态发布者。

`b08a33f3` 为呈现捕获、进入准备和恢复增加可注入边界，并在 `WindowService` 建立进出 single-flight、活动状态与原始快照所有权。进入失败先恢复原呈现，成功后才提交活动状态；退出先保留当前 PiP 呈现，宿主退出后再恢复原呈现。原呈现恢复异常时，服务先恢复 PiP 呈现并重新进入宿主，使旧状态完整回滚且可重试。如果宿主重新进入也异常，则再次恢复原呈现、提交宿主已经退出的事实，并通过带 `hostIsInPip=false` 的 `WindowsPipExitFailure` 告知 `PlayerManager` 同步逻辑状态，同时保留上层失败反馈。

## 状态合同

1. 首次进入前只捕获一次全屏/宽屏快照；失败重试不会用部分转换状态覆盖它。
2. 呈现准备和宿主进入全部成功后，服务才提交 Windows PiP 活动状态与有效视频比例。
3. 进入任一步骤异常时先恢复原呈现；恢复成功后清理快照，下一次进入重新捕获干净状态。
4. 退出先保存当前 PiP 呈现，再恢复宿主窗口，最后恢复进入前呈现；全部成功后才清理快照。
5. 退出后的呈现恢复异常时，服务恢复 PiP 呈现并重新进入宿主；成功回滚后继续保持活动状态和原始快照，允许再次退出。
6. 宿主重新进入也异常时，以真实宿主状态为准提交普通窗口，并携带 `hostIsInPip=false` 的类型化异常。
7. `PlayerManager` 收到已提交宿主退出的类型化异常时同步 `isInPip=false`；异常仍向控制层传播，以便显示失败反馈。
8. 全局 `isPipMode` 继续由 `PlayerManager.isInPip` 的唯一订阅发布，呈现恢复器不再抢先修改。
9. 同一转换期间的重复直接调用共享 Future，不重复退出全屏、写宿主或恢复呈现；失败后门禁正常释放。
10. 测试 seam 只替换呈现和宿主操作；生产路径继续使用当前 `LivePlayController`、视频控制器与 `WindowHelper`。

## 有效红灯

- `local-artifacts/build-records/20260914T150423791Z-quality-focused.json`：原有快照测试 **2 PASS**，新增事务合同 **3 FAIL**。旧实现稳定暴露进入失败不恢复呈现、退出呈现恢复失败后宿主留在普通窗口，以及重复进入派发两次三项问题。

## 最终验证

- 呈现与播放器状态专项：`local-artifacts/build-records/20260914T150803580Z-quality-focused.json`，**53/53 PASS**，覆盖宿主退出已经提交但更高层恢复仍异常的状态同步。
- 联合最终：`local-artifacts/build-records/20260914T151731816Z-quality-focused.json`，覆盖呈现事务、播放器状态、宿主事务、PiP 几何、视频设置、窗口尺寸和播放导航，合计 **97/97 PASS**。
- 最后一次 Dart 编辑后的全库 analyze：`No issues found`（27.2 秒）。
- Dart 格式化、构建策略静态检查、仓库完整性审计与 `git diff --check` 通过；最终仓库审计 `local-artifacts/repository-audits/20260914T151626176Z-focused.json` 为 0 error、2 warning。

## 验收边界与下一步

- 本批增加 W2-01 的呈现层确定性证据，该组继续保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批未构建 Windows 候选、启动原生 GUI 或操作 Android 设备；Astra Light 使用 0 次。
- 后续 Windows 累计候选需覆盖普通/宽屏/真全屏进入 PiP、正常退出恢复、快速重复操作、宿主和呈现异常注入、房间关闭/进程退出，以及主副屏往返。
- 源码与 Widget 门禁证明事务顺序、回滚和重试语义；W2-01 的最终结论继续等待真实 Windows 窗口、视频、输入和显示器证据。
