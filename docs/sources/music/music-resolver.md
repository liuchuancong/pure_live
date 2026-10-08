# Music Resolver

> 跨源解析器:一首歌 → 选源 → 拿到 MediaTicket 的决策器。

## 1. 流程

```text
MusicIdentity → 候选源列表(用户偏好优先:默认源 > 手动指定 > 可用性)
→ 逐源 resolve(音质按偏好:无损/320k/128k)
→ 成功:MediaTicket + 记忆该映射
→ 全部失败:错误聚合呈现(哪些源 VIP 限制/地区限制/失效)
```

## 2. 规则

- resolve 返回的仍是标准 MediaTicket(缓存/到期/刷新语义一致)。
- 音质降级需用户设置允许(默认允许同源降档,不允许跨源自动换——换源在 identity 层显式进行)。
- 与 lx-music 兼容:resolver 的源接口对齐 lx user-api 概念(search/getLyric/getPlayUrl),为脚本兼容留面(不承诺)。
