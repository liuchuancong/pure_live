# Pure Live v3.1.0 Android / Windows 阶段更新

版本：`3.1.0+4113`  
维护仓库：`wzgrx/pure_live`  
源码基线：继续使用维护分支现有上游基线，本轮没有合并新的上游提交。  
交付平台：Android `arm64-v8a`、Windows x64 安装程序与便携 ZIP；其他平台保持已有版本。

## 1. 本轮目标

v3.1.0 汇总 v3.0.24 之后已经完成的稳定性修复、设备验证和发布门禁增强，重点解决后台策略与音频模式冲突、Bilibili 弹幕畸形帧造成的停滞风险，以及代理开启后不同网络组件行为不一致的问题。源码、详细说明和两个维护平台的安装包由同一提交串行生成。

## 2. 后台播放、音频模式与助眠

- 根因：手动纯音频原先被后台策略当成独立保活授权，即使用户关闭“后台播放”，生命周期协调器和 Android 原生 keep-alive 仍会继续播放。
- 修复：手动纯音频只负责当前房间的画面/流量模式；后台继续播放只由后台总开关或用户已经启动的定时助眠会话决定。
- 系统 PiP 仍是用户主动进入的紧凑播放形态，不和普通退后台混为一谈。
- Android 16 实机覆盖后台开关开/关、普通视频、纯音频、系统 PiP 与 1 分钟自动助眠；到点后媒体会话和 Pure Live 保活锁均释放。

## 3. 弹幕协议稳定性

- Bilibili WebSocket 一条消息内的多包、zlib/Brotli 嵌套包继续逐帧解析。
- 对传输大小、解压输出、每条消息帧数和压缩嵌套深度增加硬边界；长度为 0、越界、截断或压缩放大的输入只丢弃当前消息，不形成死循环或无限内存增长。
- 完整富用户名优先于平台返回的掩码名，同时保留完整旧字段作为回退。
- Huya 当前公开房间协议探针完成 WebSocket 101、分组注册、心跳并收到 command 22；弹幕连接和其他平台共用统一 WebSocket 生命周期。

## 4. 代理与网络一致性

- 平台 API、封面/头像缓存和所有平台弹幕 WebSocket 统一读取“应用代理”；播放器媒体流仍由独立“播放器代理”控制。
- 中文输入法产生的全角句号、冒号和方括号会在输入与配置导入时归一化，`127。0。0。1` 不再被错误交给 DNS。
- 空主机、越界端口和指令注入保持直连；WebSocket Upgrade 完成后释放握手客户端的空闲资源。
- Android Debug 已验证虎牙目录、封面、头像和代理地址输入；协议与确定性回归覆盖代理开关和重连。

详细根因和证据见 [`NETWORK_PROXY_AUDIT_3_1_0.md`](NETWORK_PROXY_AUDIT_3_1_0.md)。

## 5. 启动、构建与验收门禁

- 启动初始化等待设置服务注册完成，避免首次安装或升级后首帧先构建、设置服务后注册的白屏/多次启动竞态。
- Android UI 自动化点位和序列增加版本校验、启动稳定等待与控制层确定性唤出。
- APK 验证进一步检查唯一 ABI、Manifest 实际 `versionCode`、Flutter 资源、FFmpegKit、SQLite、MediaKit 与应用原生库，不再只凭文件名或安装成功判定产物完整。
- 完整功能账本、近期 Issue 归因和参考录制项目审计分别见：
  - [`ACCEPTANCE_MATRIX_3_1_0.md`](ACCEPTANCE_MATRIX_3_1_0.md)
  - [`ISSUE_AUDIT_2026_08_31.md`](ISSUE_AUDIT_2026_08_31.md)
  - [`RECORDER_REFERENCE_AUDIT_3_1_0.md`](RECORDER_REFERENCE_AUDIT_3_1_0.md)

冻结提交 `3e4cdbeb` 的完整质量门禁耗时 924.527 秒：Analyze 只执行一次且为 0 issue，完整 Flutter 回归 667/667，公开接口探针 42/42，全仓审计覆盖 3884 个文件且为 0 error。记录：`local-artifacts/build-records/20260831T032317652Z-quality-full.json`。

## 6. 安装包与升级

- Android：正式 `arm64-v8a` APK，包名保持 `com.mystyle.purelive`；split ABI Manifest code 在基础 build 4113 上按 Flutter 规则增加 arm64 偏移。
- Windows：x64 可选目录安装程序和便携 ZIP；安装程序继续允许选择非系统盘，便携包数据策略见 [`WINDOWS_DATA_AND_UPGRADE.md`](WINDOWS_DATA_AND_UPGRADE.md)。
- 覆盖升级前建议通过应用内备份导出关注、历史和设置；签名证书不同的旧 APK 仍需按 Android 系统规则处理。
- 产物文件名、大小、SHA-256、构建耗时和源码提交在最终构建后写入 Release 附件中的 `BUILD_METADATA.json`、`WINDOWS_BUILD_METADATA.json`、`SHA256SUMS.txt` 与 `WINDOWS_SHA256SUMS.txt`。

## 7. 验证边界

确定性测试、公开接口探针、构建完整性和设备/桌面采样是独立证据层。平台临时风控、账号区域限制、主播下播和 CDN 波动仍可能改变实时结果；Release 说明记录已执行范围与剩余观察项，不把单次接口成功描述为所有房间长期稳定。
