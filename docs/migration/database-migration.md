# 数据库迁移

## v1 → v2 映射

| v1 | v2 | 说明 |
|---|---|---|
| drift IPTV 库(channels/groups/epg) | iptv repository 新 schema | 表结构近平移,udpxy 线路字段保留 |
| hive 各域盒子(历史/收藏按站存) | drift 统一历史/收藏(ContentRef 化) | 站点 id → sourceId 映射表驱动 |
| 收藏分组 | favorites 文件夹 | 平移 |

## 步骤(每域)

1. 读 v1(只读);2. 字段映射(站点 → sourceId;未收录站进"未知源"仍可显示);3. 写入 v2(事务);4. 计数校验(迁移前后条目数一致,差异报告)。

## 规则

- 迁移器版本化,新旧格式都有 fixture 测试(Migration Test)。
- ContentRef 化失败的单条记录进"待处理"列表,不阻塞整体。
