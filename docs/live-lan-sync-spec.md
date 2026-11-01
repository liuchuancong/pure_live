# live_lan_sync 局域网数据同步引擎开发规范

> **文档类型**：完整技术设计与开发实施规范\
> **项目归属**：PureLive Workspace\
> **Package 名称**：`live_lan_sync`\
> **建议路径**：`packages/live_lan_sync`\
> **定位**：可配置、可插拔、与业务无关的 Flutter / Dart
> 局域网设备发现及数据同步公共模块\
> **目标平台**：Android、iOS、Android TV、Windows、macOS、Linux\
> **文档状态**：开发基线\
> **适用对象**：开发人员、AI 编程助手、代码审查人员

------------------------------------------------------------------------

# 1. 文档目的

本文档定义 `live_lan_sync` 的产品边界、架构、模块职责、公共
API、配置体系、网络协议、数据模型、安全要求、平台适配、测试标准和分阶段实施流程。

开发人员必须以本文档作为实现依据。不得只实现一个 mDNS 设备扫描器或 HTTP
文件传输器，就将其视为完整的局域网同步系统。

本 Package 应当能够独立于 PureLive 使用。PureLive
是第一个接入方，但不是它唯一支持的应用。

## 1.1 核心目标

构建一套可复用的局域网同步引擎，使多个应用实例能够在用户授权后：

-   发现局域网内的其他设备。
-   手动添加无法自动发现的设备。
-   安全地配对和管理可信设备。
-   建立双向网络通信。
-   交换同步能力、数据清单和版本信息。
-   执行单向推送、单向拉取和双向同步。
-   执行增量同步和重复请求去重。
-   检测并处理并发修改冲突。
-   同步删除操作，防止已删除数据重新出现。
-   传输图片、字体、壁纸等资源文件。
-   支持文件分块、断点续传、校验和取消。
-   提供任务状态、进度、事件、错误和历史信息。
-   允许宿主应用配置服务参数、同步策略、存储实现和业务适配器。

## 1.2 非目标

第一阶段不实现以下能力：

-   公有云同步服务。
-   账号体系或云端用户认证。
-   互联网中继服务器。
-   NAT 穿透。
-   远程控制其他设备。
-   设备屏幕投射。
-   DLNA、Google Cast、AirPlay、Miracast。
-   任意目录共享或远程文件系统。
-   数据库文件直接复制。
-   自动同步所有宿主应用数据。
-   默认后台常驻和操作系统级后台调度。

未来可以扩展其他传输方式，但不得因此将首期架构设计得过度复杂。

------------------------------------------------------------------------

# 2. Package 定位与工作区归属

## 2.1 所属位置

`live_lan_sync` 必须放在 PureLive Workspace 的 `packages/` 下：

``` text
pure_live/
├── apps/
│   └── pure_live/
│       └── lib/
│           ├── app/
│           └── features/
│               └── lan_sync/
│                   ├── presentation/
│                   ├── providers/
│                   ├── pages/
│                   └── lan_sync_feature.dart
│
├── packages/
│   ├── live_lan_sync/
│   │   ├── lib/
│   │   ├── test/
│   │   ├── analysis_options.yaml
│   │   └── pubspec.yaml
│   ├── live_net/
│   ├── live_storage/
│   ├── live_platform/
│   ├── live_websocket/
│   └── ...                  # 新增 live_lan_sync 后须登记进根 pubspec.yaml 的 workspace 列表
│
└── pubspec.yaml             # Dart pub workspace 根：workspace 成员列表、共享 pubspec.lock、
│                              # dependency_overrides 与 melos 脚本（melos 8.9 为 dev 依赖，
│                              # 经根 pubspec 的 `melos:` 段配置，不存在独立 melos.yaml）
```

## 2.2 职责边界

  ----------------------------------------------------------------------------------------------------------
  模块                                职责
  ----------------------------------- ----------------------------------------------------------------------
  `live_lan_sync`                     通用设备发现、配对、安全通信、数据同步、冲突处理、文件传输、任务管理

  `features/lan_sync`                 PureLive 同步页面、设备管理 UI、同步设置 UI、业务适配器注册

  `live_storage`                      宿主应用已有的存储基础设施；是否复用由接入层决定

  `live_net`                          可复用的通用网络能力；不得把同步协议塞入其中

  `media_core_cast_dlna`              DLNA 投屏（位于外部播放栈 `F:\media_core\packages`，经依赖引入，不在本工作区 `packages/` 内），与本 Package 无业务依赖

  业务 Feature                        提供可同步的数据和文件资源适配器
  ----------------------------------------------------------------------------------------------------------

## 2.3 依赖方向

允许：

``` text
PureLive Feature
      │
      ▼
live_lan_sync
      │
      ├── Dart / Flutter 基础能力
      ├── 可选网络适配依赖
      ├── 可选加密依赖
      └── 宿主注入的 Store / Adapter
```

禁止：

-   `live_lan_sync` 导入 `apps/pure_live`。
-   `live_lan_sync` 引用 PureLive 的收藏、直播间、播放列表等业务模型。
-   `live_lan_sync` 依赖 `media_core_cast_dlna`。
-   `live_lan_sync` 直接访问 PureLive 的 Hive Box。
-   `live_lan_sync` 直接读取宿主应用的任意文件目录。
-   `live_lan_sync` 依赖 UI 层或 Riverpod Provider。
-   `live_lan_sync` 将具体业务数据库作为强制依赖。

## 2.4 是否拆分通用同步核心

第一阶段只创建 `live_lan_sync` 一个 Package，在内部保持清晰分层。

暂时不创建 `live_sync_core`、`live_sync_protocol` 等多个小
Package，避免过早拆分和增加维护成本。

当未来确实出现云同步、蓝牙同步或其他传输后端，并且需要复用同一套同步领域引擎时，再评估抽取
transport-independent sync core。

------------------------------------------------------------------------

# 3. 设计原则

## 3.1 通用性

Package
不得知道宿主应用的业务含义。它只处理通用同步实体、变更、版本、游标、冲突和文件资源。

## 3.2 可配置

以下内容不得硬编码：

