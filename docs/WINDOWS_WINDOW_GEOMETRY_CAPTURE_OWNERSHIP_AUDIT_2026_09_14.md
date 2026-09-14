# Windows 窗口几何捕获所有权审计（2026-09-14）

## 范围与结论

本批复核桌面窗口事件如何保存普通窗口大小与 Windows PiP 矩形。基线为 `8b617a7871b07536bb8750c1567103a9e2363db0`，实现提交为 `30c2e4cf0052af3ae84fa026e6da6ee6e13305a3`。

旧 `DesktopWindowMixin` 在窗口事件回调开始时读取 `WindowHelper.currentMode`。普通模式分支绕过宿主队列，直接异步执行 `windowManager.getSize().then(updateSize)`；读取期间若进入/退出 PiP，部分 PiP 尺寸可能被保存成下次启动的普通窗口大小。最大化、最小化和真全屏产生的尺寸也缺少持久化隔离。PiP 分支与普通分支的 Future 都没有统一异常收口，被动窗口事件可能产生未处理异步异常。

`30c2e4cf` 将 Windows 普通窗口与 PiP 的几何判断收口到 `WindowHelper.captureWindowGeometry`，并与进入、退出、置顶更新和 PiP 捕获共用宿主串行队列。队列真正执行时再判断已提交模式：PiP 只写完整矩形；普通窗口先后两次核对最小化、最大化和真全屏状态，只有异步尺寸读取前后均属于可恢复普通窗口才更新启动尺寸。桌面事件统一等待这一捕获 Future 并记录异常；非 Windows 桌面继续读取本机窗口大小，但也进入相同异常边界。

## 状态合同

1. Windows 窗口事件不再在队列外按旧模式分流，也不再直接异步写普通窗口尺寸。
2. 几何捕获排在已提交的 PiP 进入/退出之后，根据最终模式选择普通尺寸或 PiP 矩形，避免混合快照。
3. 普通窗口只在最小化、最大化和真全屏均为 false 时参与启动尺寸持久化。
4. 普通尺寸读取完成后再次核对模式和原生呈现，隔离读取期间发生的最大化、全屏或 PiP 转换。
5. PiP 捕获继续要求记忆位置开关，并在写入前再次核对已提交 PiP 模式。
6. 宿主读取异常向显式调用者返回，但共享队列吞掉前一任务状态后仍可执行下一次捕获。
7. 被动窗口事件拥有统一的异步异常边界，不把窗口插件异常泄漏为未处理 Future。
8. macOS/Linux 继续沿用普通窗口尺寸读取路径，不进入 Windows PiP 宿主逻辑。
9. 测试 seam 覆盖原生呈现查询、读取门禁、失败重试和进出 PiP 排序；生产路径继续调用 `window_manager`。

## 有效红灯

- `local-artifacts/build-records/20260914T152518731Z-quality-focused.json`：旧源码合同 **7 PASS / 1 FAIL**。失败稳定锁定桌面事件仍在宿主队列外按旧模式分流、普通分支直接异步写尺寸且缺少异常边界。

## 最终验证

- 宿主专项：`test/windows_pip_host_transaction_test.dart`，**13/13 PASS**，覆盖普通窗口写入、最小化/最大化/真全屏隔离、异步读取后二次核对、失败后重试，以及 PiP 进入/退出队列两侧的唯一几何提交。
- 联合最终：`local-artifacts/build-records/20260914T153101706Z-quality-focused.json`，覆盖 10 个相关测试文件，合计 **121/121 PASS**。
- 最后一次 Dart 编辑后的全库 analyze：`No issues found`（28.0 秒）。
- Dart 格式化、构建策略静态检查、仓库完整性审计与 `git diff --check` 通过；最终仓库审计 `local-artifacts/repository-audits/20260914T152954324Z-focused.json` 为 0 error、2 warning。

## 验收边界与下一步

- 本批增加 W1-01/W2-01 的窗口状态与几何确定性证据，两组继续保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本批未构建 Windows 候选、启动原生 GUI 或操作 Android 设备；Astra Light 使用 0 次。
- 后续累计候选需验证普通窗口拖动/缩放后的重启恢复，最小化/最大化/真全屏不覆盖普通尺寸，以及普通、宽屏、真全屏与 PiP 在主副屏间的连续往返。
- 源码门禁证明捕获所有权和顺序；W1-01/W2-01 的最终结论继续等待真实窗口事件、显示器与进程重开证据。
