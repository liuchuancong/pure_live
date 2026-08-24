# v2.9.4 全平台稳定版

版本：`2.9.4+4083`  
维护仓库：`wzgrx/pure_live`  
上游基线：`liuchuancong/pure_live@d7be9cf8`  
发布日期：2026-08-24

## 本轮范围

- 合并上游多画面同看、播放器结构整理和依赖锁更新，保持与上游共同祖先关系。
- 修复录制目录误删和容量限额无界循环；自定义位置使用专用子目录和所有权标记。
- 修复快手直播/录播数据形状差异，增加播放结构接口探测。
- 合并斗鱼/抖音纯 Dart 签名迁移；修复斗鱼加密缓存时间单位、并发刷新和抖音请求参数副作用。
- 加固多画面播放器释放、音频焦点、移动端解码上限、调试日志、EPG 缓存与跨房间失败回退。
- 直接依赖和固定 Git 引用全部重新核验；详细结论见 `DEPENDENCY_AUDIT.md`。

## 近期 Issue

- #778：源码复现并完整修复；测试证明公共父目录内的其他文件保持不变。
- #780：最新上游已彻底移除斗鱼/抖音 JS 运行时，签名改为纯 Dart；Linux 不再加载该原生插件。
- #782：真实接口确认推荐列表混合回放；应用同时支持房间页与列表播放结构。
- #779：属于跨平台图标/TV Banner 资源工程，列入独立视觉版本。

完整记录见 `ISSUE_AUDIT_2026_08_24.md`。

## 质量门禁

发布提交完成后记录以下证据：

- Flutter Analyze：待正式门禁回填。
- 单元/Widget 测试：待正式门禁回填。
- 公开接口探测：待正式门禁回填。
- 完整门禁记录：待正式门禁回填。
- Android/Windows 本机构建记录：待正式构建回填。
- Linux/macOS/iOS 托管构建任务：待正式构建回填。

## 发布产物

| 平台 | 目标产物 | 架构/说明 |
|---|---|---|
| Android | `PureLive-2.9.4-4083-android-arm64-v8a-release.apk` | arm64-v8a，仓库正式证书签名 |
| Windows | `PureLive-2.9.4-4083-windows-x64-setup.exe` | x64，可选安装目录 |
| Windows | `PureLive-2.9.4-4083-windows-x64-portable.zip` | x64，便携包不含运行时数据 |
| Linux | `PureLive-2.9.4-4083-linux-x64.tar.gz` | x64，Ubuntu 24.04 构建基线 |
| macOS | `PureLive-2.9.4-4083-macos-universal.zip` / `.dmg` | Universal |
| iOS | `PureLive-2.9.4-4083-ios-arm64-unsigned-app.zip` / `trollstore.ipa` | arm64 |

## 验证边界

- 本轮按源码、确定性测试、公开接口探测、Windows 本机运行采样和各平台构建证据验收。
- 本轮未执行 ADB、安装手机 APK 或自动化手机界面操作；设备验收由用户下载正式 Android 资产后独立进行。
- 外部直播、弹幕和 CDN 状态随平台变化，应用通过有界重试、房间代次和明确失败状态避免旧结果污染当前会话。

返回 [文档索引](README.md)。
