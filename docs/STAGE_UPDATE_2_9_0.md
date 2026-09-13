# v2.9.0 全平台稳定版

版本：`2.9.0+4079`
维护仓库：`liuchuancong/pure_live`
上游基线：`liuchuancong/pure_live@25f833ea`
发布日期：2026-08-23

## 本轮范围

- 合并上游从录制页返回直播时的视频层延迟挂载修复与发布资产命名调整。
- 修复竖屏、横屏清晰度及线路切换失效、控制器销毁竞争和异步选择覆盖。
- 重构横屏顶部控制区、清晰度/线路面板和直播记录双栏卡片。
- 增加跨横屏、竖屏、小窗和设置页同步的本地弹幕样式配置。

## 质量门禁

- Flutter Analyze：0 issue，耗时 1600.2 秒。
- 单元/Widget 测试：243/243 通过。
- 公开接口探测：27/27 通过。
- 完整门禁记录：`local-artifacts/build-records/20260823T132344885Z-quality-full.json`；总耗时 2937.492 秒，峰值 CPU 47.46%，峰值工作集 10.66 GB。
- Windows Release 记录：`local-artifacts/build-records/20260823T141351137Z-build-windowsx64-release.json`；保留增量目录，总耗时 1355.431 秒，完成后活跃重型进程为 0。

## 发布产物

| 平台 | 产物 | SHA-256 | 来源/记录 |
|---|---|---|---|
| Android arm64-v8a | `PureLive-2.9.0-4079-android-arm64-v8a-release.apk` | `05362a20944821d7f882821e634f8e6bfa2c1d5111d1be6b902d447dc4a75795` | 正式签名任务 `32642419843` |
| Windows x64 | `PureLive-2.9.0-4079-windows-x64-setup.exe` | `9e50f3d481f56c7f3e92e48d19042887422e20880ce27c8f1bed231153fd0d52` | 本机 Release，安装目录可选 |
| Windows x64 | `PureLive-2.9.0-4079-windows-x64-portable.zip` | `8cdf34f014f455c9e187c61eb14d5e36418ba4f3aaa712da6e06b7d74572b6cc` | 本机 Release，无运行时数据目录与调试文件 |
| Linux x64 | `PureLive-2.9.0-4079-linux-x64.tar.gz` | `2275316aa89e3ecb8de69b42a42851a95fded1715b7230166ff46858ccd2ca75` | 托管阶段任务 `32644880532` |
| macOS Universal | `PureLive-2.9.0-4079-macos-universal.dmg` | `47ba00e99f91c884e95e7ead9ec494699a142956ddc79ccb9480b7f3cd8bff73` | 托管阶段任务 `32644880532` |
| macOS Universal | `PureLive-2.9.0-4079-macos-universal.zip` | `21d3b9a5ff8f1d1714308cb5c7cdf1efa5ae4f7d9a50175bdd59c6cfddc7e1d9` | 托管阶段任务 `32644880532` |
| iOS arm64 | `PureLive-2.9.0-4079-ios-arm64-unsigned-app.zip` | `404d7622c01b1c95062a434045c36c1c433405ce7732e088be789787d802e44d` | 托管阶段任务 `32644880532` |
| iOS arm64 | `PureLive-2.9.0-4079-ios-arm64-trollstore.ipa` | `5374d4d142a64361f15b59931dc58eeda826c63fd09f173048625ed2853e3b00` | ad-hoc 签名并通过严格验证 |

## 发布一致性

- 标签 `v2.9.0` 与全部平台产物共同指向源码提交 `939fecc2203c98f3eed83e98a8df95b9aa53bd1f`。
- Android 包名为 `com.mystyle.purelive`，仅包含 `arm64-v8a`；发布汇总任务使用 `apksigner` 验证正式签名与证书信息。
- Windows 安装包与便携包来自同一干净提交；便携归档不包含 `AppData`、`IPTV_CACHE`、PDB、EXP、LIB 或 ILK。
- Linux、macOS 与 iOS 串行完成构建；发布汇总任务 `32646192843` 逐项校验来源 Run、归档结构和 SHA-256 后发布。
- 正式 Release 附带统一 `SHA256SUMS.txt` 与 `BUILD_METADATA.json`，平台来源提交均为标签提交。
