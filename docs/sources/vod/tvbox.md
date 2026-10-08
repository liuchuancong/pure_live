# TVBox(生态适配器)

> TVBox 不作为业务模块,而是 Universal Source Adapter:单仓/多仓/JSON/API/M3U/EPG/XMLTV 统一转换(ADR 0009)。

## 1. 管线

```text
TVBox Repository → Source Parser → Universal Provider
→ ContentRef → MediaTicket
```

多仓:

```text
Repository
├── Source A  ┐
├── Source B  ├→ 每源独立 Provider 实例,失败互不影响
└── Source C  ┘
```

## 2. 范围

- 单仓(spider JSON)、多仓(仓列表)、M3U、EPG、XMLTV。
- 解析:JS spider(如果有)→ 走 JS 沙箱(与 js-plugin 同一机制);纯配置 → Data Plugin。

## 3. 规则

- 源搜索/详情/播放走统一契约;解析失败逐源隔离。
- 仓库配置 = 用户数据(纳入 backup/sync;不含凭据)。
- 影视站点内容与 B 站点播同构:movie/series/episode ContentKind + MediaTicket。
