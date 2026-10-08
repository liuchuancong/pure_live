# TVBox(生态适配器)

> TVBox 不作为业务模块,而是 Universal Source Adapter:单仓/多仓/JSON/API/M3U/EPG/XMLTV 统一转换(ADR 0009)。

## 1. 管线

```text
TVBox Repository → Source Parser ─┬─(纯配置)→ Dart 解析 ─┐
                                  └─(spider 脚本)→ Python 宿主 ┘→ Universal Provider → ContentRef → MediaTicket
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
- **带代码的源跑在嵌入式 CPython 上**(ADR [0017](../../adr/0017-tvbox-python-runtime.md)):`packages/ecosystem/external_tvbox` 经 `integrations/python_runtime` 的本机 HTTP 调 spider,spider 接口面对齐 `webtv-main` 的 `chaquo/src/main/python/base/spider.py`。
- 纯配置源(仓库 JSON / M3U / EPG / XMLTV)不需要 Python:Dart 侧解析即可。
- JS spider 仍走 JS 沙箱(`fjs`,见 [../../plugin/js-plugin.md](../../plugin/js-plugin.md));两种宿主按源实际带的脚本形态选择,不互相替换。

## 3. 规则

- 源搜索/详情/播放走统一契约;解析失败逐源隔离。
- 仓库配置 = 用户数据(纳入 backup/sync;不含凭据)。
- 影视站点内容与 B 站点播同构:movie/series/episode ContentKind + MediaTicket。
