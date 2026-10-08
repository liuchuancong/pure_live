# Data Plugin

> 无代码/低代码数据源插件:标准格式的配置即插件。

## 1. 支持格式

`TVBox JSON`(单仓/多仓)、`M3U / M3U8`、`EPG / XMLTV`、`OPML`(播客订阅,预留)

## 2. 管线

```text
用户提交(URL/文件/二维码)
 → 格式识别 → Parser(白名单格式,限额解析)
 → Universal Provider 注册(派生 Manifest:capabilities 按内容自动声明)
 → ContentRef / MediaTicket 进入统一管线
```

TVBox 详见 [../sources/vod/tvbox.md](../sources/vod/tvbox.md);IPTV 详见 [../sources/iptv/iptv-architecture.md](../sources/iptv/iptv-architecture.md)。

## 3. 规则

- 解析错误逐源隔离,不影响仓内其他源。
- 字段大小与条目数限额(防膨胀);地址条目走与普通源相同的 MediaTicket 到期刷新。
- Data 插件产生的源同样受 Source 管辖:契约测试用**解析器级测试**替代(对样例数据断言),fixtures 存样例配置。