-   服务名称。
-   mDNS 服务类型。
-   监听地址和端口。
-   设备名称。
-   设备平台标识。
-   协议版本。
-   发现间隔。
-   连接超时。
-   配对有效期。
-   文件分块大小。
-   传输并发数。
-   单批次变更数量。
-   数据范围。
-   冲突策略。
-   存储实现。
-   日志行为。

## 3.3 依赖注入

网络服务、存储、身份凭据、安全实现、时钟和 ID
生成器应通过构造参数或接口注入。

不使用全局单例。

## 3.4 对等节点

设备采用 Peer-to-Peer
对等模式。每个已授权设备都可以发起或接受同步，不设置永久主设备。

对等不意味着所有设备必须同时监听服务。移动平台可在前台运行期间提供服务。

## 3.5 传输与同步分离

设备发现、网络传输、数据同步、文件传输是不同职责。

mDNS 发现成功不代表已配对；HTTP
连接成功不代表有同步权限；文件传输成功不代表业务数据已经提交。

## 3.6 正确性优先

同步系统必须优先保证：

1.  不丢失已提交变更。
2.  不重复应用同一变更。
3.  不提前推进游标。
4.  不静默覆盖并发修改。
5.  不因网络中断造成数据半提交。
6.  不将损坏文件标记为成功。

------------------------------------------------------------------------

# 4. 总体能力模型

``` text
                       live_lan_sync
                              │
       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
       ▼                      ▼                      ▼
  Device Discovery       Device Trust            Sync Engine
       │                      │                      │
       │                      │           ┌──────────┼──────────┐
       │                      │           │          │          │
       ▼                      ▼           ▼          ▼          ▼
   mDNS / QR             Pairing       Change Log  Conflict   Cursor
   Manual IP             Identity      Manifest    Resolver   Checkpoint

       ┌──────────────────────┼──────────────────────┐
       │                      │                      │
       ▼                      ▼                      ▼
  HTTP Transport        WebSocket Events        File Transfer
       │                      │                      │
       ▼                      ▼                      ▼
  Secure Requests       State Notifications     Chunk / Resume
```

## 4.1 子系统

  子系统              主要职责
  ------------------- ----------------------------------------
  Configuration       参数、默认值、配置校验
  Device Identity     本机稳定身份
  Discovery           mDNS、手动地址、设备上下线
  Pairing             配对挑战、信任建立、撤销
  Device Registry     已配对设备及权限
  Secure Session      身份验证和加密会话
  Transport           HTTP、WebSocket
  Protocol            请求、响应、版本协商
  Sync Engine         Manifest、Change Log、Cursor、批次调度
  Conflict Resolver   并发修改识别与策略执行
  File Transfer       文件清单、分块、续传、校验
  Task Manager        任务状态、暂停、恢复、取消
  Persistence         同步元数据存储
  Observability       日志、事件、诊断信息

------------------------------------------------------------------------

# 5. Package 目录结构

采用分层结构，但不要为了形式创建大量空目录和空文件。目录在对应阶段真正有实现内容时再创建。

推荐目标结构：

``` text
packages/live_lan_sync/
├── lib/
│   ├── live_lan_sync.dart
│   │
│   └── src/
│       ├── config/
│       │   ├── lan_sync_config.dart
│       │   ├── device_config.dart
│       │   ├── discovery_config.dart
│       │   ├── server_config.dart
│       │   ├── security_config.dart
│       │   ├── synchronization_config.dart
│       │   ├── transfer_config.dart
│       │   └── logging_config.dart
│       │
│       ├── domain/
│       │   ├── device/
│       │   ├── pairing/
│       │   ├── sync/
│       │   ├── conflict/
│       │   ├── transfer/
│       │   ├── protocol/
│       │   └── errors/
│       │
│       ├── application/
│       │   ├── lifecycle/
│       │   ├── discovery/
│       │   ├── pairing/
│       │   ├── devices/
│       │   ├── synchronization/
│       │   ├── conflicts/
│       │   └── transfer/
│       │
│       ├── infrastructure/
│       │   ├── discovery/
│       │   │   └── bonsoir/
│       │   ├── transport/
│       │   │   ├── http/
│       │   │   └── websocket/
│       │   ├── security/
│       │   ├── persistence/
│       │   ├── transfer/
│       │   ├── clock/
│       │   └── identifiers/
│       │
│       └── internal/
│           ├── serialization/
│           ├── validation/
│           └── utilities/
│
├── test/
│   ├── unit/
│   ├── application/
│   ├── protocol/
│   ├── integration/
│   └── fixtures/
│
├── example/                  # 仅在确实需要独立演示 App 时创建
├── README.md
├── CHANGELOG.md
├── analysis_options.yaml
└── pubspec.yaml
```

## 5.1 公共导出约束

`lib/live_lan_sync.dart` 是唯一稳定公共入口。

不得要求宿主导入 `src/`。

公共 API 只导出：

-   配置类型。
-   Client / Facade。
-   稳定领域模型。
-   Adapter 接口。
-   Store 接口。
-   事件和错误类型。
-   枚举与策略类型。

HTTP 内部实现、Bon soir 适配器、序列化细节和数据库实现默认不导出。

------------------------------------------------------------------------

# 6. 配置系统

配置是本 Package
的核心能力之一。必须提供合理默认值、配置校验和运行时可变项。

## 6.1 顶层配置

建议：

``` dart
final config = LanSyncConfig(
  device: LanSyncDeviceConfig(
    deviceId: deviceId,
    deviceName: 'PureLive Desktop',
    platform: 'windows',
    appVersion: '4.0.0',
  ),
  discovery: const LanSyncDiscoveryConfig(),
  server: const LanSyncServerConfig(),
  security: const LanSyncSecurityConfig(),
  synchronization: const LanSyncOptions(),
  transfer: const LanSyncTransferConfig(),
  logging: const LanSyncLoggingConfig(),
);
```

最终字段应经过配置审计后确定，不要在第一版暴露所有内部参数。

## 6.2 DeviceConfig

负责本机公开设备信息：

