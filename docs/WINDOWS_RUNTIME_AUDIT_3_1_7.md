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

## 5. Bilibili 播放、弹幕与全屏交互回归

- 对象：同一 GitHub Release 便携产物，独立实例 `--instance=ui317_20260901T081000`。
- 热门页能够加载 Bilibili 20 张直播卡片及缩略图；打开开播房间后约 10 秒内取得首帧并连接弹幕服务器。
- 视频画面持续更新，弹幕列表与画面弹幕同步追加；访客昵称按 Bilibili 当前返回能力显示为脱敏昵称，界面同时给出原因说明。
- 发送本地测试弹幕 `local test 317` 后约 3.5 秒，列表出现 `Pure Live: local test 317`，画面顶部同时出现相同内容，证明列表与渲染层走同一房间会话。
- 弹幕设置页使用当前浅色主题，长页滚动可进入位置、样式、小窗弹幕和帧率选项；未观察到设置页被固定高度截断。
- 双击画面进入无标题栏真全屏，播放和画面弹幕保持连续；`Escape` 返回原窗口尺寸后列表继续追加，没有重建成空会话。
- 本房间只返回 `原画 / 线路1`，因此只核对了菜单真实内容，没有把“菜单可打开”误记为多画质或多线路切换通过。
- 纯音频、PiP、录制和退出回落仍为待执行项；本节不替代这些场景。

## 6. 300 秒播放资源采样

采样命令：

```powershell
.\tool\sample_windows_runtime.ps1 `
  -TargetProcessId <PID> `
  -DurationSeconds 300 `
  -IntervalSeconds 5 `
  -Scenario v3.1.7-bilibili-playback-ui
```

共 61 个样本，实际 300.648 秒，全程 `Responding=true`，进程没有意外退出：

| 指标 | 首样本 | 末样本 | 最大值 | 平均值 | 趋势/分钟 |
|---|---:|---:|---:|---:|---:|
| CPU | 2.9449% | 2.0761% | 3.8027% | 2.2202% | +0.2575% |
| Working Set | 399.7227 MiB | 421.5195 MiB | 434.7070 MiB | 412.6834 MiB | +5.0943 MiB |
| Private Bytes | 816.2930 MiB | 889.9492 MiB | 1209.4531 MiB | 861.1089 MiB | +21.5505 MiB |
| Handles | 1666 | 1656 | 1683 | 1669.1148 | +0.2198 |
| Threads | 242 | 238 | 245 | 241.9344 | -0.5607 |

Private Bytes 在个别采样点出现可逆峰值，下一采样点回落到约 842～890 MiB；Working Set、句柄与线程没有同步单调增长。五分钟结果没有显示句柄或线程泄漏，但 Private Bytes 的末值仍比首值高约 73.66 MiB，必须用更长等长采样、退出房间回落和录制对照来区分媒体缓存平台期与泄漏，当前不据此宣称“内存已完全稳定”。

本地证据：

- `local-artifacts/diagnostics/windows-regression/20260901T001723474Z-v3.1.7-bilibili-playback-ui-pid31172.csv`
- `local-artifacts/diagnostics/windows-regression/20260901T001723474Z-v3.1.7-bilibili-playback-ui-pid31172-summary.json`
