# Network Security

> 所有网络经统一出口;插件拿不到裸 HTTP。

## 宿主网络(network 包)

- dio 统一装配:拦截器(风控头/UA 池)、cookie 管理、重试、gbk 转码、talker 日志、系统代理。
- 请求去敏:日志脱敏 Cookie/Token 字段。

## 插件网络(PluginNetwork)

```text
JS → Sandbox API → PluginNetwork → Network Core
```

提供:域名白名单(Manifest 声明)、timeout、redirect policy、headers、cookies(需权限)、proxy(跟随系统)、response size limit、并发限制、缓存。

## 规则

- 白名单外域名 → 拒绝 + 诊断;用户可在插件详情查看/微调(高风险需确认)。
- 全局代理与镜像策略(国内镜像)统一在 network 包,插件自动继承。
