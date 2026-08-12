# Pure Live v2.0.24

本版本在 v2.0.23 小窗弹幕功能基础上，重点完善本机质量门禁、可复现打包、外部接口有效性和数据安全。

## 新增与优化

- 新增 Windows 本机一键质量门禁、Android 分架构 APK、Windows 便携包、EXE 安装包和 SHA-256 校验流程。
- 固定 Flutter 3.44.9、Dart 3.12.2、Git 依赖提交及原生媒体产物，提交 `pubspec.lock`，提高构建可复现性。
- 新增 Bilibili、Douyu、Huya、Kuaishou、Douyin、网易 CC 公开接口探测。
- 移除失效的斗鱼第三方 HTML 签名中转；抖音匿名 Cookie 改为运行时获取，避免硬编码过期值。
- 备份格式升级到 v3，本地导出、Firebase、WebDAV 和 TV 同步默认排除 Cookie 与 WebDAV 凭据。
- 清理仓库中的签名私钥、证书和构建报告；正式 Android 签名改为仓库外部配置。
- 修复播放器、小窗弹幕、直播切换、分享监听、定时器和订阅的资源释放问题。
- GitHub Actions 改为手动兜底并缩短产物保留时间，取消每日定时任务和标签自动构建。

## 下载说明

- Android：按设备架构选择 `arm64-v8a`、`armeabi-v7a` 或 `x86_64` APK。
- Windows：优先下载 `PureLive-2.0.24-windows-x64-setup.exe`，也可使用便携 ZIP。
- `SHA256SUMS.txt` 可用于校验下载文件完整性。

Android APK 使用此仓库专用的发布签名。若设备上已有其他签名来源的同包名应用，需要先备份应用数据再安装本版本。本机构建未配置发布密钥时会生成包名为 `com.mystyle.purelive.qa` 的 QA 包，可与正式版并存，不作为正式 Release 附件。
