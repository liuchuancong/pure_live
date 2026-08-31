# Pure Live v3.1.2 Android Release 运行审计

审计日期：2026-08-31（Asia/Shanghai）  
源码提交：`4d79e5fa6e0b861577d4e7dc0db3e37d50f8e5db`  
测试产物：`PureLive-3.1.2-4115-debug-signed-android-arm64-v8a-release.apk`  
测试设备：OnePlus PJZ110，Android 16 / API 36，`1440×3168`，640 dpi，最高 120 Hz。  
测试方式：通过网络 ADB 覆盖安装 GitHub Release APK，保留用户数据；不是 `flutter run`。

## 安装、数据与启动

- 覆盖安装从 `3.1.0+6113` 升级到 `3.1.2+6115` 成功，包名保持 `com.mystyle.purelive`，运行 ABI 为 `arm64-v8a`。
- 升级后原关注和直播卡片仍存在，没有因为版本更新清空本地数据。
- 首次冷启动 `TotalTime=314 ms`；启动约 4 秒的单点样本为 `PSS 234,528 KB / RSS 422,292 KB`，CPU 瞬时样本 0%。该单点只作启动基线，不代表长时资源结论。
- 连续 10 次强制结束后的冷启动全部成功：最短 293 ms、最长 332 ms、平均 306.2 ms；每次进程均存活、窗口获得焦点，日志中 0 次 Pure Live FATAL/ANR。
- 机器可读记录：`local-artifacts/runtime/android-v3.1.2/cold-start-10-runs-20260831.json`。

## 分类与横向边界

- 分类平台标签向左、向右分别重复滑动 10 次和 20 次，首端稳定为“哔哩哔哩 / 斗鱼 / 虎牙 / 抖音”，末端稳定为“网络 / Twitch / Soop / YY”，没有继续漂移或失去响应。
- 网易 CC 现网旧 JSON 分类地址跳转官方 Glive HTML 时，页面稳定显示“全部 / 端游 / 手游 / 其他”，没有 `jsonDecode`、格式异常、重试死循环或崩溃。
- 机器可读边界记录：`local-artifacts/runtime/android-v3.1.2/category-tab-boundaries-corrected-20260831.json`；CC 页面语义树与截图位于同一运行目录。

## 搜索与 Clash 应用代理

- “全部”搜索 `LOL` 可汇总并排序开播结果；全部/单平台标签同样在左右端点稳定停止。
- 设备未启用 Android 全局 HTTP 代理。本机 Clash/Mihomo 在 `192.168.1.238:7897` 监听，Windows 与手机 `nc` 均验证该端口可达。
- 应用层代理关闭时，全部搜索明确显示“部分平台请求失败：Twitch”；这属于当前设备到 Twitch 的直连路径差异，不是聚合搜索整体失败。
- 临时把 Pure Live 应用层代理设为 `192.168.1.238:7897` 后再次搜索 `LOL`，部分失败提示消失；切换到 Twitch 标签可取得真实结果及在线人数，例如 `Thebausffs`、`Drututt`、`Broxah` 等房间。
- 测试结束后已把代理地址恢复为 `127.0.0.1:7897`，并把“启用应用层代理”和“启用播放代理”都恢复为关闭，未修改 Android 全局代理或 VPN 设置。
- 证据：`search-lol-via-clash-retry.xml`、`search-lol-twitch-via-clash.xml/.png`、`proxy-restored-verified-enabled.xml`、`proxy-restored-final-off.xml`。

## 刷新率模式

- 设置页正确报告当前/最高刷新率 `120 / 120 Hz`。
- 省电、均衡、最高三档均在选择后即时更新说明；最高档同时说明主界面和自动弹幕跟随设备上限。
- 恢复测试前的“最高（设备上限）”后强制结束并冷启动，设置仍保持 `最高（设备上限） · 120 / 120 Hz`，证明即时作用和持久化均生效。
- 证据：`refresh-power.xml`、`refresh-balanced.xml`、`refresh-performance-restored.xml`、`refresh-after-restart.xml`。

## 当前结论与边界

- 本轮直接通过：覆盖升级与数据保留、10 次冷启动、分类/搜索标签硬边界、CC 分类迁移回退、三档刷新率与持久化、Twitch 经可达 Clash 应用代理的原生搜索。
- 上述过程没有出现 Pure Live FATAL/ANR。
- 尚未据此声明所有平台的播放、弹幕、画质、线路、录制、长时资源和故障恢复均已通过；这些项目继续按 `docs/ACCEPTANCE_MATRIX_3_1_0.md` 的未完成项执行。
