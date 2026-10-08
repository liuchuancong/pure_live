# IPTV Repository

> IPTV 数据面:drift(关系型)存储 + repository 契约。

## 存储表(要点)

```text
lists(id, name, url?, enabled, updatedAt)
channels(id, listId, name, logo, group, sortKey, enabled)
channel_urls(channelId, url, kind(direct|udpxy), priority)
epg_bindings(channelId, strategy, tvgId, normalizedName)
```

## Repository 契约(纯 Dart 可单测)

```dart
abstract class IptvRepository {
  Future<List<IptvList>> lists();
  Future<void> importList(IptvListSource source);   // m3u/epg 解析入库
  Future<List<Channel>> channels({GroupRef? group});
  Future<void> reorder / toggle / favorite(...);
}
```

## 规则

- 业务 UI(iptv 域)只经 repository,不触 SQL。
- v1 数据迁移:IPTV 库结构可近乎平移(见 [../../migration/database-migration.md](../../migration/database-migration.md))。
- udpxy 中继地址在 resolve 时组装为 MediaTicket(中继也是"线路")。
