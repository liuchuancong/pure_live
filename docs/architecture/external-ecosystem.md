# External Ecosystem(外部生态协议与直接导入)

> 文档状态:定稿 / Architecture Decision
> 定位:TVBox 仓库、LX Music 音乐源、M3U、XMLTV 及其他第三方数据源的**统一接入规范**。
> 核心结论:**TVBox 单仓/多仓、LX Music 源等外部生态,直接导入直接运行,不要求也不允许强制转换成 PureLive 插件格式。**

## 1. 设计目标

PureLive v2 不仅提供自己的 Plugin SDK,还必须兼容现有第三方生态。用户已经拥有的大量资产——TVBox 单仓、TVBox 多仓、LX Music 音乐源、M3U、XMLTV、第三方数据源、社区维护的数据仓库——应该**直接导入并使用**。

不要求用户:修改原始仓库 / 转换为 PureLive Plugin / 编写 Dart Plugin / 重新打包 / 发布到插件市场。

> **兼容外部协议,而不是要求外部生态迁移到 PureLive Plugin API。**

## 2. Runtime Adapter 模式

```text
External Source → External Runtime → PureLive Unified Model → Feature → Media Core
```

例:TVBox JSON → TVBox Runtime → ContentRef/MediaItem/MediaTicket → VOD/Live;LX Music Source → LX Music Runtime → MusicItem/Lyric/MediaTicket → Music Feature → Media Core。

## 3. Plugin 与 External Source 的区别(必须区分)

| | PureLive Plugin | External Source |
|---|---|---|
| 本质 | 为 PureLive 设计的**原生扩展协议** | 第三方生态**已有的数据源协议** |
| 构成 | Manifest / Capability / Provider / Permission / Lifecycle / Runtime | TVBox Repository / LX Music Source / M3U / XMLTV / 其他兼容源 |
| 适合 | 新直播/视频/音乐平台、新功能、UI/搜索/Feed/账户扩展、Theme、数据处理、自动化 | 已有仓库与源,原样接入 |
| 修改原协议 | — | **不修改** |
| 转换为 Plugin | — | **不转换** |
| 重新打包 | — | **不要求** |
| 加载方式 | Plugin Runtime | 对应 External Runtime 直接加载 |

支持的能力面(扩展 PureLive 本身):新平台/新功能/UI/搜索/Feed/账户/Theme/数据处理/自动化。

## 4. 总体架构

```text
            PureLive v2
                 │
        ┌────────┴────────┐
        │                 │
  Native Plugin     External Source
        │                 │
 PureLive Plugin API  External Runtime
        │                 │
  LiveProvider…     TVBox / LX Music
        └────────┬────────┘
                 ▼
        Unified Content Model
        (ContentRef / MediaItem / MediaTicket)
                 ▼
          PureLive Features → Media Core → Player
```

## 5. ExternalSourceRuntime

External Source 不直接进入 UI,中间加一层运行时,负责:协议识别、Source 加载、解析、请求调度、Cookie/Session、数据缓存、错误处理、Source 生命周期、**转换为 PureLive Unified Model**。

```dart
abstract interface class ExternalSourceRuntime {
  String get type;
  String get version;
  bool canHandle(ExternalSourceDescriptor source);
  Future<ExternalSourceInstance> load(ExternalSourceDescriptor source);
}
```

Runtime 只做"外部协议 → 解析 → 统一模型",**不负责 UI**。

## 6. ExternalSourceDescriptor

用户导入的不是 Plugin,而是 Source Descriptor:

```dart
class ExternalSourceDescriptor {
  final String id;
  final String uri;                    // https://…/api.json 或本地文件路径
  final String? name;
  final String? type;                  // tvbox / lx_music / m3u / xmltv / 自动
  final Map<String, dynamic> metadata;
}
```

用户不需要知道 PureLive 内部的 Plugin API。

## 7. 协议自动识别

```text
URL / 文件 → Source Detector → 协议识别 → Runtime
```

