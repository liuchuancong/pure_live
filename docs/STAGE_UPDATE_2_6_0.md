# v2.6.0 阶段稳定版

版本：`2.6.0+4076`
维护仓库：`wzgrx/pure_live`
上游基线：`liuchuancong/pure_live@c3ae29bb`
发布日期：2026-08-23

## 本阶段范围

1. 真实合并上游至 `c3ae29bb`，包含关注刷新、房间详情补全、版本历史容错、弹幕模板、BetterPlayer 尺寸与 Windows 小窗设置改动；冲突语义按维护版稳定性实现整合。
2. 修复近期公开问题 #765、#769、#770、#771、#773，并吸收 #767 的高 DPI 性能边界。
3. 修复首页图片缓存反复驱逐、非 Exo 原生纹理初始化环、画面比例切换重开流等 CPU/GPU/内存热点。
4. 更新全部可直接升级且与 Flutter 3.47 兼容的依赖；保留有明确类型或原生组合约束的固定项。
5. Android、Windows、Linux、macOS、iOS 分阶段串行构建；不向上游提交 PR。

## 稳定性设计

- 房间详情、醒目留言、播放地址和弹幕连接均以当前“房间号 + 平台 + 加载代次”为提交条件，迟到响应只结束自身任务，不覆盖新房间。
- PiP、横竖屏、后台恢复继续复用同一播放器和弹幕会话；恢复 revision 只重建展示订阅，连接异常时才重连。
- 弹幕历史、待处理批次、文本/表情缓存与本地互动队列保持有界；直播控制器关闭时取消 Worker、Timer、订阅和子控制器。
- 图片按可见尺寸解码并复用磁盘缓存；刷新只推进全局 epoch，不逐卡删除同一缓存条目。
- Windows 原生视频视图受可见视口约束；播放器适配模式更新只改变布局，不重新拉流。
- Windows 小窗位置、大小与主窗口几何独立保存，并提供记忆开关和显式重置；默认跟随应用所在显示器，多显示器变化时把旧矩形校正到仍可见的工作区。

## 依赖审计

- Dart/Flutter：`scrollview_observer 1.27.1` 为本轮唯一可直接升级项。
- `dynamic_color 1.9.0` 为当前 Flutter Material API 的兼容线；2.x 主题类型迁移另立任务。
- Android：AGP 9.3.1、Gradle 9.5.0、Google Services 4.5.0、SDK 37、JDK 17 字节码；版本组合遵循 AGP 9.3 官方默认基线。
- Git、本地路径和 Native Assets 依赖继续锁定完整提交或仓库快照，发布构建使用 lockfile。

## 质量门禁

最终上游整合源码 `b1d61b27` 已完成本地完整门禁：

- Flutter Analyze：0 issue（323.8 秒）；
- 单元与 Widget 测试：224/224 通过；
- 公开接口探测：26/26 通过，覆盖 Bilibili、Douyu、Huya、Kuaishou、Douyin、网易 CC、Twitch 与 SOOP Live；
- Built-in Kotlin、构建策略、设备 UI 地图、锁文件与变更文件格式检查全部通过；
- 完整门禁耗时 557.633 秒，重型进程峰值内存 5.97 GiB、峰值 CPU 17.27%、结束后活跃重型进程为 0；
- 记录：`local-artifacts/build-records/20260822T193705756Z-quality-full.json`。

## 串行构建与产物

各平台严格按 Android → Windows → Linux → macOS → iOS 串行执行；最终同步上游 `c3ae29bb` 后涉及公共播放器代码，因此五个平台均从同一最终代码树 `56275967` 重新构建。Android、Linux、macOS 与 iOS 的工作流每轮只启用一个目标平台，Windows 使用本机 Release 构建。此前 iOS 首轮暴露的 Xcode 26 隐式引擎 registrar 可选值错误已由 `609e8345` 修复并纳入最终构建。

| 平台 | 产物 | SHA-256 | 来源/记录 |
|---|---|---|---|
| Android arm64-v8a | `PureLive-2.6.0-4076-arm64-v8a-release.apk` | `704f7a873905b2d8d89f66b347a128562f6ea0c2ac9f7e9421ef12c4dd230e77` | `56275967`；[Actions 32594370391](https://github.com/wzgrx/pure_live/actions/runs/32594370391)；正式 RSA-4096 签名，包名 `com.mystyle.purelive`，仅含 `arm64-v8a` |
| Windows x64 | `PureLive-2.6.0-windows-x64-setup.exe` | `693a8dba51ca825780309098605c3622724c467e37d23d472847aa35cee3559c` | `56275967`；本机 Inno Setup，可选安装目录 |
| Windows x64 | `PureLive-2.6.0-4076-windows-x64-portable.zip` | `b08258dbf747c7aaae5030669d63a1653f60abb251c95de920403db2c51a28b0` | `56275967`；`20260822T195209357Z-build-windowsx64-release.json` |
| Linux x64 | `PureLive-2.6.0-4076-linux-x64.tar.gz` | `4ba6a34c7f7d0d67b244af9d269f4ffe07185953ff4e4f73e57820402bb6b3d5` | `56275967`；[Actions 32595365876](https://github.com/wzgrx/pure_live/actions/runs/32595365876) |
| macOS Universal | `PureLive-2.6.0-4076-macos-universal.dmg` | `073026d33e50515b8f1ca68fddba609403ba445378924b5a28d2bfd9cfd7380d` | `56275967`；[Actions 32595637310](https://github.com/wzgrx/pure_live/actions/runs/32595637310) |
| macOS Universal | `PureLive-2.6.0-4076-macos-universal.zip` | `c6508e80e82b5286a1491b7b0ed09a5cb2d509efe2ed32fc4b40f6358ba1328c` | 同上 |
| iOS arm64 | `PureLive-2.6.0-4076-ios-arm64-unsigned-app.zip` | `e5c888f248da2b3cb9c8f10343494b9e91fcc4246f611fdd862dadbf04349b45` | `56275967`；[Actions 32596143257](https://github.com/wzgrx/pure_live/actions/runs/32596143257) |
| iOS TrollStore | `PureLive-2.6.0-4076-ios-arm64-trollstore.ipa` | `099756d50f7f82cb01dd5db202f59b56099628bdba6b98960c496d461dd9f564` | 同上；工作流完成临时签名与 IPA 结构验证 |

Android 使用 `apksigner` 复核 v2 签名、版本名和 ABI；全部远端产物侧车校验通过，Linux 归档包含主程序，macOS/iOS 归档包含完整 `.app` 结构。Windows Release 冷启动后进行了 372.339 秒、37 个采样点的隔离实例烟雾测试：工作集从 307,494,912 B 到 304,701,440 B，私有字节减少 20,561,920 B，CPU 累计仅增加 2.125 秒，未出现随时间持续增长；记录为 `20260822T195317241Z-windows-release-smoke.json`。

## 已知平台边界

- 斗鱼历史醒目留言缺少已验证的稳定公开回补入口；进入直播间后的实时 SC、自动过期与切房隔离已覆盖。
- iOS 无签名设备归档供自行签名或 TrollStore 使用；播放器默认策略只作用于新配置，尊重已有用户选择。
- 外部直播接口会随平台变化；脚本结果记录的是发布时点状态，并保留失败平台的独立诊断。

相关文档：[近期 Issue 审计](ISSUE_AUDIT_2026_08_23.md) · [依赖与接口审计](DEPENDENCY_AUDIT.md) · [构建与发布](BUILD_AND_RELEASE.md)
