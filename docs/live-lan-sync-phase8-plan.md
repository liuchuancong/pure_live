# PureLive 接入 live_lan_sync · Phase 8 实施方案

> 状态:**已确认并实施完成**(analyze 0 问题、276 测试全过、release build 成功)\
> 范围:spec Phase 8(PureLive 接入)+ Phase 9 的桌面部分;\
> 验收基线:至少完成收藏同步端到端。
> 音乐/影视/红薯等其余模块的接入按同一套适配器模式**后续分批**进行,不在本期。

---

## 1. 现状盘点(已核实)

| 需求 | 宿主现状 | 结论 |
|---|---|---|
| 密钥安全存储 | `flutter_secure_storage: 11.2.0` 已在依赖中,`account_repository.dart`/`webdav_settings.dart` 在用(Windows DPAPI 等) | **直接复用**,不新增依赖 |
| 同步元数据存储 | `live_storage` 的 Drift 数据库:`JsonStore`(命名空间 KV,`putAll`/`deleteAll` 单次 batch 提交,`watchKeys()`)+ `StoragePrefs`(settings 命名空间) | **JsonStore + StoragePrefs 实现 `LanSyncStore`** |
| TLS 证书 | `pointycastle: ^3.9.1` 已在依赖(红果签名/音乐同步 RSA,有手写 DER 读写先例) | **用 pointycastle 自签 EC P-256 证书**,手写最小 DER 编码,不新增依赖 |
| 日志 | `appLog`(live_log 树) | `LanSyncLogger(appLog.forCategory('lan_sync'))` 一行接入 |
| 设备名 | `Platform.localHostname`(音乐同步同款) | 同款 |
| 设置架构 | `SettingsSection` 枚举 + `SettingsChildEntry` 子页树;`backup` 组已有 `webdavSync` 子页先例 | 新增 `SettingsSection.lanSync` 子页(backup 组) |
| UI 组件 | desen_ui(`DsListSection`/`DsListRow`/`showDsDialog`/`DsQrImage` 待查) | 沿用 |

## 2. 目录与模块边界

```text
apps/pure_live/lib/features/lan_sync/
├── data/
│   ├── secure_credential_store.dart    # flutter_secure_storage → SecureCredentialStore
│   ├── drift_lan_sync_store.dart       # JsonStore×3 + StoragePrefs → LanSyncStore
│   ├── tls_identity_provider.dart      # pointycastle 自签证书生成/加载
│   ├── favorites_sync_adapter.dart     # 收藏 scope(P0)
│   └── adapters.dart                   # 组合导出
├── application/
│   ├── lan_sync_controller.dart        # 运行时状态(发现/配对/任务流)
│   └── lan_sync_providers.dart         # Riverpod 组装根
├── presentation/
│   ├── lan_sync_pane.dart              # 设置子页:开关/本机信息/设备列表
│   ├── pairing_dialog.dart             # 配对弹窗:双方展示同一 6 位码 → 确认
│   └── widgets/                        # 设备行/任务行
└── lan_sync.dart
```

依赖方向:`features/lan_sync → live_lan_sync + live_storage + pointycastle`;
`live_lan_sync` 不反向依赖任何宿主代码(架构红线,现有测试已在守)。

## 3. 关键设计决策(需要你确认的点)

### 3.1 TLS 证书生成 — pointycastle,无新依赖 ✅建议
EC P-256 密钥对 + 自签 X.509v3(10 年有效,SAN=设备名),DER 手工编码为 PEM。
私钥 PEM 存 `flutter_secure_storage`,证书 PEM 存 JsonStore `lan_sync_meta` 命名空间
(证书是公开物)。首次启动生成,之后复用。
**代价**:手写约 200 行确定性 DER 编码(SEQUENCE/OID/BIT STRING),风险低、有
音乐同步的 DER 先例;pointycastle 的 ECKeyGenerator 已是库内现成件。

### 3.2 `LanSyncStore` 实现 — Drift JsonStore ✅建议
- `lan_sync_log` 命名空间:变更日志(key = `scope/entityId`,value = LoggedChange JSON,
  含 sequence)。**sequence 计数器存 StoragePrefs**,读取时全表 max + 计数器取大,
  写入 `recordLocalChange` 用 `putAll`(单 batch)保证「日志行+计数器」原子——
  注:StoragePrefs 有 `persistBatch`(多键一个事务),配合使用可做到真原子。
- `lan_sync_cursors`、`lan_sync_tasks`、`lan_sync_conflicts`、`lan_sync_transfers`
  各一个命名空间(key=对端/scope 或 id)。
- `hasProcessedOperation`:独立 `lan_sync_processed` 命名空间(key=operationId)。
  **已知取舍**:已处理集合会无限增长 → P1 加「保留最近 N 天」清理。
- 原子性:`commitBatch` 的效果 = 一次 `putAll` 到日志命名空间 + 一次
  `StoragePrefs.persistBatch`(已处理+游标)。跨两个 backing 无法做到单个
  Drift 事务,**降级为「先日志后游标」顺序 + 崩溃后重放幂等**(引擎的
  applyChanges 本就幂等,spec §15.3 的补偿路径)。写入 CHANGELOG 如实标注。

### 3.3 授权模型(首次接入从简)
- 配对成功时授予:**读收藏 + 写收藏**(本期唯一 scope),文件权限不授。
- 设置页提供每台设备的「允许读取/允许写入/撤销」开关,改 `DeviceTrustService.updateGrants`。