-   `deviceId`：安装实例的稳定 ID。
-   `deviceName`：用户可修改的显示名称。
-   `platform`：宿主平台标识。
-   `appVersion`：宿主应用版本。
-   `protocolVersion`：同步协议版本。
-   `capabilities`：支持的能力集合。

`deviceId` 不应使用 IP、MAC 地址或硬件序列号。应由宿主持久化生成的随机
ID。

设备名称可以运行时修改，但设备 ID 不应因此变化。

## 6.3 DiscoveryConfig

建议配置：

-   `enabled`。
-   `serviceType`。
-   `scanInterval`。
-   `serviceTtl` 或设备过期时间。
-   `enableManualAddress`。
-   `enableQrPairing`。
-   `preferredNetworkInterfaces`（如确实需要）。
-   `ipv4Enabled` / `ipv6Enabled`（按实现能力提供）。

默认服务类型建议为 `_purelive-sync._tcp`，但必须允许其他应用覆盖。

TXT 记录只能放公开、非敏感元数据，例如设备
ID、协议版本、应用版本和能力摘要。不得放 Token、密码、配对码或私钥。

## 6.4 ServerConfig

建议配置：

-   是否启用本机服务端。
-   监听地址策略。
-   端口；`0` 表示由系统分配可用端口。
-   最大连接数。
-   请求超时。
-   最大请求体大小。
-   最大 WebSocket 消息大小。
-   是否仅允许已配对设备连接。

默认只监听必要的局域网接口，不要默认暴露到所有网络环境。

## 6.5 SecurityConfig

建议配置：

-   是否强制配对。
-   是否强制加密。
-   配对验证码有效期。
-   配对失败最大次数。
-   限流窗口。
-   可信设备撤销策略。
-   证书或公钥指纹校验策略。
-   允许的安全协议版本。

不得提供 `allowUnauthenticatedSync = true`
这样的正式生产开关。测试环境可使用显式测试替身，不应降低生产安全默认值。

## 6.6 SynchronizationConfig

建议配置：

-   是否启用增量同步。
-   单批次变更数量。
-   单次同步最大数据量。
-   最大重试次数。
-   重试退避策略。
-   是否自动同步。
-   自动同步触发条件。
-   默认冲突策略。
-   Tombstone 保留策略。
-   是否允许双向同步。

自动同步必须由宿主明确开启。移动端后台能力不能作为默认保证。

## 6.7 TransferConfig

建议配置：

-   分块大小，初始建议 1--4 MiB。
-   最大并发文件数。
-   单文件最大大小。
-   总传输空间限制。
-   是否启用断点续传。
-   是否校验分块哈希。
-   是否校验完整文件哈希。
-   临时目录提供方式。
-   传输超时。

## 6.8 运行时配置更新

区分两类配置：

**静态配置**：需要重启对应子系统才能生效，例如监听端口、服务类型、证书配置。

**动态配置**：可以运行时更新，例如设备显示名称、同步范围、日志等级和并发限制。

必须明确配置更新行为：

-   `updateConfig` 返回更新结果。
-   对静态配置的变更，应提示需要重启服务或由 Client 安全重启相关组件。
-   不允许静默忽略配置变更。
-   配置校验失败时不得部分应用。

------------------------------------------------------------------------

# 7. 核心公共模型

公共模型必须稳定、与具体业务无关。

## 7.1 SyncDevice

代表发现到的设备或已登记的可信设备。

建议字段：

-   `deviceId`
-   `deviceName`
-   `platform`
-   `appVersion`
-   `protocolVersion`
-   `addresses`
-   `port`
-   `capabilities`
-   `trustState`
-   `connectionState`
-   `firstSeenAt`
-   `lastSeenAt`

发现结果和可信设备应使用不同状态表达，不得把"发现"直接等同于"已配对"。

## 7.2 DeviceTrust

记录设备信任关系：

-   设备 ID。
-   公钥指纹或证书指纹。
-   显示名称。
-   配对时间。
-   最近验证时间。
-   授权 Scope。
-   文件发送/接收权限。
-   撤销状态。

密钥材料必须由安全存储实现保护。普通 Store
只能保存非秘密元数据，或保存经过安全存储封装的引用。

## 7.3 SyncChange

通用变更记录：

``` json
{
  "operationId": "unique-operation-id",
  "scope": "favorites",
  "entityType": "favorite",
  "entityId": "stable-entity-id",
  "originDeviceId": "device-a",
  "operation": "upsert",
  "schemaVersion": 1,
  "revision": {
    "device-a": 12,
    "device-b": 4
  },
  "createdAt": "2026-11-01T00:00:00Z",
  "payload": {
    "example": "business-owned-data"
  }
}
```

字段要求：

-   `operationId` 全局唯一，用于幂等去重。
-   `entityId` 在不同设备之间保持稳定。
-   `scope` 表示宿主注册的数据范围。
-   `schemaVersion` 用于结构兼容判断。
-   `revision` 用于检测因果关系和并发修改。
-   `payload` 是通用 JSON 数据，不包含任意 Dart 对象。

## 7.4 SyncCursor

游标必须按"对端设备 + Scope"隔离。

字段：

-   `peerDeviceId`
-   `scope`
-   `localCheckpoint`
-   `remoteCheckpoint`
-   `lastSuccessfulSyncAt`
-   `protocolVersion`

只有在对应批次数据成功持久化后，才能推进游标。

## 7.5 SyncTask

任务字段：

-   `taskId`
-   `peerDeviceId`
-   `direction`
-   `scopes`
-   `status`
-   `stage`
-   `totalChanges`
-   `completedChanges`
-   `totalBytes`
-   `transferredBytes`
-   `startedAt`
-   `completedAt`
-   `error`

任务状态至少包含：

`pending`、`discovering`、`connecting`、`authenticating`、`negotiating`、`planning`、`transferring`、`applying`、`resolvingConflicts`、`completed`、`partiallyCompleted`、`failed`、`cancelled`、`paused`。

------------------------------------------------------------------------

# 8. 设备发现

## 8.1 发现实现

推荐使用 Bonsoir 实现 mDNS / DNS-SD。

Bonsoir 是发现适配器，不是同步引擎。应用层依赖 `DeviceDiscovery`
抽象，不直接依赖 Bonsoir 的类型。

