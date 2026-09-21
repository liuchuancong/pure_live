# Bigo Web 媒体接入检查点（2026-09-21）

## 本轮结论

本轮把旧的“无令牌房间元数据”阶段推进到当前官网 Web token 与受保护 HLS 编解码核心：

- `BigoTokenCodec` 复现 OpenSSL `Salted__`、MD5 `EVP_BytesToKey`、AES-256-CBC/PKCS#7 数据封装。
- `BigoApi.studioRoom` 依次读取 `/v1/webjs/t` 与 `/v1/webjs/status`，再把短期 token 放入房间接口查询参数；token 只存在于请求作用域。
- 房间响应分别保留公开/登录门槛/受限、直播状态、房间身份与 HLS；门槛响应中的 `alive=0` 继续保持未知，不冒充下播。
- `BigoHlsProtection` 读取 `EXT-X-BIGO-WEB-PROTECTION:SEED`，只转换前两个 188 B MPEG-TS 包各自的前 16 B；无标签的普通 HLS 不经过该转换。

这些实现对照 [Streamlink 当前 Bigo 插件](https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/bigo.py)与其 [OpenSSL 兼容加密实现](https://github.com/streamlink/streamlink/blob/master/src/streamlink/utils/crypto.py)。Streamlink 当前也在每个媒体分片读取阶段应用相同的两包前缀转换，因此应用层需要在私有 HLS relay 内交付转换后的字节，而不是把官网 HLS 地址直接交给 native 播放器。

## 生产探测

本机通过 Clash 读取官网有限目录，得到 20 行；当前首行 token 流程三步均成功：时间戳、54 字符 token、房间接口均返回成功，房间 `alive=1`、`needLogin=false` 且带 `hls_src`。媒体 authority 使用 `*.cubetecn.com:1453`。本机 Schannel、Python OpenSSL 以及 Clash CONNECT 三条读取路径都在该非标准端口 TLS 握手阶段收到 EOF，因此本轮没有取得清单与分片原件，也没有把“房间接口返回 URL”记作 native 播放证据。

独立确定性向量已验证：固定 salt/nonce 的 Dart token 输出与 Node/OpenSSL AES-256-CBC 输出逐字节一致；固定 seed 的两组 16 B 掩码与当前 Streamlink 算法一致，重复转换恢复 `0x47` TS 同步字节。

## 当前边界与下一步

1. 给 `FFmpegHlsInputRelay` 增加有界媒体前缀转换钩子，同时覆盖流式播放、完整 body 暂存和录制预取路径。
2. 用脱敏夹具验证清单标签到每个分片 seed 的绑定，禁止 seed 跨清单/代次复用。
3. 接入 Bigo owned input、恢复与录制绑定，再补链接解析、有限目录、精确 ID 搜索、能力声明、迁移和应用注册。
4. 原生验收批次再验证 Windows/Android 的实际播放、切源、停止与录制；本检查点只代表源码核心与 Web token 合同。

## 验证记录

- 3 个生产 Dart 文件与 2 个 Bigo 测试文件定向 Analyze：无问题。
- 固定 token/分片向量的独立 Dart 探针：通过。
- Bigo 两个测试文件启动时，Windows native-assets hook 发现本地 FFmpeg bundle 缓存目录缺失并在测试加载前退出；未把这次基础设施失败计为测试通过，完整测试留到平台源码批次后的集中门禁。
- 未执行构建、安装、ADB 或设备操作。
