# v2.9.0 全平台稳定版

版本：`2.9.0+4079`
维护仓库：`wzgrx/pure_live`
上游基线：`liuchuancong/pure_live@25f833ea`
发布日期：2026-08-23

## 本轮范围

- 合并上游从录制页返回直播时的视频层延迟挂载修复与发布资产命名调整。
- 修复竖屏、横屏清晰度及线路切换失效、控制器销毁竞争和异步选择覆盖。
- 重构横屏顶部控制区、清晰度/线路面板和直播记录双栏卡片。
- 增加跨横屏、竖屏、小窗和设置页同步的本地弹幕样式配置。

## 质量门禁

- Flutter Analyze：发布源码冻结后记录。
- 单元/Widget 测试：发布源码冻结后记录。
- 公开接口探测：发布源码冻结后记录。
- 构建记录：写入 `local-artifacts/build-records/`，并在产物完成后补充。

## 发布产物

| 平台 | 产物 | SHA-256 | 来源/记录 |
|---|---|---|---|
| Android arm64-v8a | 构建后补充 | 构建后补充 | 正式签名 |
| Windows x64 | 构建后补充 | 构建后补充 | 本机 Release |
| Linux x64 | 构建后补充 | 构建后补充 | GitHub 托管 Linux 阶段 |
| macOS Universal | 构建后补充 | 构建后补充 | GitHub 托管 Apple 阶段 |
| iOS arm64 | 构建后补充 | 构建后补充 | unsigned app 与 TrollStore IPA |

## 发布一致性

- 所有产物必须来自同一个 `v2.9.0` 标签提交。
- Android 包名保持 `com.mystyle.purelive`，仅声明实际发布的 `arm64-v8a`。
- Windows 安装包与便携包不得包含用户运行时数据或原生调试文件。
- 每个平台独立校验归档结构和 SHA-256，最终 Release 附带统一 `SHA256SUMS.txt` 与 `BUILD_METADATA.json`。