抽象能力：

-   `start()`。
-   `stop()`。
-   `registerLocalService()`。
-   `unregisterLocalService()`。
-   `discoveredDevices` Stream。
-   `discoveryErrors` Stream。

## 8.2 服务发现数据

TXT 记录仅包含：

-   `device_id`
-   `protocol_version`
-   `app_version`
-   `platform`
-   `capabilities_hash`

设备名称、端口和地址应通过服务记录解析；如需完整信息，连接后再通过安全握手获取。

## 8.3 发现可靠性

必须支持：

-   服务出现。
-   服务消失。
-   地址变化。
-   同一设备多网卡重复广播。
-   IPv4 / IPv6。
-   网络切换。
-   发现超时。
-   手动输入 IP 和端口。
-   二维码配对。

mDNS
可能被路由器隔离、访客网络策略或操作系统权限阻断。因此手动连接是正式能力，不是调试功能。

## 8.4 设备去重

以稳定 `deviceId` 为主键，不以 IP 地址为主键。

同一设备有多个网络地址时，保存为地址列表，并按可达性和网络策略选择连接地址。

若相同 Device ID
对应不同公钥指纹，应视为身份异常，不得自动覆盖可信设备记录。

------------------------------------------------------------------------

# 9. 配对与安全会话

## 9.1 配对原则

发现设备不代表信任设备。连接成功不代表允许读取数据。

正式同步必须满足：

1.  对端身份验证成功。
2.  双方配对关系有效。
3.  当前操作 Scope 已授权。
4.  当前文件操作权限有效。
5.  通信通道已加密。

## 9.2 配对流程

``` text
设备发现
   ↓
发起配对
   ↓
交换临时挑战与身份材料
   ↓
用户确认设备信息
   ↓
验证短时配对凭据
   ↓
验证公钥/证书指纹
   ↓
保存可信设备关系
   ↓
建立加密会话
```

## 9.3 安全技术

优先使用标准 TLS
和公钥/证书绑定。若需要额外的端到端密钥协商，使用经过审查的成熟协议实现，不得自行设计加密握手。

必须具备：

-   传输加密。
-   对端身份认证。
-   防重放机制。
-   配对验证码限时有效。
-   配对失败限流。
-   设备撤销。
-   权限检查。
-   敏感信息不写日志。

## 9.4 权限模型

每个设备分别授权：

-   读取某个 Scope。
-   写入某个 Scope。
-   接收文件。
-   发送文件。
-   发起同步。
-   接受同步。

权限默认最小化。配对不应自动授予全部 Scope 的读写权限。

------------------------------------------------------------------------

# 10. 数据同步引擎

## 10.1 采用 Change Log，而不是数据库复制

禁止直接复制 Hive CE、SQLite 或其他业务数据库文件。

正确流程：

``` text
业务 Repository
      ↓
业务数据变更
      ↓
Outbox / Change Log
      ↓
live_lan_sync 导出变更
      ↓
网络传输
      ↓
目标 Adapter 校验并应用
      ↓
目标业务 Repository
```

## 10.2 Outbox 一致性

业务数据更新与变更日志记录必须具备可靠的一致性保证。

优先使用同一数据库事务提交业务变更和 Outbox 记录。

如果当前存储无法提供跨 Box 事务，应设计可恢复的 Outbox
状态机或通过业务层可靠事件记录实现，不能先改业务数据、再随意异步写日志而不处理失败。

## 10.3 同步阶段

1.  验证对端身份和权限。
2.  协商协议版本和 Scope Schema。
3.  交换各 Scope Manifest。
4.  比较同步游标和变更摘要。
5.  计算需要发送和接收的变更批次。
6.  传输变更。
7.  校验变更。
8.  检测并解决冲突。
9.  通过 Adapter 应用数据。
10. 持久化处理结果。
11. 确认游标。
12. 记录任务完成状态。

## 10.4 幂等性

同一个 `operationId` 只能应用一次。

目标端必须保存已处理 Operation ID，或通过等价的唯一约束保证幂等。

重复收到已成功提交的变更，应返回"已处理"结果，不得重复插入业务记录。

## 10.5 批次

变更必须分批：

-   限制每批条数。
-   限制每批字节数。
-   对大型 Payload 单独处理。
-   每批独立校验和提交。
-   每批提交成功后确认该批次。
-   网络断开后从最后成功提交的批次继续。

不能一次性把全部 Change Log 读入内存。

------------------------------------------------------------------------

# 11. 版本与冲突处理

## 11.1 不使用单纯时间戳决定胜负

设备系统时间可能偏差，时间戳不能准确表示因果顺序。

版本信息应至少包含逻辑版本和来源设备信息。多设备并发修改需要支持 Version
Vector 或等价的因果版本模型。

## 11.2 版本向量比较

对两个版本向量：

-   A 每个分量均不小于 B，且至少一个更大：A 因果领先。
-   A 每个分量均不大于 B，且至少一个更小：A 因果落后。
-   A 有的分量更大、有的分量更小：并发修改。

设备移除、长期离线设备和向量压缩必须有明确策略，不能无限增长。

## 11.3 按数据类型定义策略

  数据类型       建议策略
  -------------- ------------------------------------------
  简单偏好设置   可配置覆盖策略；检测并发后可保留冲突副本
  收藏集合       以添加/移除操作为基础合并
  标签集合       集合操作合并
  播放历史       追加合并并去重
  播放列表       条目操作合并；顺序冲突单独处理
  文件资源       比较内容哈希和资源版本
  复杂配置对象   默认报告冲突，不静默覆盖

## 11.4 删除标记

删除必须生成 Tombstone，不可直接物理删除同步记录。

Tombstone 至少保留到：

-   所有仍受信任且参与该 Scope 的设备已确认相关删除；或
-   达到明确的保留期限，并经过设备离线策略评估。

设备撤销、长期离线和新设备首次加入时，必须避免旧数据导致已删除记录复活。

## 11.5 冲突策略 API

支持：

-   `manual`：交给宿主 UI。
-   `preferLocal`：本机优先。
-   `preferRemote`：远端优先。
-   `merge`：调用 Scope Adapter 的合并实现。
-   `keepBoth`：保留双方版本。

