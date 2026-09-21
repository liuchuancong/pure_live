# NimoTV 合同检查点（2026-09-21）

## 当前公开合同

- 官网 `https://www.nimo.tv/` 当前可见公开直播房间；
- 移动房间页 `https://m.nimo.tv/{channel}` 内嵌 `G_roomBaseInfo`，提供稳定 `roomId`、主播身份、标题、分类、直播状态、`viewerNum` 与 `mStreamPkg`；
- 数字房间规范化为 `/live/{roomId}`，频道别名规范化为 `/{alias}`；首阶段搜索只接受精确频道号、别名和官方链接，不把首页推荐当作完整目录；
- 官网首页目录当前使用 WUP/Tars 二进制会话接口，原生目录与关键词分页留到后续合同批次。

## 媒体与指标

`mStreamPkg` 是十六进制编码的媒体参数包。源码有界解码后提取官方 FLV 域名、流 ID、`appid`、`tp`、`wsSecret` 与 `wsTime`，并按平台 ratio 生成：

| 稳定 ID | 展示档位 |
| --- | --- |
| `flv:6000` | 1080p |
| `flv:2500` | 720p |
| `flv:1000` | 480p |
| `flv:500` | 360p |
| `flv:250` | 240p |

媒体地址固定升级为 HTTPS，主机限制为 NimoTV 官方 FLV 子域。`wsTime` 按十六进制 Unix 秒解析，播放器提前五分钟刷新并在标记到期前十秒判定失效；播放恢复与录制入口重新读取房间页取得新签名，同时保持原 ratio 选择。

`viewerNum` 只在当前直播状态下作为并发观看展示；下播或字段缺失时保持未知，不以其他互动字段补值。远端聊天尚待单独接入。

## 当前生产证据

2026-09-21 从官网首页选择当前公开房间，移动房间页返回直播状态与时效媒体包。按当前 Streamlink 参数规则生成 HTTPS FLV 后，请求返回 HTTP 200，开头字节为标准 `FLV` 文件头。该证据证明当前样本媒体合同可达，不替代 Android/Windows 原生播放和短录验收。

## 源码与验证边界

适配器、链接解析、注册表、设置目录迁移、指标能力、网页链接回流和中英文范围说明已写入源码。确定性契约测试与迁移测试已写入 `test/nimotv_site_test.dart`、`test/nimotv_catalog_migration_test.dart` 和 `test/web_search_room_parser_test.dart`；按当前“功能先行、集中验收”批次，测试执行与双端原生验证保留到源码收敛阶段。

## 参考

- NimoTV 官网：<https://www.nimo.tv/>
- Streamlink NimoTV 当前实现：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/nimotv.py>
- Streamlink 2026 变更记录：<https://github.com/streamlink/streamlink/blob/master/CHANGELOG.md>
