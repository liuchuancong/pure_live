# Plugin Manifest

> 所有插件必须声明 Manifest;Manifest 不允许运行时动态扩大权限。

## 1. 示例

```yaml
id: com.purelive.source.bilibili
name: Bilibili
version: 1.0.0
apiVersion: 1
author: PureLive

capabilities:
  - live
  - vod
  - search
  - feed
  - comment
  - danmaku
  - subtitle
  - auth

permissions:
  - network
  - cookies
  - account
```

## 2. 字段语义

| 字段 | 语义 |
|---|---|
| `id` | 全局唯一,反向域名约定;ContentRef 的 sourceId 即它 |
| `version` | 插件自身版本 |
| `apiVersion` | 目标插件 API 契约版本;Runtime 按 minimum/maximum 区间判定兼容 |
| `capabilities` | 实现的能力清单(见 [../contracts/capability-contract.md](../contracts/capability-contract.md)),注册到 CapabilityRegistry |
| `permissions` | 所需权限(见 [plugin-permission.md](plugin-permission.md));未声明的调用一律拒绝 |
| `author` / `name` | 展示信息;安装页向用户呈现 |

## 3. 规则

- Manifest 解析失败 / apiVersion 不兼容 / 能力名未知 → 拒绝安装。
- `capabilities` 与代码实际提供不一致 → 契约测试失败,禁止启用。
- Data 插件(TVBox/M3U)的 Manifest 由解析器从数据源自动派生(见 [data-plugin.md](data-plugin.md))。