这些是策略选项，不是所有 Scope 都必须无条件支持的行为。Adapter
可以声明不支持某些策略。

------------------------------------------------------------------------

# 12. 业务数据适配器

## 12.1 核心原则

Package 不能直接读取宿主业务数据库。

宿主通过 Adapter 提供可同步数据。

## 12.2 SyncScopeAdapter

概念接口：

``` dart
abstract interface class LanSyncDataAdapter {
  String get scope;

  int get schemaVersion;

  Future<SyncManifest> createManifest();

  Future<List<SyncChange>> exportChanges({
    required SyncCursor cursor,
    required int limit,
  });

  Future<SyncApplyResult> applyChanges({
    required List<SyncChange> changes,
  });

  Future<SyncConflictResult> resolveConflict({
    required SyncChange local,
    required SyncChange remote,
  });
}
```

接口最终需要支持批次上下文、取消信号、事务边界、校验失败和部分成功报告。

## 12.3 Adapter 注册

由宿主应用 Composition Root 创建并注册：

``` text
PureLive Composition Root
        │
        ▼
LanSyncClient
        │
        ├── SettingsSyncAdapter
        ├── FavoritesSyncAdapter
        ├── PlaylistSyncAdapter
        ├── PlaybackHistorySyncAdapter
        ├── FontConfigSyncAdapter
        └── WallpaperConfigSyncAdapter
```

业务 Adapter 应依赖对应业务模块的 Repository，不依赖 UI。

## 12.4 Scope 元数据

每个 Scope 必须声明：

-   唯一名称。
-   Schema 版本。
-   是否支持双向同步。
-   是否支持删除。
-   是否支持冲突合并。
-   是否包含敏感信息。
-   是否允许文件引用。
-   默认同步策略。
-   数据大小预期。

Scope 名称应稳定，不因 UI 文案或语言变化而改变。

------------------------------------------------------------------------

# 13. 文件传输

## 13.1 文件与业务数据分离

业务变更通过 Change Log 同步；大文件通过 File Transfer 子系统传输。

业务变更可以包含资源 ID 和哈希引用，但不能将大文件 Base64 塞进普通 JSON
Payload。

## 13.2 文件清单

``` json
{
  "fileId": "stable-file-id",
  "category": "font",
  "fileName": "example-font.ttf",
  "mimeType": "font/ttf",
  "size": 12345678,
  "sha256": "whole-file-hash",
  "chunkSize": 2097152,
  "totalChunks": 6,
  "schemaVersion": 1
}
```

## 13.3 传输流程

1.  创建传输任务。
2.  交换文件元数据。
3.  检查目标是否已有相同 SHA-256 文件。
4.  创建临时文件。
5.  协商缺失分块。
6.  分块传输。
7.  校验分块。
8.  支持中断后续传。
9.  校验完整文件哈希。
10. 通过目标 Adapter 校验文件类型和内容。
11. 原子提交到宿主指定资源位置。
12. 通知业务模块资源可用。

## 13.4 路径安全

-   不接受远端任意绝对路径。
-   不允许 `../` 路径穿越。
-   文件名需要规范化。
-   目标目录由宿主 Adapter 决定。
-   临时文件与最终文件应位于适合原子替换的同一文件系统。
-   文件提交前必须完成校验。
-   取消任务后按策略清理临时文件。

## 13.5 默认文件策略

  类型           默认
  -------------- ------------
  字体           可选
  壁纸           可选
  图片封面       可选
  用户导入配置   可选
  视频文件       不自动同步
  下载缓存       禁止
  播放缓存       禁止
  临时文件       禁止

------------------------------------------------------------------------

# 14. 网络协议

## 14.1 传输协议

建议：

-   HTTP：控制请求、Manifest、变更批次和文件分块。
-   WebSocket：设备在线状态、任务进度通知、变更提醒。
-   TLS：加密和设备身份验证。
-   JSON：控制协议和通用数据变更。

WebSocket 仅作为通知通道。同步正确性必须由持久化 Change Log、Cursor
和确认机制保证。

## 14.2 API 版本

统一前缀：

`/sync/v1/`

建议接口：

  方法     路径                                   用途
  -------- -------------------------------------- ----------------
  GET      `/hello`                               协议协商
  POST     `/pair/challenge`                      创建配对挑战
  POST     `/pair/confirm`                        确认配对
  GET      `/device`                              获取设备信息
  POST     `/manifest/exchange`                   交换数据清单
  POST     `/changes/exchange`                    交换变更批次
  POST     `/changes/ack`                         确认批次提交
  POST     `/files/init`                          初始化文件任务
  PUT      `/files/{transferId}/chunks/{index}`   上传分块
  GET      `/files/{transferId}/status`           查询传输状态
  DELETE   `/files/{transferId}`                  取消传输
  WS       `/events`                              实时事件

所有接口都必须验证身份、权限、协议版本和请求大小。

## 14.3 请求通用字段

建议包含：

-   `requestId`
-   `protocolVersion`
-   `senderDeviceId`
-   `sessionId`
-   `timestamp`
-   `nonce`
-   `payload`

响应应包含：

-   `requestId`
-   `success`
-   `error`
-   `payload`

不得把安全性仅建立在时间戳上；Nonce 或会话序号必须参与防重放。

## 14.4 兼容性

协议版本和 Scope Schema 版本分开管理：

-   协议版本控制通信结构和交互流程。
-   Scope Schema 版本控制业务 Payload 结构。

不兼容版本必须明确返回错误，不能尝试把未知字段静默解释为旧格式。

------------------------------------------------------------------------

# 15. 持久化接口

## 15.1 不绑定数据库

Package 应提供 `LanSyncStore` 抽象，允许宿主注入存储实现。

可以另外提供可选默认存储适配器，但不能强制所有宿主使用 Hive CE。

## 15.2 必须持久化的元数据

-   本机设备 ID。
-   已配对设备。
-   设备权限。
-   配对身份指纹。
-   同步任务。
-   Change Log 或待确认变更。
-   已处理 Operation ID。
-   Sync Cursor。
-   Tombstone。
-   冲突记录。
-   文件传输任务和分块状态。
-   协议兼容信息。

