# ADR 0003:插件系统

- 状态:已接受(2026-10-08)

## 背景

站点解析是维护成本大头;用户自定义源/主题是明确需求(参考 lx-music 生态)。

## 决策

三形态插件:Native(Dart 编译,官方/高性能)、JS(flutter_js 沙箱,第三方生态)、Data(TVBox/M3U/EPG 无代码)。Manifest 静态声明 capabilities/permissions/apiVersion;生命周期 Installed→…→Uninstalled;安装必经安全管线。详细:[../plugin/plugin-overview.md](../plugin/plugin-overview.md)。

## 后果

- 正:新源/新主题不动核心;生态可开放。
- 负:契约维护成本;JS 沙箱性能受限——复杂协议走 Native,生态分层本身就是取舍。
