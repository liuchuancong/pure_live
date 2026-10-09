# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- `IdentityFacts` / `IdentityPolicy` / `IdentityMatcher`:权威编号优先(同值即同一、不同值即不同且压过模糊相符),
  置信度是"可比字段里相符的权重占比";只有标题可比、或时长超出容差,都**不自动并**。
- `IdentityIndex` / `IdentityStore` / `KeyValueIdentityStore`:身份 → 成员索引与换源用 `alternatives()`;
  用户的确认被记住(问一次),身份 id 对无编号内容就是首次使用的 ref key —— 全程不改写 ContentRef。