## 15.3 存储一致性

必须定义事务边界：

-   接收变更和记录已处理 Operation ID 应尽可能原子提交。
-   业务 Adapter 应在其业务存储中保证应用变更和幂等状态一致。
-   Cursor 只能在批次提交成功后更新。
-   文件任务状态不能先标记完成再验证哈希。

如果底层存储不支持事务，必须采用可恢复状态机和补偿机制。

## 15.4 多窗口与多进程

桌面多窗口不能各自创建独立监听服务。

宿主应指定唯一的 Sync Host，负责：

-   监听端口。
-   mDNS 注册。
-   设备连接。
-   同步调度。
-   文件传输任务。

其他窗口通过应用已有 IPC 或状态管理机制与 Sync Host 通信。

不得通过全局单例绕过生命周期管理。

不得直接让多个进程同时写入同一份 Hive CE 文件。

------------------------------------------------------------------------

# 16. Client 生命周期与公共 API

## 16.1 统一入口

建议对宿主暴露 `LanSyncClient`。

示意：

``` dart
final client = LanSyncClient(
  config: config,
  store: store,
  adapters: adapters,
  fileAdapters: fileAdapters,
  security: security,
);

await client.initialize();
await client.startDiscovery();
await client.startServer();

final devices = client.discoveredDevices;

final task = await client.synchronize(
  deviceId: peerId,
  scopes: {'settings', 'favorites'},
  direction: SyncDirection.bidirectional,
);

await client.dispose();
```

该示例表达 API 方向，不代表未经实现和评审即可直接照抄为最终接口。

## 16.2 生命周期

建议提供：

-   `initialize()`：校验配置、恢复元数据、初始化子系统。
-   `startDiscovery()`：开始设备发现。
-   `stopDiscovery()`：停止发现。
-   `startServer()`：启动本机服务。
-   `stopServer()`：停止本机服务。
-   `refreshDevices()`：主动刷新。
-   `pair()`：配对设备。
-   `synchronize()`：创建同步任务。
-   `pauseTask()`：暂停。
-   `resumeTask()`：恢复。
-   `cancelTask()`：取消。
-   `removeDevice()`：撤销信任。
-   `updateConfig()`：更新配置。
-   `dispose()`：释放资源。

重复调用必须有明确行为。例如重复 `startDiscovery()`
不得创建多个浏览器实例。

## 16.3 Stream

建议提供：

-   `discoveredDevices`
-   `trustedDevices`
-   `connectionStates`
-   `tasks`
-   `events`
-   `conflicts`
-   `transferProgress`
-   `errors`

Stream 必须明确广播/单订阅语义、关闭时机和背压处理。

------------------------------------------------------------------------

# 17. 事件模型

建议定义统一事件基类或 sealed hierarchy：

-   `DeviceDiscovered`
-   `DeviceLost`
-   `DeviceUpdated`
-   `PairingRequested`
-   `PairingCompleted`
-   `DeviceTrustRevoked`
-   `ConnectionEstablished`
-   `ConnectionLost`
-   `SyncStarted`
-   `SyncStageChanged`
-   `SyncProgressChanged`
-   `SyncConflictDetected`
-   `SyncCompleted`
-   `SyncFailed`
-   `TransferProgressChanged`
-   `TransferCompleted`
-   `TransferFailed`

事件用于通知 UI 和宿主，不应替代持久化状态。

应用重启后，任务状态应从 Store 恢复，而不是依赖过去是否收到某个 Stream
事件。

------------------------------------------------------------------------

# 18. 错误模型

错误至少分类：

-   `configuration`
-   `discovery`
-   `deviceUnavailable`
-   `identityMismatch`
-   `pairing`
-   `authentication`
-   `permissionDenied`
-   `protocolIncompatible`
-   `schemaIncompatible`
-   `transport`
-   `timeout`
-   `rateLimited`
-   `dataValidation`
-   `storage`
-   `conflict`
-   `fileTransfer`
-   `integrityCheck`
-   `insufficientStorage`
-   `cancelled`
-   `unknown`

错误对象应包含：

-   稳定错误码。
-   错误类别。
-   是否可重试。
-   关联设备 ID。
-   关联任务 ID。
-   失败阶段。
-   安全的用户提示。
-   调试上下文。

不得将密钥、Token、完整业务 Payload 或敏感路径放入错误日志。

重试使用指数退避并设置上限。认证失败、权限拒绝和协议不兼容不能无限重试。

------------------------------------------------------------------------

# 19. 平台适配

## 19.1 Android / Android TV

考虑：

-   本地网络访问。
-   Wi-Fi 网络变化。
-   组播发现限制。
-   Android 版本权限差异。
-   前台服务和后台执行限制。
-   TV 遥控器操作。
-   网络断开后的恢复。

首期以前台同步为主，不承诺进程被系统杀死后持续服务。

## 19.2 iOS

考虑：

-   Local Network Privacy。
-   Bonjour 服务声明。
-   后台运行限制。
-   应用进入后台后的 socket 生命周期。
-   网络变化。
-   用户拒绝本地网络权限后的说明与恢复入口。

不能假设 iOS 可无限期运行局域网 HTTP Server。

## 19.3 Windows

考虑：

-   Windows Defender Firewall。
-   网络配置文件。
-   入站端口规则。
-   多网卡。
-   网络切换。
-   多窗口唯一服务宿主。

## 19.4 macOS

考虑：

-   Local Network 权限。
-   Bonjour 声明。
-   App Sandbox 网络能力。
-   防火墙。
-   应用生命周期。

## 19.5 Linux

考虑：

-   Avahi / mDNS 环境。
-   防火墙。
-   多网卡。
-   IPv4 / IPv6。
-   组播可用性。

## 19.6 平台能力抽象

平台差异通过接口封装，例如：

-   `LocalNetworkPermissionProvider`
-   `NetworkInterfaceProvider`
-   `SecureCredentialStore`
-   `TemporaryDirectoryProvider`

没有必要把所有平台逻辑都放入一个巨大的 PlatformService。

