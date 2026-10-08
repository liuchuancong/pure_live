# ADR 0009:TVBox 适配器

- 状态:已接受(2026-10-08)

## 背景

TVBox 单仓/多仓是中文影视生态的事实标准;用户量大,但站点实现参差。

## 决策

TVBox 不做业务模块,做 **Universal Source Adapter**(Data Plugin):Repository(单仓/多仓)→ Parser → Universal Provider → ContentRef → MediaTicket;支持 JSON/M3U/EPG/XMLTV;JS spider 经沙箱执行。见 [../sources/vod/tvbox.md](../sources/vod/tvbox.md)、[../contracts/repository-contract.md](../contracts/repository-contract.md)。

## 后果

- 正:一次性接入整个影视生态;PureLive 不感知具体影视站。
- 负:解析器兼容性长尾(spider 差异);逐源隔离 + 限额解析缓解。
