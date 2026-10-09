# 共享 Android 实机轮转

> `AGENTS.md` 与 `BUILD_POLICY.md` §5.1 链接的租约规则。v1 版本(`5a06d9d22` 随 v1 文档一起删除)里那些
> 逐日调度段、候选 SHA 和手机现场记录属于**历史证据**,不重建;这里只留仍然成立的规则。
>
> 前置默认:**设备工作只在当前请求明确要求时进行**。历史的连接授权、曾经过的配对、以往跑通的命令都不算
> 继续的同意(见 `AGENTS.md` 的 Device and collaboration boundaries)。

## 1. 入口与参数

`tool/run_android_device_test_turn.ps1` 是本仓库的串行设备步骤包装器,保留唤醒、常亮恢复、前台校验和失败清理。

| 参数 | 含义 |
| --- | --- |
| `-CommandLine` | 本轮要在设备上执行的完整命令。与 `-Pass` 互斥。 |
| `-Pass` | 本轮本仓库没有设备步骤,显式交棒。 |
| `-Serial` | 目标 transport;缺省读当前进程的 `PURELIVE_ADB_SERIAL`,显式参数优先。 |
| `-NoRotation` | 不参加轮转,直接执行本轮。只改变调度,不代表绕过任何设备检查。 |
| `-TimeoutMinutes` / `-TurnGraceSeconds` / `-PollSeconds` | 轮次上限 / 预期 lane 无活动请求时的宽限 / 轮询间隔(默认 180 / 120 / 3)。 |

包装器从 `tool/` 逐级向上找协调器 `shared-device-test-rotation/Invoke-DeviceTestTurn.ps1`。**该目录在仓库之外**
(共享工作区设施),找不到且没有 `-NoRotation` 时脚本直接抛错。因此今天这台机器上只有显式 `-NoRotation` 的
单轮可跑;恢复共享轮转之前不要假设有协调器。

## 2. 轮转规则(协调器存在时)

- 同一部手机同时服务多个任务时,所有会读或改实机运行状态的步骤固定串行,一次只有一个 lane 持有文件租约。
- v1 安排的三条 lane 与顺序是 `biliroaming → xhs → purelive`,循环交棒。v2 分支上只有 `purelive` 这一条还属于
  本仓库,另外两条属于别的仓库/任务;恢复共享实机安排时要重新确认当前 lane 清单,不要把这段当成现状。
- 预期 lane 已提交活动请求时,后面的 lane 一直排队,不越过。
- 预期 lane 崩溃或消失且宽限期内没有活动请求时,协调器记 `graceSkip` 放行下一个已排队的 lane;这不是由别的
  任务冒充被跳过的那个,其后仍按循环继续。
- 本轮没有实机步骤就用 `-Pass` 提交,不要静默跳过。

## 3. 操作边界

- 一条命令只绑一个显式 serial:多在线 transport 时按 `-Serial IP:PORT` 选定,唤醒步骤与**清理**都用这一个编号;
  清理不跟随正文里被改写的环境变量。预检选不出目标时,不对旧环境执行常亮清理。
- 唤醒、安装、输入之前先只读核对设备身份(`ro.product.model` 与 `ro.product.device` 成对核对)与当前前台包名;
  不按设备列表顺序猜测,不把"离线"等同于"配对失效"。
- 连接失败先读 `adb devices` / mdns,再试用户给定的备用地址。**不做**这些动作:重启手机或 adbd、`adb kill-server`、
  切换 Wi-Fi、撤销调试授权、改 ADB 端口、更新 Root/LSP 模块。
- 保留数据的覆盖安装只在核对签名、版本与关键数据快照之后进行;失败时保留证据,不重复靠等待来"恢复"。
- 本轮结束要核验:自己创建的代理 session/reverse 回到基线、本包进程与唤醒锁消失、常亮恢复原值。外部改值保留,
  恢复失败要报告而不是掩盖。
- 录制/触控/UIAutomator/截图/日志清理等设备操作必须经本包装器(见 `BUILD_POLICY.md` §5.1),
  屏幕元素与坐标含义见 `tool/DEVICE_UI_MAP.md`。

## 4. 离线回归

设备工具本身的修改可以先不碰手机验证:

```powershell
py -3 -m unittest discover -s tool\tests -p test_android_device_test_turn.py
```

它只执行假的唤醒脚本,不调用 ADB。注意本机裸 `python` 解析到一个缺标准库的 mingw64 解释器(见
`docs/roadmap/w2-progress.md` §4 的环境注意),所以这里必须用 `py -3`。
