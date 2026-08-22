# v2.6.0 阶段稳定版

版本：`2.6.0+4076`
维护仓库：`wzgrx/pure_live`
上游基线：`liuchuancong/pure_live@db3460f8`
发布日期：2026-08-23

## 本阶段范围

1. 真实合并上游的关注刷新、房间详情补全、版本历史容错和弹幕模板改动。
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
- Windows 小窗位置、大小与主窗口几何独立保存；多显示器变化时把旧矩形校正到仍可见的工作区。

## 依赖审计

- Dart/Flutter：`scrollview_observer 1.27.1` 为本轮唯一可直接升级项。
- `dynamic_color 1.9.0` 为当前 Flutter Material API 的兼容线；2.x 主题类型迁移另立任务。
- Android：AGP 9.3.1、Gradle 9.5.0、Google Services 4.5.0、SDK 37、JDK 17 字节码；版本组合遵循 AGP 9.3 官方默认基线。
- Git、本地路径和 Native Assets 依赖继续锁定完整提交或仓库快照，发布构建使用 lockfile。

## 质量门禁

同一源码冻结点已完成本地完整门禁：

- Flutter Analyze：0 issue（295.7 秒）；
- 单元与 Widget 测试：223/223 通过；
- 公开接口探测：26/26 通过，覆盖 Bilibili、Douyu、Huya、Kuaishou、Douyin、网易 CC、Twitch 与 SOOP Live；
- Built-in Kotlin、构建策略、设备 UI 地图、锁文件与变更文件格式检查全部通过；
- 完整门禁耗时 560.057 秒，重型进程峰值内存 7.44 GiB、峰值 CPU 18.21%、结束后活跃重型进程为 0；
- 记录：`local-artifacts/build-records/20260822T180054267Z-quality-full.json`。

Android arm64、Windows x64、Linux x64、macOS Universal 与 iOS arm64 的产物、SHA-256 和来源提交在平台串行构建结束后补入本节。

## 已知平台边界

- 斗鱼历史醒目留言缺少已验证的稳定公开回补入口；进入直播间后的实时 SC、自动过期与切房隔离已覆盖。
- iOS 无签名设备归档供自行签名或 TrollStore 使用；播放器默认策略只作用于新配置，尊重已有用户选择。
- 外部直播接口会随平台变化；脚本结果记录的是发布时点状态，并保留失败平台的独立诊断。

相关文档：[近期 Issue 审计](ISSUE_AUDIT_2026_08_23.md) · [依赖与接口审计](DEPENDENCY_AUDIT.md) · [构建与发布](BUILD_AND_RELEASE.md)
