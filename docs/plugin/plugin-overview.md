# 插件体系总览

> 万物插件化,但 **Package(工程组织)/ Plugin(运行时扩展)/ Capability(能力契约)三者分离**。

## 1. 三种插件形态

| 形态 | 运行方式 | 适合 | 文档 |
|---|---|---|---|
| **Native Plugin** | Dart 编译进 App(或预编译分发) | Bilibili 等核心源、高性能媒体能力、系统级能力 | [native-plugin.md](native-plugin.md) |
| **JS Plugin** | flutter_js 沙箱解释执行 | 网站解析、API、搜索、影视源、音乐源、小型数据适配器 | [js-plugin.md](js-plugin.md) |
| **Data Plugin** | 纯数据解析,无代码 | TVBox JSON、多仓、M3U、EPG、XMLTV、OPML | [data-plugin.md](data-plugin.md) |

## 2. 核心机制

- [plugin-manifest.md](plugin-manifest.md) 身份与声明(apiVersion/capabilities/permissions)
- [plugin-lifecycle.md](plugin-lifecycle.md) Installed→Verified→Loaded→Initialized→Enabled→Disabled→Uninstalled
- [plugin-permission.md](plugin-permission.md) 权限清单与用户授权
- [plugin-security.md](plugin-security.md) 安全校验、最小权限、崩溃隔离
- [native-plugin.md](native-plugin.md) / [js-plugin.md](js-plugin.md) / [data-plugin.md](data-plugin.md) 形态细则
- [plugin-development.md](plugin-development.md) 开发指南

## 3. 分发

Builtin → Local File → URL → Repository → Marketplace(未来)。安装必经安全管线(见 [../security/security-model.md](../security/security-model.md))。

## 4. 生态愿景

官方插件 / 社区插件 / 个人插件 / 企业插件;最终形成 Live / VOD / Music / IPTV / Subtitle / Theme / Search / Utility 的插件市场。第一阶段不追求数量——**一个插件(Bilibili)→ 一个 Capability → 一个 ContentRef → 一个 MediaTicket → 一个 Player → 完整业务闭环**。
