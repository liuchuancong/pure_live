# Pure Live v3.1.7 Windows 便携版运行基线

## 1. 测试对象与隔离方式

- 对象：GitHub Release 同源产物 `PureLive-3.1.7-4120-windows-x64-portable.zip`。
- SHA-256：`ac174263d67c3d131656c69043d21562b5c4fd85512c5fca970e23ef2c603013`。
- 解压目录：`.local-build/windows-v3.1.7-runtime-20260831T235951296Z/`。
- 启动参数：独立 `--instance=smoke317_20260831T235951296Z`。
- 数据目录：便携目录内 `AppData/smoke317_20260831T235951296Z/`，没有读取或覆盖用户现有安装的数据。
- 测试窗口以隐藏方式启动；本轮只建立启动、空闲资源和退出基线，不把它扩大解释成播放器或录制实测。

## 2. 启动与隔离结果

| 检查项 | 结果 |
|---|---|
| FileVersion / ProductVersion | `3.1.7+4120` |
| 启动后是否响应 | 是 |
| 独立数据根是否创建 | 是 |
| 数据是否写入便携目录之外 | 本场景未发现 |
| 180 秒内无响应样本 | 0 |
| 退出后同路径残留进程 | 0 |
| 独立目录文本日志中的 FATAL / Unhandled exception / ERROR | 0 |

独立数据目录只产生迁移锁、Hive 设置文件和空迁移清单，共 4 个文件；没有把运行期数据写入发布 ZIP，也没有接触正式安装目录。

## 3. 180 秒空闲资源基线

采样命令：

```powershell
.\tool\sample_windows_runtime.ps1 `
  -TargetProcessId <PID> `
  -DurationSeconds 180 `
  -IntervalSeconds 5 `
  -Scenario v3.1.7-portable-idle
```

共 37 个样本，实际 180.930 秒，全部 `Responding=true`：

| 指标 | 首样本 | 末样本 | 最大值 | 趋势/分钟 |
|---|---:|---:|---:|---:|
| CPU | 0.0000% | 0.0129% | 0.0398% | +0.0037% |
| Working Set | 196.0078 MiB | 196.0234 MiB | 196.0586 MiB | +0.0024 MiB |
| Private Bytes | 530.9766 MiB | 528.8086 MiB | 530.9766 MiB | -0.1557 MiB |
| Handles | 1072 | 1043 | 1072 | -3.5541 |
| Threads | 153 | 147 | 153 | -1.5695 |

空闲 Working Set 在约 0.11 MiB 范围内波动，线性趋势接近 0；Private Bytes、句柄和线程均回落。该结果证明干净便携实例的空闲阶段没有观察到持续资源增长，但直播、弹幕、录制、PiP 与多窗口仍需分别采样，不能由空闲结果替代。

## 4. 本地证据

- `local-artifacts/diagnostics/windows-regression/20260901T000031375Z-v3.1.7-portable-idle-pid35756.csv`
- `local-artifacts/diagnostics/windows-regression/20260901T000031375Z-v3.1.7-portable-idle-pid35756-summary.json`
- `.local-build/windows-v3.1.7-runtime-20260831T235951296Z/`

上述目录按仓库策略不提交 Git；本文件只记录可复核摘要。后续使用同一发布产物继续执行播放、弹幕、短录、退出回落和更长平台期对照。
