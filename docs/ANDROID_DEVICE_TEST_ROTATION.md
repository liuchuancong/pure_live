# 共享 Android 实机轮转

## 当前任务覆盖规则（2026-09-05）

### 2026-09-07 用户补充：K90 Pro Max 远程操作边界

当前主机 DESKTOP-F2H984F，ADB 固定路径 `C:\Users\123\AppData\Local\Android\Sdk\platform-tools\adb.exe`。目标优先 `192.168.1.2:5555`，备用 `192.168.1.2:36883`（动态端口）。任何唤醒或应用操作前先用明确 `-s` 只读核对 `ro.product.model=25102RKBEC`、`ro.product.device=myron`；当前系统 Android 17。安装、输入及状态读取均绑定该编号，不按设备列表顺序猜测。

用户缺少现场救援条件：不重启手机/adbd，不切换 Wi-Fi，不撤销调试授权，不修改 ADB 端口，不更新 Root/LSP/其他模块，不执行 `adb kill-server`。本段覆盖下方历史默认恢复策略。连接失败只先读 devices/mdns，再尝试用户给定备用地址；不将离线等同配对失效。Wireless ADB 的开机 5555 尚未重启验证，本任务不通过重启补证；既有 Root 能力不意味着本次测试需要调用 su。

### 当前调度

09-08 升级前置最新状态：[只读备份与本地迁移演练](ANDROID_SCHEMA7_BACKUP_REHEARSAL_2026_09_08.md)已核对实际安装 80b7431c、新候选同证书及两份一致关键数据快照，真实 schema 6 副本生产升级至 7 并重开验证通过。手机前台为哔哩哔哩，未唤醒、安装或输入，已询问切换测试窗口。下一轮重新核对当前前台/进程/数据哈希，确认窗口后才执行保留数据安装；不重建不变的 1d318bba。

09-08 当前验收输入：[花椒与响应收尾累计候选](HUAJIAO_ANDROID_CANDIDATE_2026_09_08.md) **1d318bba** 已完成完整门禁、arm64 Debug 构建和独立归档核验，尚未安装；32 组原生场景待验。下一轮先只读核对设备、前台/录制、当前签名和一致数据库备份，再按共享包装器执行保留数据覆盖安装；不重复构建旧候选。Windows 仍 f3de664a。下方各“最新”段均保留为历史调度记录。

最新[累计候选](CUMULATIVE_ANDROID_CANDIDATE_2026_09_08.md)：3a7716b0 Android Debug 已通过全量质量门、内容/签名核验并归档，尚未安装。本批没有设备操作；等待明确前台测试窗口，下一轮重新核对实际设备身份、前台/录制与安装包签名、版本和数据，再以 NoRotation、显式 Serial 的共享包装器执行。旧候选保留；下方各“最新”段为历史记录。

最新[目录恢复累计候选](DIRECTORY_RECOVERY_AUDIT_2026_09_08.md)：58546f51 Android Debug 已构建并归档，含分区/图标与目录恢复修订，尚未安装。本轮只读核对 192.168.1.2:5555、25102RKBEC/myron 一致，没有唤醒或前台输入。等待明确的 Pure Live 前台测试窗口，下一轮重新核对身份、现有版本/前台/录制和数据，再用 NoRotation、显式 Serial 的包装器执行；所有远程设备边界保持。下方旧候选状态属于历史记录。

最新[09-08 TLS候选](RECORDING_TLS_ANDROID_CANDIDATE_2026_09_08.md)：b5f39c2b已构建并归档，尚未安装。手机切换窗口等待用户确认，本批未执行任何设备操作。下轮使用该候选，先重读身份/前台/常亮和运行状态；不将旧预检作为当前手机状态，NoRotation及用户所有远程边界保持。

最新[录制暂存候选与守卫](RECORDING_STAGED_ANDROID_CANDIDATE_2026_09_07.md)：c442380c Android Debug已构建但未安装。只读确认身份一致，前台为哔哩哔哩，待用户确认切换窗口；本次没有唤醒或输入。唤醒脚本已增加自身身份预检；常亮采用原位掩码精确恢复及读回核验，清理接收本轮原值/取得值，不再固定关闭。外部改值保留并报告失败。工具修订仅离线验证，下一轮继续先核对身份与前台；NoRotation保持。

最新[Cookie候选Android复验](TWITCASTING_COOKIE_ANDROID_RETEST_2026_09_07.md)：手机当前为80b7431c，保留数据覆盖安装成功；首段401解除，但MP4尾部附近严格解码失败，转为本机确定性复现。12:47:25 UTC最终清理核验通过，无本包进程/活动唤醒锁，代理与reverse回到基线，常亮恢复。本轮新任务已取消；下一轮设备前先处理测试器对旧监控及失败force-stop的所有权缺口。历史轮次见下。

最新[TwitCasting原生与会话审计](TWITCASTING_ANDROID_NATIVE_AUDIT_2026_09_07.md)：Android 1a18f353已保留数据覆盖安装，首段401导致短录FAIL，源码Cookie修订尚待新候选实机复验。11:55:25 UTC精确核验两个代理session恢复、reverse回到基线、本包进程/唤醒锁消失；测试监控已明确取消，原有监控保留，常亮恢复。手机当前未安装后续Cookie修复。NoRotation及用户远程边界保持。

最新[浮窗遮挡收尾审计](ANDROID_PROXY_OCCLUSION_AUDIT_2026_09_07.md)：复用1aa6886f，已完成一次实际录制后代理开关自动恢复与session/映射/进程/唤醒锁清理。10:26:02 UTC最终核验通过；这是历史证据，下一次仍重新核对设备与前台。NoRotation调度规则保持不变。

