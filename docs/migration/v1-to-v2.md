# v1 → v2 迁移总览

> 原则:v2 首次启动提供一次性迁移向导;**老数据不丢**,失败可跳过重试,绝不清空。

## 迁移面

| v1 数据 | v2 去处 | 文档 |
|---|---|---|
| hive 设置/凭据引用 | storage 新 kv + secure | [settings-migration.md](settings-migration.md) |
| drift IPTV 库 | 新 iptv repository(结构近平移) | [database-migration.md](database-migration.md) |
| 各域历史/收藏 | ContentRef 统一模型 | [database-migration.md](database-migration.md) |
| 直播源配置(启用/排序) | 源插件配置(按站 id 映射) | [plugin-migration.md](plugin-migration.md) |

## 流程

```text
检测 v1 数据 → 摘要展示(多少收藏/历史/设置)→ 用户确认
→ 逐域迁移(每域独立事务,失败隔离可重试)→ 校验 → 标记完成
```

## 规则

- v1 数据**只读不改**(迁移读 v1,写 v2 存储);回滚 = 清 v2 重来,v1 完好。
- 迁移器版本化;W9 交付(见 [../roadmap/v2-roadmap.md](../roadmap/v2-roadmap.md)),v2 早期版本不强制迁移。