------------------------------------------------------------------------

# 20. 安全规范

必须满足：

1.  发现设备不能自动信任。
2.  未配对设备不能读取同步数据。
3.  正式通信必须加密。
4.  可信设备必须进行身份验证。
5.  Scope 权限必须逐项检查。
6.  文件发送和接收权限必须独立。
7.  mDNS TXT 不得包含秘密。
8.  配对验证码短时有效并限流。
9.  请求必须防重放。
10. 请求体和文件大小必须受限。
11. 文件路径由本地生成。
12. 文件提交前必须校验。
13. 取消配对后旧凭据立即失效。
14. 日志必须脱敏。
15. 默认排除 Token、Cookie、密码和私钥。

对端处于同一个 Wi-Fi
网络不代表可信。访客网络、公共热点和被攻陷的局域网设备都必须纳入威胁模型。

------------------------------------------------------------------------

# 21. 性能和资源限制

初始默认值建议通过配置开放：

  参数                    初始建议
  -------------------- -----------
  单批变更条数                 100
  文件分块                   2 MiB
  并发文件传输                   2
  单设备并发同步任务             1
  请求超时               15--30 秒
  配对码有效期              3 分钟
  自动发现间隔               15 秒

这些值是初始基准，不是不可变协议常量。应通过真实设备和弱网络测试调整。

必须做到：

-   JSON 批次大小限制。
-   文件流式传输。
-   有界并发。
-   有界内存缓冲。
-   可取消任务。
-   网络断开后清理或保留可恢复状态。
-   防止任务队列无限增长。
-   防止重复连接和重复服务注册。

------------------------------------------------------------------------

# 22. PureLive 接入方案

## 22.1 PureLive 负责什么

PureLive 负责：

-   生成和持久化本机 Device ID。
-   提供设备显示名称和应用版本。
-   提供 Store 实现。
-   提供安全凭据存储实现。
-   注册业务 Adapter。
-   管理 Client 生命周期。
-   使用 Riverpod 3 向 UI 暴露状态。
-   提供同步设置、设备管理和历史页面。

## 22.2 业务 Adapter

建议初始接入顺序：

1.  收藏。
2.  自定义标签。
3.  自定义分区。
4.  播放列表。
5.  播放历史。
6.  应用设置。
7.  字体配置。
8.  壁纸配置。

每个业务模块自行定义稳定 ID、Schema 版本、变更导出、数据校验和合并策略。

## 22.3 PureLive Feature 结构

``` text
apps/pure_live/lib/features/lan_sync/
├── application/
│   ├── lan_sync_feature_service.dart
│   └── lan_sync_adapter_registry.dart
├── presentation/
│   ├── pages/
│   ├── widgets/
│   └── providers/
└── lan_sync_feature.dart
```

该 Feature 不重复实现网络协议，只负责应用组装和 UI。

## 22.4 Provider

Provider 只暴露 Client 的状态和命令，不包含
HTTP、mDNS、文件传输和同步算法。

同步服务生命周期由 App Composition Root 管理，不通过全局单例管理。

------------------------------------------------------------------------

# 23. UI 不属于 Package

`live_lan_sync` 不提供 PureLive 专属 UI。

宿主可以自行设计：

-   局域网同步主页。
-   发现设备列表。
-   二维码配对页。
-   设备详情页。
-   权限设置页。
-   同步内容设置页。
-   同步任务详情。
-   冲突处理页。
-   文件传输列表。
-   同步历史页。

Package 只提供稳定状态模型、事件和操作 API。

其他应用接入时可以使用完全不同的 UI。

------------------------------------------------------------------------

# 24. 测试规范

## 24.1 单元测试

必须覆盖：

-   配置校验。
-   设备身份比较。
-   设备去重。
-   版本向量比较。
-   幂等去重。
-   Change Log 筛选。
-   Cursor 推进。
-   Tombstone。
-   冲突识别。
-   冲突策略。
-   文件哈希。
-   分块状态恢复。

## 24.2 协议测试

必须覆盖：

-   版本协商。
-   未知协议版本。
-   无效请求。
-   重放请求。
-   超大请求。
-   缺少权限。
-   身份指纹不匹配。
-   重复 Operation ID。
-   不完整批次。
-   错误确认游标。

## 24.3 集成测试

必须覆盖：

-   两台设备发现。
-   手动 IP 连接。
-   配对和撤销。
-   单向推送。
-   单向拉取。
-   双向同步。
-   同步中断和恢复。
-   文件断点续传。
-   冲突处理。
-   设备重启后恢复任务。

## 24.4 多平台测试矩阵

至少验证：

-   Windows ↔ Windows
-   Windows ↔ Android
-   Windows ↔ Android TV
-   Windows ↔ macOS
-   Windows ↔ Linux
-   Android ↔ Android

iOS 必须单独验证本地网络授权、Bonjour 声明和前后台行为。

## 24.5 故障注入

测试：

-   传输到一半断网。
-   设备进程被终止。
-   目标磁盘空间不足。
-   文件哈希不匹配。
-   业务 Adapter 提交失败。
-   游标写入失败。
-   两端同时修改同一实体。
-   一端删除另一端修改。
-   设备被撤销后仍尝试连接。

------------------------------------------------------------------------

# 25. 开发阶段与交付物

不得一次性生成整个 Package。按阶段实施，每阶段都要有可验证结果。

## Phase 0：需求和接口评审

交付：

-   本文档评审结果。
-   公共 API 清单。
-   配置项清单。
-   协议边界。
-   数据适配器契约。

验收：公共接口和职责边界明确。

## Phase 1：Package 骨架

实现：

-   `pubspec.yaml`
-   公共导出。
-   Config。
-   Domain 模型。
-   错误类型。
-   Store / Adapter 接口。
-   基础测试。

验收：Package 可独立分析、测试和被宿主引用。

## Phase 2：设备发现

实现：

-   Bonsoir 适配器。
-   mDNS 注册和浏览。
-   设备去重。
-   手动地址。
-   网络变化处理。

验收：两台设备可发现彼此，发现不自动建立信任。

## Phase 3：身份和配对

实现：

