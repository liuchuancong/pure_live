# 插件开发(开发者视角)

> 作者向指南见 [../plugin/plugin-development.md](../plugin/plugin-development.md);本篇面向仓库内维护者。

## Native 源插件(仓内 `plugins/<site>`)

- 骨架由脚手架生成;实现 Capability 接口(resolve/refresh 必须给真实 `expiresAt`)。
- 协议词典:v1 `lib/shared/platforms/<site>` 与 pure_live_TV `lib/modules/vod` —— 重写不复製。
- 网络统一走 network 底座(风控头/UA 池已有);凭据走 auth 保险箱。
- fixtures:用真实响应录制(脱敏 Cookie/Token);契约测试离线跑。

## JS 插件(生态)

- 模板脚本 + 本地导入调试;沙箱限制见 [../security/plugin-sandbox.md](../security/plugin-sandbox.md)。
- 只能 PluginNetwork(白名单域);超时/大小上限内工作。

## 验收门禁

契约测试绿 + fixtures 齐 + 权限最小化 + 无跨插件依赖 + README。