### 3.4 服务端与端口
- 桌面端:设置页开关打开 → `LanSyncHttpServer`(port 0,实际端口进 mDNS TXT)
  + mDNS 注册 + 引擎 `attachTo` + `PairingResponder`。
- 移动/TV 端:同一开关语义;仅前台可用(iOS/Android 后台不承诺,spec §19)。

### 3.5 UI(设置 → 备份与同步 → 局域网同步)

**主子页 `SettingsSection.lanSync`**(backup 组的第二个 child,排在 webdavSync 后):

1. 「启用局域网同步」开关(关 = 停服务器、停 mDNS、停自动同步;信任记录保留)
2. 本机信息行:设备名(可编辑,存 StoragePrefs)+「我的指纹」(短指纹,点击复制)
3. 「发现设备」区块:附近设备列表(设备名/平台/已配对状态),
   未配对设备行尾「配对」按钮;空态说明"两台设备需在同一网络且都打开开关"
4. 「已配对设备」区块:设备行 → 点开行内展开(授权开关/撤销)
5. 「同步记录」区块:最近任务(时间/对端/方向/结果),点行展开错误详情
6. 右上角动作(PageAction,沿 player_kernel_pane 先例):「立即同步全部设备」

**配对流程 UI**(核心交互,spec §9.2):
- 发起方点「配对」→ 对端(配对窗口需打开)弹出请求弹窗:设备名 + 6 位码 + [拒绝/接受]
- 双方弹窗显示**同一个 6 位码**,各自核对后点确认
- 双方确认 → 两侧都提示「已配对」,信任落库
- 弹窗含倒计时(3 分钟过期);码不匹配点拒绝即可,协议会限流爆破

**异常流**:窗口未开(对端提示先打开开关)、会话过期(重新发起)、
密钥确认失败(明确提示"可能存在中间人",配对终止)、撤销后对端请求(拒绝并记录)。

### 3.6 Riverpod 状态划分(配置/运行时/页面三分)

- **配置(持久)**:`lanSyncSettingsProvider`(Notifier:enabled/deviceName/autoSync)→ StoragePrefs
- **运行时(组合根管理生命周期)**:
  - `lanSyncRuntimeProvider`:一次性组装(证书→store→engine→server→discovery),
    enabled 开关驱动 start/stop;Provider 内部持 `LanSyncClient` 等价物(本期先
    显式字段组装,等 spec 的 Facade 落地再换)
  - `discoveredDevicesProvider`:目录的 stream → List<SyncDevice>
  - `pendingPairingsProvider`:responder.requests stream
  - `syncTasksProvider`:engine.taskUpdates + store.tasks
- **页面(临时)**:配对弹窗的倒计时/等待态用本地 StatefulWidget,不进全局。

### 3.7 首期接入的数据 scope

| scope | 实体 | 操作映射 | 说明 |
|---|---|---|---|
| `favorites` | LiveRoom(identityKey) | upsert=整条关注、delete=取关 | P0,验收主体 |
| 播放历史 | — | — | P1(追加去重策略,spec §11.3) |
| 播放列表/设置/字体/壁纸 | — | — | 后续批次 |

收藏适配器要点:`recordLocalChange` 挂在 `FollowsController.add/remove` 之后;
入站 `applyChanges` 走 `repository.add/remove`;并发冲突策略 = `preferRemote`
(收藏以"最后确认的一端"为准,两端同时改一条关注属罕见;写进设置文档)。
**风险**:FollowsController 与入站写入会互相触发 watch 回环 → 适配器内加
「正在应用远端批次」的静默标志(内存内,不入库)。

### 3.8 不做(本期明确排除)
- 手机/TV 真机联调(代码保持平台中立;Windows↔Windows 手工验证)
- 自动后台同步(autoSync 默认关,UI 只给「立即同步」按钮)
- 音乐同步(已有的 LX 音乐同步与本方案并行共存,不合并)
- 文件传输 UI(引擎已就绪,入口留到字体/壁纸批次)

## 4. 实施顺序(确认后执行)

1. `SecureCredentialStore` + Drift `LanSyncStore` + 单测(内存 JsonStore 复用包内测试)
2. pointycastle 证书生成/加载 + 单测(往返、指纹稳定、坏 PEM 拒绝)
3. `favorites` 数据适配器 + 回环防抖 + 单测
4. providers 组装根 + enabled 开关驱动启停 + 单测(默认关,不启服务)
5. 设置子页 + 配对弹窗 + Slang 文案(zh/en)+ 深浅主题
6. `dart analyze`/`flutter test`/`flutter build windows --release` + 手工验证:
   两实例配对 → 收藏变更 → 立即同步 → 两侧一致;撤销 → 拒绝
7. CHANGELOG/README/spec 的 sync-progress 台账更新

预计新增 ~2200 行(含测试与文案),改动文件 ~15 个,均为新增或接线,不动现有页面。

## 5. 已拍板的三件事（按默认方案执行）

1. **证书生成用 pointycastle**(不新增依赖)——同意?
2. **Store 的原子性降级**(先日志后游标+幂等重放,见 3.2)——接受?
3. **入口放 设置→备份与同步→局域网同步**(子页,不做独立一级页面)——同意?
