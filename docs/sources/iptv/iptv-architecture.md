# IPTV 架构

> IPTV 统一插件化:Data Plugin 形态为主(M3U/EPG 即插件)。

## 1. 支持

M3U / M3U8 / EPG(XMLTV)/ Xtream / 自定义 API

## 2. 模型

```text
Channel / Group / Program / EpgEvent / MediaTicket
```

## 3. 文档

导入与文件:[m3u.md](m3u.md) · 节目单:[epg.md](epg.md) · 数据面:[repository.md](repository.md)

## 4. 业务要点

- 频道管理:分组/排序/收藏/隐藏(iptv_repository,drift 存储)。
- 组播/udpxy 中继支持(v1 已验证:udpxy 地址作为线路)。
- 频道切换性能优先:相邻频道预 resolve。
- 导入入口:文件/URL/剪贴板/**桌面拖拽**(desktop_drop)。