最新[Picarto 原生审计](PICARTO_ANDROID_NATIVE_AUDIT_2026_09_07.md)：候选已覆盖安装，独立代理往返通过，短录因解码损坏与自动收尾失败尚未通过；明确恢复及进程/唤醒锁/常亮清理已完成。录制入口使用实际返回导航；嵌套滚动修订只有离线复验，下一轮先补最小原生恢复证据。

本轮录制工具更新见[守卫审计](ANDROID_RECORDING_GUARD_AUDIT_2026_09_07.md)：`android_recording_smoke.ps1`要求明确Serial、型号/代号一致且Pure Live已在前台；前台或连接异常时停止，不重选目标、不重放输入、不抢回应用。平台导航按实际标签逐次观察。[代理事务](ANDROID_PROXY_TRANSACTION_AUDIT_2026_09_07.md)现已完成离线回归；国外录制前先独立验证本轮代理开启/恢复和session对账，不把旧入口说明当作当前手机已验收。

用户已暂停三个任务轮转。本次完整验收使用 `tool/run_android_device_test_turn.ps1 -NoRotation -CommandLine '…'` 直接执行本项目的串行设备步骤，保留唤醒、常亮恢复、前台校验和失败清理。网络 ADB 在线先测 Android，离线改测 Windows；不等待其他任务交棒，也不操作其他应用。恢复共享实机安排时再使用下面的默认租约流程。此开关只改变调度，不代表绕过设备检查。

多条在线 transport 时，包装器使用 `-Serial IP:PORT` 明确选择，或从当前进程 `PURELIVE_ADB_SERIAL` 读取默认值；显式参数优先。该编号经编码传给唤醒步骤，成功后再传给测试正文。清理只针对唤醒成功的同一编号，不跟随正文改写的环境变量；预检选择失败时不对旧环境目标执行常亮清理。离线回归命令为 `python -m unittest discover -s tool/tests -p test_android_device_test_turn.py`，只执行假的唤醒脚本，不调用 ADB。

国外平台可在同一包装器中调用 `tool/android_foreign_recording_smoke.ps1 -Platform twitch -ExerciseStreamSelection`；它创建独立session，完成画质/线路选择与短录后恢复两个原开关状态，只清理自己明确创建且未被替换的reverse。正常原状态均关闭时回到DIRECT。录制器独立选择录制画质，短录通过不代表它继承了播放器选择。

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
  -Serial '192.168.1.2:5555' `
  -CommandLine '.\tool\android_runtime_smoke.ps1 -Serial $env:PURELIVE_ADB_SERIAL -ExpectedModel 25102RKBEC -ExpectedDevice myron' `
  -TimeoutMinutes 30
```

同一台手机同时出现 USB 与网络 ADB 时，脚本优先选取唯一网络 transport；出现多个手机或多个网络 transport 时必须传入 `-Serial`，脚本拒绝猜测目标设备。冒烟脚本会先核对型号/代号、前台应用和 Pure Live 进程：其他应用占用前台时在脚本自身的唤醒、启动和点击前结束；外层轮转包装器的唤醒/待机恢复仍按租约执行。确需切换前台时明确追加 `-AllowForegroundSwitch`，确需重启已运行的 Pure Live 时追加 `-AllowAppRestart`。预检失败时也不会在清理阶段强停 Pure Live。默认证据写入 `local-artifacts/diagnostics/android-runtime-smoke-<时间>`，不会进入 Git。音频模式切换使用 UI 状态轮询完成串行确认，不用固定短延时连续点击，避免把尚未完成的第一次切换误判为第二次恢复。

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
- K90 Pro 在 10 分钟后自动锁屏且没有密码。Pure Live 包装器会在取得 C 轮租约、执行任何真实设备命令之前统一调用 `tool/wake_android_device.ps1 -StayAwake`：优先选择唯一 IPv4 ADB transport，发送唤醒和 `dismiss-keyguard`，复核系统 Keyguard，并仅在当前测试租约内启用供电时常亮；`finally` 总会调用 `-ReleaseStayAwake` 恢复用户原有的 10 分钟锁屏策略。具体 UI/运行冒烟仍保留每次观察前的二次唤醒复核，因此长队列等待或无线 ADB 慢响应不会把锁屏页当成应用界面。
- 国外平台只在独占设备轮次使用代理脚本。`android_configure_proxy.ps1 -Mode LocalClash -Serial ... -SessionPath ...`先核对设备、前台和本机Clash监听；当前地址/端口字段须已配置为127.0.0.1及指定端口。前台必须是可识别的Pure Live首页或代理页，操作逐次读取XML；不自动抢回其他应用。配对调用`android_restore_proxy_defaults.ps1 -Serial ... -SessionPath ...`，记录包含实际端口、两个原开关状态及reverse所有权。无session的恢复调用只在已有目标前台关闭两个开关，不删除任何reverse。清理遇前台丢失或所有权歧义时保留cleanup-pending及路径，不报告成功；恢复后核验session状态和实际设备状态。
- Twitch/Soop/Picarto 的标准录制回归使用 `tool/android_foreign_recording_smoke.ps1`，由它负责上述代理启用与 `finally` 清理；该脚本本身仍须作为 C 轮包装器的 `-CommandLine` 执行。
- 新设备尚未建立网络 ADB transport 时，可仅在当前 PowerShell 进程临时设置 `PURELIVE_ADB_PAIR_ENDPOINT`、`PURELIVE_ADB_PAIR_CODE`，以及可选的 `PURELIVE_ADB_CONNECT_ENDPOINT`。唤醒脚本先完成一次配对、从 `_adb-tls-connect._tcp` 自动发现同一 IP 的连接端口，再继续唤醒检查；协调器状态与历史只保存脚本命令，不记录配对码。完成当前命令后立即清除这些临时环境变量。
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