-   设备身份。
-   配对挑战。
-   用户确认。
-   安全凭据持久化。
-   设备撤销。
-   Scope 权限。

验收：未配对设备无法读取同步数据。

## Phase 4：安全通信

实现：

-   HTTP Server / Client。
-   TLS 身份绑定。
-   协议协商。
-   请求认证。
-   请求限流。
-   WebSocket 通知。

验收：两台设备可以安全交换测试消息。

## Phase 5：增量同步

实现：

-   Change Log。
-   Manifest。
-   Cursor。
-   批次交换。
-   幂等。
-   Tombstone。
-   事务和恢复机制。

验收：重复同步不会重复创建数据；断线恢复不丢失已提交变更。

## Phase 6：冲突处理

实现：

-   版本向量。
-   并发修改检测。
-   策略接口。
-   冲突持久化。
-   冲突事件。

验收：并发修改不会静默覆盖。

## Phase 7：文件传输

实现：

-   文件清单。
-   分块上传。
-   断点续传。
-   哈希校验。
-   原子提交。
-   取消和清理。

验收：大文件中断后可以恢复，损坏文件不会提交。

## Phase 8：PureLive 接入

实现：

-   Store Adapter。
-   业务 Sync Adapter。
-   App 生命周期组装。
-   Riverpod 状态适配。
-   同步 UI。

验收：至少完成收藏和播放列表同步。

## Phase 9：跨平台和稳定性

实现：

-   平台权限。
-   网络切换。
-   多窗口宿主协调。
-   弱网测试。
-   安全审计。
-   性能测试。

验收：所有目标平台的主动同步能力通过测试。

------------------------------------------------------------------------

# 26. AI 开发强制规范

AI 编程助手必须遵守：

## 26.1 开始前

1.  阅读当前 Workspace 根部的 `pubspec.yaml`（Dart pub workspace：`workspace:` 成员列表、共享 `pubspec.lock`、依赖 override 只允许声明在根部；melos 8.9.0 以 dev 依赖形式存在，脚本同样配置在根 pubspec 的 `melos:` 段）。
2.  阅读相邻 Package 的 `pubspec.yaml` 和导出风格。
3.  阅读项目 Dart SDK、分析规则和代码生成约定。
4.  审计现有 `live_net`、`live_storage`、`live_platform` 能力。
5.  不得假设现有包已经提供某个 API，必须先核实。

## 26.2 架构约束

-   Package 必须位于 `packages/live_lan_sync`。
-   不得放入 `apps/pure_live/lib/features` 实现同步引擎。
-   不得依赖 PureLive 业务模型。
-   不得依赖 DLNA。
-   不得引入全局单例。
-   不得让 UI 直接访问底层网络实现。
-   不得把所有逻辑写进单个 Service。
-   不得强制绑定 Hive CE。
-   不得直接复制数据库文件。
-   不得把 Bonsoir 作为整个系统的核心抽象。

## 26.3 代码约束

-   公共 API 必须从唯一入口导出。
-   内部实现放在 `src/`。
-   所有异步任务必须有取消和释放策略。
-   所有 Stream 必须明确关闭时机。
-   所有网络输入必须校验。
-   所有文件输入必须校验路径和内容。
-   所有任务状态必须可恢复或明确标记不可恢复。
-   不得留下空壳接口和无意义包装层。
-   不得为尚未实现的未来能力创建大量占位文件。

## 26.4 修改流程

必须遵循：

``` text
现有代码审计
    ↓
方案与依赖评估
    ↓
目录和接口设计
    ↓
用户确认
    ↓
文件级实施计划
    ↓
分阶段修改
    ↓
静态分析
    ↓
单元测试
    ↓
集成测试
    ↓
文档更新
```

用户明确要求先看方案时，不得直接批量修改代码。

------------------------------------------------------------------------

# 27. 首期版本范围

首期不追求功能数量，必须优先保证端到端正确性。

## P0：必须完成

-   可配置 Client。
-   mDNS 发现。
-   手动 IP。
-   设备身份。
-   安全配对。
-   HTTP 安全通信。
-   协议版本协商。
-   Adapter 接口。
-   Change Log。
-   Cursor。
-   幂等处理。
-   单向和双向同步。
-   基础冲突检测。
-   任务状态和错误事件。

## P1：第二阶段完成

-   Tombstone 清理策略。
-   完整版本向量。
-   文件分块传输。
-   断点续传。
-   WebSocket 事件。
-   同步历史。
-   设备 Scope 权限管理。
-   多平台完善。

## P2：后续扩展

-   多设备并发同步。
-   自动后台同步。
-   更复杂的集合/列表合并。
-   局域网中继。
-   云端传输后端。
-   可插拔压缩算法。
-   大规模设备管理。

------------------------------------------------------------------------

# 28. 最终架构决策

最终 Package：

`packages/live_lan_sync`

定位：

**独立、可配置、可插拔、业务无关的局域网设备发现与数据同步引擎。**

核心职责：

-   设备发现。
-   设备身份。
-   安全配对。
-   设备信任和权限。
-   安全网络通信。
-   协议协商。
-   增量数据同步。
-   版本与冲突处理。
-   文件传输。
-   任务管理。
-   同步状态与事件。
-   可插拔存储和业务适配器。

PureLive 负责：

-   创建配置。
-   提供存储实现。
-   提供安全凭据存储。
-   注册业务 Adapter。
-   管理 Client 生命周期。
-   提供 UI 和用户交互。

最终依赖关系：

``` text
PureLive App
    │
    ├── lan_sync Feature UI
    │
    ├── PureLive Store Adapter
    │
    ├── PureLive Security Adapter
    │
    └── PureLive Business Adapters
              │
              ▼
       live_lan_sync
              │
       ┌──────┼────────┐
       │      │        │
       ▼      ▼        ▼
   Discovery Transport Sync Engine
       │      │        │
       ▼      ▼        ▼
     mDNS    HTTP   Change Log
             WS     Cursor
                    Conflict
                    Transfer
```

**最终原则：`live_lan_sync`
只解决"设备之间如何安全、可靠地交换通用数据和文件"，不决定"宿主应用应该同步什么业务数据"。**