例:`…/tvbox.json` → TVBox Detector → TvBoxRuntime;`…/source.js` → LX Music Detector → LxMusicRuntime。也允许用户显式指定类型:自动识别 / TVBox / LX Music / M3U / XMLTV。

## 8. TVBox 直接导入

**单仓**:用户"添加仓库"输入 `https://example.com/tvbox.json` → TVBox Runtime → 读取配置 → 解析站点 → 注册 Repository → 分类/搜索/详情/播放。**不生成 Plugin。**

**多仓**:可添加多个仓库,由 ExternalRepositoryManager 统一管理(Repository A/B/C/D),统一提供分类/搜索/详情/播放/收藏/历史。

**多仓聚合不复制数据到数据库,保留来源**:

```text
ContentRef { sourceId, repositoryId, contentType, contentId }
例:tvbox/repository-a/movie/123、tvbox/repository-b/movie/456
```

从而支持:追踪来源 / 删除仓库 / 单独刷新 / 单独禁用 / 统计失败率 / 源切换 / 保留用户收藏。

**播放解析**:TVBox 播放地址不直接交给 UI——`TVBox Runtime → Resolve → MediaTicket → Media Core`。因此 TVBox 直接复用 PureLive 已有的:多线路、URL 过期刷新、播放恢复、网络错误恢复、解码器切换、Watchdog、播放日志、历史、投屏、小窗、后台播放。

## 9. LX Music 直接导入

用户"添加音乐源"输入 URL 或本地 `source.js`:

```text
LX Music Source → LxMusicRuntime → Source API → MusicItem
→ MusicResolver → MediaTicket → Media Core
```

**LxMusicRuntime 与原生 Plugin 运行环境分离**(Script Runtime / Source API / Network / Cookie / Request / Response / Adapter);**Source 原本使用的接口保持原样**,PureLive 只提供兼容运行环境。

数据统一:源返回数据不直接污染 UI——统一转成 `MusicItem`(id/title/artists/album/duration/artwork/source/metadata),播放地址转 MediaTicket,歌词转 Lyric。

## 10. 为什么不统一转换成 Plugin

1. **用户成本高**:普通用户无法使用现有仓库;
2. **生态碎片化**:同一仓库要维护 TVBox 版 + PureLive Plugin 版;
3. **兼容性下降**:第三方仓库更新后转换层可能失效;
4. **生态失去价值**:PureLive 的核心优势是**直接吸收已有生态**,而不是要求生态迁移。

注意:**协议适配 ≠ Plugin 转换**。`TVBox → TVBox Runtime → ContentRef → MediaItem` 是对的;`TVBox → PureLive Plugin → ContentRef` 是错的。

## 11. Capability 映射

External Source 最终也映射到 Capability,核心运行时保持统一:

```text
TVBox:    Search / Category / Detail / Playback / Repository
LX Music: MusicSearch / MusicResolve / Lyric / Album / Artist
```

## 12. 生命周期与状态

```text
ADD → DETECT → LOAD → VALIDATE → REGISTER → READY → REFRESH → DISABLE → REMOVE
```

```dart
enum ExternalSourceStatus { loading, ready, disabled, error, expired }
```

## 13. ExternalSourceManager

统一负责:添加/删除/启用禁用/更新/刷新/协议检测/版本检查/可用性检查/错误查看/**优先级管理**/多 Source 管理。

## 14. SourcePriority(多仓同内容)

```text
TVBox A priority=100 → TVBox B 80 → TVBox C 50
Resolver:优先 A → 失败 → B → 失败 → C
```

与 LineFallback / MediaTicket / Recovery 机制结合。

## 15. ExternalSourceCache(分数据 TTL)

| 数据 | TTL |
|---|---|
| 仓库配置 | 10 min |
| 分类 | 30 min |
| 详情 | 30 min |
| 搜索 | 1~5 min |
| 图片 | 长缓存 |
| 播放地址(resolved-url) | 极短缓存 |

## 16. 网络与安全

