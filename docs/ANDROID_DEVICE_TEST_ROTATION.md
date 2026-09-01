# 共享 Android 实机轮转

同一台 Android 手机同时服务三个 Codex 任务。所有会读取或改变实机运行状态的测试按固定顺序串行：

| 代号 | lane | 任务 |
|---|---|---|
| A | `biliroaming` | 哔哩哔哩模块 |
| B | `xhs` | 小红书模块 |
| C | `purelive` | Pure Live |

正常逻辑顺序固定为 `A → B → C → A`。同一时刻只有一个 lane 持有文件租约；一轮命令结束后自动记录结果并交给下一 lane。预期 lane 已提交活动请求时，后续 lane 始终排队，不会越过，因此三个任务不会并发触摸、安装或重启同一部手机上的应用。本轮没有实机步骤时，当前 lane 应通过自己的包装器提交显式 `-Pass`。若预期任务崩溃或消失且 120 秒内没有活动请求，协调器会记录 `graceSkip` 后放行下一个已经排队的 lane，避免另外两个任务永久等待；这不是由其他任务冒充被跳过的 lane，其后仍按循环状态继续交棒。

## Pure Live 调用

Pure Live 的实机命令统一由仓库包装器进入 `purelive` lane：

```powershell
.\tool\run_android_device_test_turn.ps1 `
  -CommandLine '.\tool\android_ui.ps1 -Validate'
```

播放、弹幕、音频模式往返、系统画中画恢复以及 CPU/PSS/帧时间证据使用同一个可重复冒烟脚本，并放在一个 C 轮次内执行：

```powershell
.\tool\run_android_device_test_turn.ps1 `
  -CommandLine '.\tool\android_runtime_smoke.ps1' `
  -TimeoutMinutes 30
```

同一台手机同时出现 USB 与网络 ADB 时，脚本优先选取唯一网络 transport；出现多个手机或多个网络 transport 时必须传入 `-Serial`，脚本拒绝猜测目标设备。默认证据写入 `local-artifacts/diagnostics/android-runtime-smoke-<时间>`，不会进入 Git。音频模式切换使用 UI 状态轮询完成串行确认，不用固定短延时连续点击，避免把尚未完成的第一次切换误判为第二次恢复。

需要把安装、仅重启 Pure Live、测试和证据采集合并成一个有边界的测试轮次时，把这些命令放进同一个 `-CommandLine`。包装器会等待 A、B 完成本轮，再独占设备执行 C，最后把下一轮交回 A。

共享协调器位于：

```text
%USERPROFILE%\Documents\Codex\shared-device-test-rotation\Invoke-DeviceTestTurn.ps1
```

本轮没有 Pure Live 实机步骤时也要显式交棒，避免 B lane 完成后等待 C：

```powershell
.\tool\run_android_device_test_turn.ps1 -Pass
```

队列状态和历史位于 `%LOCALAPPDATA%\Codex\device-test-rotation`，不进入 Git，也不得写入配对码、Cookie、Token、账号或其他凭据。

## 一轮的边界

- 一轮只覆盖一个明确场景或一组不可拆分的连续步骤，默认等待上限 180 分钟。
- 安装、`force-stop`、启动、触控、旋转、UIAutomator、截图、`logcat -c`、`settings`、`appops`、MT、LSPosed 操作均属于实机轮次。
- 只操作本任务的包、进程和数据。Pure Live 不清理或重启哔哩哔哩、小红书模块及其宿主。
- 手机重启、全局 ADB 重置、LSPosed 重启、设备级数据清理不属于普通测试轮次。
- 租约只解决设备互斥。取得轮次后仍先核对明确的 IP ADB serial 与前台包名；前台不是 Pure Live 时停止本轮的坐标输入。
- K90 Pro 在 10 分钟后自动锁屏且没有解锁凭据。Pure Live 的 UI 驱动与运行冒烟会在取得 C 轮租约后发送唤醒和 `dismiss-keyguard`；只有系统仍明确报告锁屏时才执行按当前分辨率计算的上滑，避免误触上一 lane 留下的应用。
- 各任务不得在租约外执行 `adb kill-server`。测试器取得 C 轮后会确认进程级 ADB server；若命令明确返回“daemon 未连接且命令尚未送达”，只重启 server 并有界重试一次，不对离线、超时或语义失败盲目重放触控。
- 命令成功、失败或抛出异常时都由包装器释放文件租约。测试失败也会交棒，避免后续任务长期排队。
- 没有实机步骤的代码审查、静态分析和本地单元测试不占用手机；重型构建仍单独遵守 `BUILD_POLICY.md` 的资源互斥规则。

## 轮转证据

共享历史按 NDJSON 记录 lane、退出码、完成时间、下一 lane 和循环编号。Pure Live 的测试报告还应记录：

1. 本轮场景与目标包版本；
2. 使用的明确 ADB serial；
3. 前台包守卫结果；
4. 命令退出码及证据路径；
5. 交棒后的 `nextLane`。

轮转记录只证明设备未被三个任务同时操作，不替代功能断言、截图、日志、性能采样或发布门禁。
