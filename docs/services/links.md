# Links(通用链接解析)

> 分享链接/深链接 → ContentRef → 路由;Links 不直接做 UI 跳转。

## 流程

```text
URL(分享短链/平台链接/PureLive 协议)
 → LinkResolver(短链展开 → 正则/规则匹配各源注册的链接模式)
 → ContentRef(如 bilibili.com/video/BVxxx → bilibili://vod/BVxxx)
 → RouteResolver(按 kind 找 feature 路由)→ Feature
```

## 来源

- 外部分享进入(深链接:platform 包 app_links 接入;分享到 App 的媒体 intake)。
- 剪贴板检测(用户主动触发时)。
- PureLive 自有协议 `purelive://`(未来)。

## 规则

- 解析不出 → 友好提示,不崩;解析缓存避免重复展开。
- 规则由各源插件注册(LinkPattern capability 面),links 服务只做调度——加新站不改 links 包。
