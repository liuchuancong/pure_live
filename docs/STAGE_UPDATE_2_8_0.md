# v2.8.0 阶段稳定版

版本：`2.8.0+4078`
维护仓库：`wzgrx/pure_live`
上游基线：`liuchuancong/pure_live@4ca626d9`
发布日期：2026-08-23

## 本轮范围

- 合并上游抖音搜索、恢复关注刷新、Windows PiP 几何校验、RTX VSR 可选项与结构整理。
- 修复关注页手动下拉、前台恢复和请求失败后的陈旧开播状态，保持逐平台列表稳定。
- 加固抖音匿名搜索回退、Cookie 生命周期、分页、房间身份和备用接口。
- 修复横屏/全屏弹幕设置面板固定夜间样式，完整继承全局浅色、深色与跟随系统主题。
- 继续覆盖 Windows 高 DPI 视频纹理限幅、播放器资源释放、弹幕/PiP/横竖屏生命周期与长时间运行稳定性。

## 质量门禁

- Flutter Analyze：0 issue（发布源码修改完成后仅执行 1 次）。
- 单元/Widget 测试：236/236 通过；包含关注权威刷新、抖音搜索、弹幕/PiP 生命周期、播放器切换、Windows 视口纹理和旧配置迁移。
- 公开接口探测：27/27 通过。
- 质量记录：`local-artifacts/build-records/20260823T064043566Z-quality-focused.json`、`local-artifacts/build-records/20260823T064708611Z-quality-full-tests-only.json`。

## 发布产物

| 平台 | 产物 | SHA-256 | 来源/记录 |
|---|---|---|---|
| Android arm64-v8a | `PureLive-2.8.0-4078-arm64-v8a-release.apk` | `281c8b56e48a0395ab0add5e6facf2c57e235053144fef5dff78305535b79479` | 本机编译记录 `20260823T080507194Z-build-androidarm64-release.json`；正式签名任务 `32627517369` |
| Windows x64 | `PureLive-2.8.0-windows-x64-setup.exe` | `910e6e225d81f46562ffaa9aadafe9a6c24e1dc421c5cac8bd1aacaeae9bcfa9` | 本机 Release 记录 `20260823T084050619Z-build-windowsx64-release.json` |
| Windows x64 | `PureLive-2.8.0-4078-windows-x64-portable.zip` | `84d67004e4e3334402e0852fe1562903f9a419fb3f283c0bbd78e19078ed88db` | 1,304 个归档条目；无调试文件和运行时数据目录 |
| Linux x64 | `PureLive-2.8.0-4078-linux-x64.tar.gz` | `49e40f7cc9c82a530b67bccc2d72c67347bac68673718a5599499c489204a7bc` | 构建任务 `32630964172`；结构/校验暂存任务 `32631923619` |
| macOS Universal | `PureLive-2.8.0-4078-macos-universal.dmg` | `08e95cbdc36a09a99535c5a028683c32fd2602377f6df13137badc5b2d0e4fd2` | 构建任务 `32631993139`；结构/校验暂存任务 `32632491955` |
| macOS Universal | `PureLive-2.8.0-4078-macos-universal.zip` | `f66366989226af8692d6f6bb591ce47d41009c6aa017277eb3010c24f72e4515` | 同上 |
| iOS arm64 | `PureLive-2.8.0-4078-ios-arm64-unsigned-app.zip` | `c13279f7cf182eb4b25643a8fe248207224d5a7277c4cf164ba0f9cca50f3e50` | 构建任务 `32632536806`；签名/结构/校验暂存任务 `32632982360` |
| iOS arm64 | `PureLive-2.8.0-4078-ios-arm64-trollstore.ipa` | `8a5afb18ef36bf98494b546f0420d41f41fc3aada9c78fb181eccc340e915777` | ad-hoc 签名并通过 `codesign --verify --deep --strict` |

## 发布一致性

- 全部客户端产物均来自标签 `v2.8.0` 指向的源码提交 `1aa5b46aad7c791512bda14f2d8b811404392650`。
- Android 包名为 `com.mystyle.purelive`，`versionName=2.8.0`、`versionCode=6078`，仅含 `arm64-v8a`；正式证书 SHA-256 为 `c0bb95744c81f9c7dd4535a9552775038eb5a59c5922f791d1695f45ac34ceaf`。
- Windows 安装包产品版本为 `2.8.0`，主程序版本为 `2.8.0+4078`；便携包包含应用和 Flutter 资源，不包含 PDB/EXP/LIB/ILK、`AppData` 或 `IPTV_CACHE`。
- Linux、macOS 与 iOS 构建按平台串行执行；每批产物在 GitHub 内部复核来源提交、SHA-256 和归档结构后才进入草稿 Release。
- Release 同时提供各平台单独校验文件、汇总 `SHA256SUMS.txt` 与 `BUILD_METADATA.json`。