统一经 PluginNetwork / ExternalNetwork:Host Allowlist / Timeout / Redirect / Headers / Cookies / Proxy / Response Size / Concurrency / Cache / User-Agent——第三方 Source 出问题不直接影响整个应用。

脚本型 Source(LX Music)安全边界:

```text
Source Script → Sandbox Runtime → (Network / Cookie / Storage / Source API)
```

默认:网络允许、Cookie 受控、本地文件禁止、系统命令禁止、进程禁止、任意 FFI 禁止、任意 Native API 禁止。

## 17. 本地 Source

URL 之外支持本地文件(tvbox.json / playlist.m3u / epg.xml / source.js):文件 → Source Detector → External Runtime → 注册。

## 18. 远程 Source 增量更新

远程 Source 不应每次启动重新下载。Source 记录 `uri / etag / lastModified / lastFetchedAt / version / checksum`,支持 `ETag + If-None-Match`、`Last-Modified + If-Modified-Since`。

## 19. Source / Repository / Provider 三区分

| 概念 | 是什么 |
|---|---|
| Source | 原始外部资源(URL / File / Script) |
| Repository | Source 加载后形成的内容集合(TVBox Repository / Music Source / M3U Playlist) |
| Provider | PureLive 内部能力实现(SearchProvider / VodProvider / MusicProvider / LiveProvider) |

链:`External Source → Runtime → Repository → Provider → Feature`。

## 20. 包结构

```text
packages/
├── pure_live_content/  pure_live_capability/  pure_live_repository/
├── pure_live_external/           # api / runtime / detector / manager / model
├── pure_live_external_tvbox/     # parser / runtime / repository / resolver
├── pure_live_external_lx_music/  # runtime / source / parser / resolver
├── pure_live_external_m3u/
├── pure_live_external_xmltv/
└── pure_live_plugin_api/
```

依赖:`pure_live_external → content / capability / network / storage`;`external_tvbox / external_lx_music → pure_live_external`。**TVBox Runtime 不得依赖 Live/Vod/Music/Home UI**——UI 只消费统一模型。

## 21. 外部生态支持矩阵

| 外部生态 | 导入方式 | 转换 Plugin? | Runtime |
|---|---|---|---|
| TVBox 单仓 | URL/文件 | ❌ | TVBox Runtime |
| TVBox 多仓 | 多个 URL | ❌ | TVBox Runtime |
| LX Music Source | URL/文件 | ❌ | LX Music Runtime |
| M3U | URL/文件 | ❌ | M3U Runtime |
| XMLTV | URL/文件 | ❌ | XMLTV Runtime |
| PureLive Plugin | Plugin | ✅ 原生 | Plugin Runtime |
| JS Plugin | Plugin | ❌ | JS Plugin Runtime |
| Native Plugin | Plugin | ❌ | Native Runtime |

**"Plugin Runtime"与"External Runtime"是两个不同概念。**

## 22. 用户体验

用户不需要理解 Capability/Provider/Plugin/Adapter/Runtime/Repository——只看到"**添加来源**"一个入口(URL/文件 + 类型自动识别▼ + 添加),PureLive 自动完成 检测→加载→验证→注册→可用。

## 23. 与整体架构的关系

两条链最终汇合到同一套 Content / Media / Playback / History / Favorite / Search / Feed / Cache / Account / Diagnostics——**PureLive 不为了兼容 TVBox、LX Music 而建立第二套播放器、历史、收藏、搜索或缓存体系**。

## 24. 架构结论

```text
Extension System
 ├── PureLive Plugin(原生扩展协议 → Plugin Runtime)
 └── External Source(外部生态协议 → External Runtime)
        └── 汇合 → Capability → Unified Model → Feature → Media Core
```

> **PureLive Plugin 用于扩展 PureLive 本身;External Source 用于兼容已有生态。**
> **已有生态不需要迁移、不需要转换、不需要重新打包。**
> **PureLive 负责提供兼容 Runtime,并将外部协议运行结果映射到统一领域模型。**
