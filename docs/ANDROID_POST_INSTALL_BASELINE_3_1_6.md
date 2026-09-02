# Pure Live v3.1.6 Android 安装后静态基线

本记录补充 v3.1.6（`versionCode=6119`）覆盖安装后的非侵入式检查。检查期间手机正在使用其他应用，因此没有启动 Pure Live、抢占前台或执行点击；这里只验证安装、空闲资源释放和系统历史记录，不把它扩大解释成播放器、弹幕或录制实测通过。

## 环境

- 设备：OnePlus PJZ110，Android 16，arm64-v8a。
- 包名：`com.mystyle.purelive`。
- 已安装版本：`3.1.6+6119`。
- 覆盖更新时间：2026-09-01 04:58:06（Asia/Shanghai）。
- 采样时间：2026-09-01 05:25:16（Asia/Shanghai）。
- 采样时前台：`com.xingin.xhs/.index.v2.IndexActivityV2`。

## 结果

| 检查项 | 结果 |
|---|---|
| 覆盖安装后版本 | `versionName=3.1.6`、`versionCode=6119` |
| Pure Live 活动进程 | 0 |
| Pure Live 活动服务 | 0 |
| Pure Live 活动通知 | 0 |
| 系统活动 Wake Lock | `Wake Locks: size=0` |
| Pure Live 活动 Wake Lock | 0 |
| Android DropBox 中主进程属于 Pure Live 的 `data_app_anr` / `data_app_crash` | 0 |
| 用户前台是否被改变 | 否 |

DropBox 归属按每条记录的主 `Process:` 字段判断。系统级 ANR 采样中出现某个应用的 CPU/线程快照，不等同于该应用是 ANR 主体；本次没有把其他应用的 ANR 误归因给 Pure Live。

## 证据边界

原始证据保存在忽略版本控制的本地目录：

- `local-artifacts/runtime/android-v3.1.6/post-install-baseline/post-install-baseline.json`
- `local-artifacts/runtime/android-v3.1.6/post-install-baseline/active-wakelocks.txt`
- `local-artifacts/runtime/android-v3.1.6/post-install-baseline/purelive-dropbox-summary.json`
- `local-artifacts/runtime/android-v3.1.6/post-install-baseline/data_app_anr.txt`
- `local-artifacts/runtime/android-v3.1.6/post-install-baseline/data_app_crash.txt`

该基线证明覆盖安装后没有遗留后台进程、服务、通知或唤醒锁，也没有检出以 Pure Live 为主进程的历史崩溃/ANR。播放、弹幕、横竖屏、PiP、小窗、录制和网络故障恢复仍按 `ACCEPTANCE_MATRIX_3_1_0.md` 的对应运行项继续验证。
