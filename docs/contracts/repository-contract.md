# Repository 契约

> Repository 表示一个"内容源集合"——生态分发的基本单位,与单个 Provider 分离。

## 1. 结构

```text
Repository
├── metadata       名称/作者/版本/更新时间
├── sources        源列表(每个含 id/类型/入口)
├── updatePolicy   手动/自动/间隔
├── parser         解析器类型(tvbox-json / m3u / epg-xmltv / opml / …)
└── capabilities   集合层面提供的能力声明
```

## 2. 类型

`TVBox Repository`(单仓/多仓)/ `Music Repository` / `Live Repository` / `IPTV Repository` / `Plugin Repository`(插件分发索引,未来)

## 3. 处理管线

```text
Repository URL → Source Parser → Universal Provider → ContentRef → MediaTicket
```

多仓:

```text
Repository
├── Source A
├── Source B
└── Source C
```

PureLive 不需要知道某个影视站的内部实现——TVBox 只是一个 Universal Source Adapter(见 [../sources/vod/tvbox.md](../sources/vod/tvbox.md)),不是业务模块。

## 4. 规则

- Repository 更新失败不影响已加载源;解析错误逐源隔离。
- Repository 配置属于用户数据,纳入 sync/backup(不含凭据)。
- 第三方生态仓库未来经 `Plugin Repository` 分发(见 [../architecture/evolution.md](../architecture/evolution.md))。
