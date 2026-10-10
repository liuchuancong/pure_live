# pure_live_douyu

> 职责:Douyu 直播源 —— 匿名观众的 feed / 分类 / 搜索 / 带签名换链,协议取数参照 v1 维护线。

| 项 | 规则 |
|---|---|
| 层 | providers(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0(`network`、`utils`)+ L1(`capability`、`platform`)。同层禁互依;不得触碰 PlayerAdapter(I1/I5)。 |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9) |
| 公共面 | 只有 `lib/pure_live_douyu.dart`;内部实现放 `lib/src/` |
| sourceId | `douyu.live`(每行 `ContentRef` 都带它) |

## 内容

- `live/douyu_sign.dart` —— `DouyuDevice`(设备 DID:cookie 与表单必须同一个)、`DouyuEncryptionDescriptor`、
  `douyuSignedForm`(md5 链)、`DouyuSigner`(取描述符 + 缓存与单飞)
- `live/douyu_source.dart` —— `DouyuSource`(Feed / Browse / Search / Resolve)、`DouyuApiException`、
  `douyuPlayUrl`(换链梯)
- `models/douyu_row.dart` —— 三种行形状到 `ContentSummary` 的映射与三个"这条算不算在播"判定

## 行为契约

| 项 | 规则 |
|---|---|
| 端点 | feed `japi/weblist/apinc/allpage/6/<page>`;分类 `m.douyu.com/api/cate/list`;目录 `gapi/rkc/directory/mixList/2_<cid>/<page>`;房间资料 `betard/<roomId>`;搜索 `japi/search/api/searchShow`;换链 `lapi/live/getH5PlayV1/<roomId>`。 |
| 签名 | 换链前先取 websec 描述符(`wgapi/livenc/liveweb/websec/getEncryption?did=`),按 `enc_time` 轮 md5,再带 salt 收尾;salt = 房间号 + 秒级时间戳,`is_special` 描述符不带 salt。表单由 `Uri(queryParameters:).query` 生成(空值渲染成 `cdn` 而非 `cdn=`,v1 一直这么发)。 |
| DID 一致性 | 描述符请求、表单 `did`、cookie 三处必须同一个 DID;不一致时斗鱼边缘直接 403,没有 API 错误码可读。 |
| 描述符缓存 | 同一设备 5 分钟内复用,且必须 `expire_at > now + 30s`、`0 < enc_time <= 16`;并发换链合一次抓取(单飞)。 |
| 换链梯 | `rtmp_live` 若是完整绝对地址必须直接采用(它现在确实会这么返),否则才与 `rtmp_url`/`flv_url` 拼接;再退 `player_1`/`stream_url`/`url`,最后只接受路径像媒体的 `flv_url`。提前返回裸 CDN 目录就是"input stream address format"故障的成因。 |
| 转义 | 只做 `&amp;` → `&`;签名 query 被 HTML 转义后 CDN 不认。 |
| 票据期限 | 匿名链带 `expire=<自签发起的秒数>`,所以 `expiresAt = createdAt + expire`,`refreshBefore = min(45s, 生命/4)`;`expire` 缺失时 refreshBefore 留空、由平台默认提前量兜。契约要求会失效的票据必须带 `expiresAt`。 |
| 失败 | 一律 `DouyuApiException`(带斗鱼自己的 `error` 码与原因);`refresh` 是 `async`,同步抛错会绕过调用方的 `await` 与恢复梯。 |
| 分页 | 目录接口自己声明 `page`/`totalpage` 时按它说;没有声明的接口只在"这页返满"时说 hasMore。没有依据就说 false —— 猜 true 会让列表一直转。 |
| 直播判定 | 列表行 `type == 1`;搜索行 `isLive == 1 && roomType == 0`;资料页 `show_status == 1 && videoLoop != 1` 且标题不以「【回放】」开头。三个接口口径不同,混用会把回放当成在播。 |
| 归属 | 传入的 `NetworkClient` 是借的(同进程别处也在用),`dispose()` 只关自己建的那个。 |

## 本切片不包含

登录 cookie、passport/JWT 续期、弹幕 socket、清晰度与线路挑选(`rate=-1` 交给 CDN)、超级聊天。
这些都是 v1 维护线里已有的能力,等第一个真实消费者要它们时再按契约补,而不是先建一个没人调用的面。

## 未验证

- **没有真实抓包**。`fixtures/` 是空的,测试体是照 v1 解析器读的字段名搭的形状(见 `test/douyu_source_test.dart`
  顶部说明)。它们钉的是本包的解码,不是斗鱼现在怎么答。录制真实响应是下一步,需要一次对斗鱼的实际请求。
- 描述符字段(`enc_time`/`is_special`/`expire_at`)与签名链今天是否仍与 v1 一致。
- 换链返回的实际形式(拼路径型 / 完整 URL 型)线上占比。
- `allpage/6` 的每页真实条数与是否另有分页声明。
- 设备/播放器能否真的拉起返回的 FLV:属于 `integrations/media` 与房间页的验收,不在本包。
